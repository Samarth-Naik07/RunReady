import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:run_ready/features/run_score/providers/run_score_provider.dart';
import 'package:run_ready/features/weather/data/weather_models.dart';
import 'package:run_ready/features/weather/providers/weather_provider.dart';

/// Perfect running weather at [hourOfDay] on 30 Sep 2026, with [rain] %.
HourlyWeather hourAt(int hourOfDay, {int rain = 0}) {
  return HourlyWeather(
    time: DateTime(2026, 9, 30, hourOfDay),
    temperature: 15,
    apparentTemperature: 15,
    precipitationProbability: rain,
    relativeHumidity: 50,
    windSpeed: 5,
    uvIndex: 1,
    weatherCode: 0,
  );
}

/// A container with a fixed forecast and a fixed "now".
ProviderContainer makeContainer({
  required Future<HourlyForecast> Function() forecast,
  required DateTime now,
}) {
  final container = ProviderContainer(
    overrides: [
      weatherForecastProvider.overrideWith((ref) => forecast()),
      clockProvider.overrideWithValue(() => now),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('ignores hours that have already started', () async {
    // 06:00–08:00 would be perfect, but it's already 07:30.
    final hours = [
      hourAt(6),
      hourAt(7),
      hourAt(8, rain: 40),
      hourAt(9, rain: 40),
      hourAt(10, rain: 60),
    ];
    final container = makeContainer(
      forecast: () async =>
          HourlyForecast(timezone: 'Asia/Kolkata', hours: hours),
      now: DateTime(2026, 9, 30, 7, 30),
    );

    await container.read(weatherForecastProvider.future);
    final window = container.read(bestRunWindowProvider).value!;

    expect(window.start, DateTime(2026, 9, 30, 8));
    expect(window.end, DateTime(2026, 9, 30, 10));
  });

  test('is null when fewer than 2 upcoming hours remain', () async {
    final hours = [hourAt(21), hourAt(22), hourAt(23)];
    final container = makeContainer(
      forecast: () async =>
          HourlyForecast(timezone: 'Asia/Kolkata', hours: hours),
      now: DateTime(2026, 9, 30, 22, 15), // only 23:00 is still ahead
    );

    await container.read(weatherForecastProvider.future);
    final result = container.read(bestRunWindowProvider);

    expect(result.hasValue, isTrue);
    expect(result.value, isNull);
  });

  test('is loading while the forecast is loading', () {
    final container = makeContainer(
      forecast: () => Completer<HourlyForecast>().future,
      now: DateTime(2026, 9, 30, 6),
    );

    expect(container.read(bestRunWindowProvider).isLoading, isTrue);
  });
}
