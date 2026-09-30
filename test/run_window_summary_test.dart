import 'package:flutter_test/flutter_test.dart';

import 'package:run_ready/features/run_score/domain/run_score_models.dart';
import 'package:run_ready/features/run_score/domain/run_window_summary.dart';
import 'package:run_ready/features/weather/data/weather_models.dart';

/// A 2-hour window where both hours have the same weather.
RunWindow windowWith({
  double feelsLike = 15,
  int rain = 0,
  double wind = 5,
  double uv = 1,
}) {
  HourlyRunScore hour(int h) => HourlyRunScore(
    hour: HourlyWeather(
      time: DateTime(2026, 9, 30, h),
      temperature: feelsLike,
      apparentTemperature: feelsLike,
      precipitationProbability: rain,
      relativeHumidity: 50,
      windSpeed: wind,
      uvIndex: uv,
      weatherCode: 0,
    ),
    score: 80,
  );

  return RunWindow(
    start: DateTime(2026, 9, 30, 6),
    end: DateTime(2026, 9, 30, 8),
    score: 80,
    hourlyScores: [hour(6), hour(7)],
  );
}

void main() {
  test('names the top two good conditions', () {
    expect(
      describeRunWindow(windowWith()),
      'Low rain chance and comfortable temperature.',
    );
  });

  test('adds the most important caution', () {
    expect(
      describeRunWindow(windowWith(feelsLike: 32)),
      'Low rain chance and light wind. Hot, so take water.',
    );
  });

  test('rain caution wins over heat', () {
    expect(
      describeRunWindow(windowWith(feelsLike: 32, rain: 60, uv: 3)),
      'Light wind. Rain is likely, so plan for wet roads.',
    );
  });
}
