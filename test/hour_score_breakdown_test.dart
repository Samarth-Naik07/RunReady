import 'package:flutter_test/flutter_test.dart';

import 'package:run_ready/features/run_score/domain/hour_score_breakdown.dart';
import 'package:run_ready/features/run_score/domain/run_score_calculator.dart';
import 'package:run_ready/features/weather/data/weather_models.dart';

const calculator = RunScoreCalculator();

HourlyWeather hourWith({
  double feelsLike = 15,
  int rain = 0,
  double wind = 5,
  double uv = 1,
  int humidity = 50,
}) {
  return HourlyWeather(
    time: DateTime(2026, 9, 30, 17),
    temperature: feelsLike,
    apparentTemperature: feelsLike,
    precipitationProbability: rain,
    relativeHumidity: humidity,
    windSpeed: wind,
    uvIndex: uv,
    weatherCode: 0,
  );
}

void main() {
  group('scoreBreakdown', () {
    test('points add up to the calculator Run Score', () {
      final hours = [
        hourWith(),
        hourWith(feelsLike: 34, rain: 70, wind: 20, uv: 8, humidity: 90),
        hourWith(feelsLike: 0, rain: 20, wind: 30),
      ];

      for (final hour in hours) {
        final total = scoreBreakdown(
          hour,
          calculator,
        ).map((f) => f.points).reduce((a, b) => a + b);

        expect(total, closeTo(calculator.scoreHour(hour).score, 0.0001));
      }
    });

    test('uses the calculator factor scores and weights', () {
      final breakdown = scoreBreakdown(hourWith(rain: 30), calculator);
      final rain = breakdown.firstWhere((f) => f.label == 'Rain chance');

      expect(rain.value, '30%');
      expect(rain.factorScore, calculator.rainScore(30)); // 70
      expect(rain.weight, RunScoreCalculator.rainWeight);
      expect(rain.points, closeTo(21, 0.0001));
      expect(rain.maxPoints, closeTo(30, 0.0001));
    });
  });

  group('explainScore', () {
    test('perfect conditions', () {
      expect(
        explainScore(scoreBreakdown(hourWith(), calculator)),
        'Close to ideal running conditions on every factor.',
      );
    });

    test('names the two biggest losses, biggest first', () {
      // Lost points: rain 21, temperature 12.25, UV 5, humidity 1.25.
      final hour = hourWith(feelsLike: 27, rain: 70, uv: 6, humidity: 70);

      expect(
        explainScore(scoreBreakdown(hour, calculator)),
        'Lowered mostly by the rain chance (70%) and '
        'feels-like temperature (27°C).',
      );
    });

    test('ignores factors that lost under 3 points', () {
      // Humidity 80% loses 2.5 points; nothing else loses any.
      expect(
        explainScore(scoreBreakdown(hourWith(humidity: 80), calculator)),
        'Close to ideal running conditions on every factor.',
      );
    });
  });

  test('runScoreRating', () {
    expect(runScoreRating(85), 'Great');
    expect(runScoreRating(80), 'Great');
    expect(runScoreRating(65), 'Good');
    expect(runScoreRating(45), 'Fair');
    expect(runScoreRating(20), 'Poor');
  });
}
