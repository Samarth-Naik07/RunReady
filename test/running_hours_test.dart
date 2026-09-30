import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:run_ready/features/run_score/domain/run_score_models.dart';
import 'package:run_ready/features/run_score/domain/running_hours.dart';
import 'package:run_ready/features/run_score/providers/run_score_provider.dart';
import 'package:run_ready/features/weather/data/weather_models.dart';
import 'package:run_ready/features/weather/providers/weather_provider.dart';

/// Perfect weather at [time] except for [rain] %, so the hour's Run Score is
/// 100 - 0.3 × rain.
HourlyWeather hourAt(DateTime time, {int rain = 0}) {
  return HourlyWeather(
    time: time,
    temperature: 15,
    apparentTemperature: 15,
    precipitationProbability: rain,
    relativeHumidity: 50,
    windSpeed: 5,
    uvIndex: 1,
    weatherCode: 0,
  );
}

/// Two days from 30 Sep 00:00. Night hours (00–04) are perfect, the evening
/// (22–23) is nearly perfect, and the rest of the day is worse, so the night
/// would win if it were allowed.
List<HourlyWeather> twoDays() {
  final start = DateTime(2026, 9, 30);
  return [
    for (var h = 0; h < 48; h++)
      hourAt(
        start.add(Duration(hours: h)),
        rain: switch (h % 24) {
          < 5 => 0, //    100
          >= 22 => 10, //  97
          _ => 50, //      85
        },
      ),
  ];
}

ProviderContainer makeContainer(DateTime now) {
  final container = ProviderContainer(
    overrides: [
      weatherForecastProvider.overrideWith(
        (ref) async =>
            HourlyForecast(timezone: 'Asia/Kolkata', hours: twoDays()),
      ),
      clockProvider.overrideWithValue(() => now),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// True if [window] starts 5:00 AM–10:00 PM and ends by midnight that day.
bool withinRunningHours(RunWindow window) {
  final midnight = DateTime(
    window.start.year,
    window.start.month,
    window.start.day + 1,
  );
  return window.start.hour >= 5 &&
      window.start.hour <= 22 &&
      !window.end.isAfter(midnight);
}

void main() {
  group('isRunningHour', () {
    test('rejects night hours from midnight to 4 AM', () {
      for (var h = 0; h < 5; h++) {
        expect(isRunningHour(DateTime(2026, 9, 30, h)), isFalse, reason: '$h');
      }
    });

    test('accepts 5 AM through the 11 PM hour', () {
      for (var h = 5; h < 24; h++) {
        expect(isRunningHour(DateTime(2026, 9, 30, h)), isTrue, reason: '$h');
      }
    });
  });

  test('runningHoursOnly drops the night hours and keeps order', () {
    final kept = runningHoursOnly(twoDays());

    expect(kept, hasLength(38)); // 19 running hours × 2 days
    expect(kept.first.time, DateTime(2026, 9, 30, 5));
    expect(kept.last.time, DateTime(2026, 10, 1, 23));
  });

  group('recommended windows', () {
    test('10 PM – 12 AM is allowed and beats the daytime', () async {
      final container = makeContainer(DateTime(2026, 9, 30, 4, 30));
      await container.read(weatherForecastProvider.future);

      final best = container.read(bestRunWindowProvider).value!;

      expect(best.start, DateTime(2026, 9, 30, 22));
      expect(best.end, DateTime(2026, 10, 1));
    });

    test('night windows never appear, even when they score best', () async {
      // At 8:30 PM the next 24 hours include tonight's perfect 00–05 hours.
      final container = makeContainer(DateTime(2026, 9, 30, 20, 30));
      await container.read(weatherForecastProvider.future);

      final best = container.read(bestRunWindowProvider).value!;
      final others = container.read(otherRunWindowsProvider).value!;
      final starts = [
        for (final w in [best, ...others]) w.start.hour,
      ];

      expect(starts, isNot(contains(1))); // 1:00–3:00 AM
      expect(starts, isNot(contains(3))); // 3:00–5:00 AM
      expect(starts, isNot(contains(4))); // 4:00–6:00 AM
      expect(starts, isNot(contains(23))); // 11 PM – 1 AM
      expect([best, ...others].every(withinRunningHours), isTrue);
      expect(best.start, DateTime(2026, 9, 30, 22));
    });
  });
}
