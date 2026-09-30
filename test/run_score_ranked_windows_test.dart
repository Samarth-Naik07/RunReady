import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:run_ready/features/run_score/domain/run_score_calculator.dart';
import 'package:run_ready/features/run_score/providers/run_score_provider.dart';
import 'package:run_ready/features/weather/data/weather_models.dart';
import 'package:run_ready/features/weather/providers/weather_provider.dart';

const calculator = RunScoreCalculator();

/// Perfect weather at [hourOfDay] except for [rain] % and [wind] km/h.
/// With calm wind, the hour's Run Score is 100 - 0.3 × rain.
HourlyWeather hourAt(int hourOfDay, {int rain = 0, double wind = 5}) {
  return HourlyWeather(
    time: DateTime(2026, 9, 30, hourOfDay),
    temperature: 15,
    apparentTemperature: 15,
    precipitationProbability: rain,
    relativeHumidity: 50,
    windSpeed: wind,
    uvIndex: 1,
    weatherCode: 0,
  );
}

void main() {
  // Hour scores: 5:100  6:100  7:94  8:70  9:70  10:97  11:97
  final hours = [
    hourAt(5),
    hourAt(6),
    hourAt(7, rain: 20),
    hourAt(8, rain: 100),
    hourAt(9, rain: 100),
    hourAt(10, rain: 10),
    hourAt(11, rain: 10),
  ];

  group('rankedWindows', () {
    test('starts with the same window as bestWindow', () {
      final ranked = calculator.rankedWindows(hours);
      final best = calculator.bestWindow(hours)!;

      expect(ranked.first.start, best.start);
      expect(ranked.first.score, best.score);
    });

    test('lists non-overlapping windows, best first', () {
      final ranked = calculator.rankedWindows(hours);

      // Windows by score: 05–07 (100), 06–08 (97), 10–12 (97), 09–11 (83.5),
      // 07–09 (82), 08–10 (70). Picking the best free one each time:
      // 05–07, skip 06–08 (overlaps), 10–12, skip 09–11 (overlaps), 07–09.
      expect([for (final w in ranked) w.start.hour], [5, 10, 7]);
      expect([for (final w in ranked) w.score.round()], [100, 97, 82]);
    });

    test('respects maxCount', () {
      expect(calculator.rankedWindows(hours, maxCount: 2), hasLength(2));
    });

    test('is empty when no window fits', () {
      expect(calculator.rankedWindows([hourAt(6)]), isEmpty);
    });
  });

  group('otherRunWindowsProvider', () {
    test('skips the best window and anything below 60', () async {
      final container = ProviderContainer(
        overrides: [
          weatherForecastProvider.overrideWith(
            (ref) async => HourlyForecast(
              timezone: 'Asia/Kolkata',
              hours: [
                hourAt(5),
                hourAt(6),
                hourAt(7, rain: 100, wind: 40), // 50
                hourAt(8, rain: 100, wind: 40), // 50
                hourAt(9, rain: 10), //  97
                hourAt(10, rain: 10), // 97
              ],
            ),
          ),
          clockProvider.overrideWithValue(() => DateTime(2026, 9, 30, 4, 30)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(weatherForecastProvider.future);
      final others = container.read(otherRunWindowsProvider).value!;

      // Best is 05–07. Of the rest, 09–11 (97) qualifies but 07–09 (50) is
      // below 60, so it is dropped.
      expect([for (final w in others) w.start.hour], [9]);
    });
  });
}
