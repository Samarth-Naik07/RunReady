import 'package:flutter_test/flutter_test.dart';

import 'package:run_ready/features/run_score/domain/run_score_calculator.dart';
import 'package:run_ready/features/weather/data/weather_models.dart';

const calculator = RunScoreCalculator();

/// An hour with perfect running weather, unless a value is overridden.
HourlyWeather hourAt(
  int hourOfDay, {
  double feelsLike = 15,
  int rain = 0,
  double wind = 5,
  double uv = 1,
  int humidity = 50,
}) {
  return HourlyWeather(
    time: DateTime(2026, 9, 30, hourOfDay),
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
  group('temperatureScore', () {
    test('is 100 across the ideal 10–20 °C range', () {
      expect(calculator.temperatureScore(10), 100);
      expect(calculator.temperatureScore(15), 100);
      expect(calculator.temperatureScore(20), 100);
    });

    test('falls linearly when it is too hot', () {
      expect(calculator.temperatureScore(30), 50);
      expect(calculator.temperatureScore(35), 25);
      expect(calculator.temperatureScore(40), 0);
      expect(calculator.temperatureScore(45), 0);
    });

    test('falls linearly when it is too cold', () {
      expect(calculator.temperatureScore(0), 50);
      expect(calculator.temperatureScore(-10), 0);
      expect(calculator.temperatureScore(-20), 0);
    });
  });

  group('rainScore', () {
    test('is the opposite of the rain probability', () {
      expect(calculator.rainScore(0), 100);
      expect(calculator.rainScore(30), 70);
      expect(calculator.rainScore(100), 0);
    });
  });

  group('windScore', () {
    test('is 100 up to 10 km/h', () {
      expect(calculator.windScore(0), 100);
      expect(calculator.windScore(10), 100);
    });

    test('falls linearly to 0 at 40 km/h', () {
      expect(calculator.windScore(25), 50);
      expect(calculator.windScore(40), 0);
      expect(calculator.windScore(60), 0);
    });
  });

  group('scoreHour', () {
    test('is 100 for perfect running weather', () {
      expect(calculator.scoreHour(hourAt(6)).score, 100);
    });

    test('combines every factor with its weight', () {
      final hour = hourAt(
        6,
        feelsLike: 15, // temperature 100 × 0.35 = 35
        rain: 20, //      rain         80 × 0.30 = 24
        wind: 25, //      wind         50 × 0.20 = 10
        uv: 6, //         UV           50 × 0.10 =  5
        humidity: 80, //  humidity     50 × 0.05 =  2.5
      );

      expect(calculator.scoreHour(hour).score, closeTo(76.5, 0.001));
    });

    test('uses the feels-like temperature, not the air temperature', () {
      final hour = HourlyWeather(
        time: DateTime(2026, 9, 30, 6),
        temperature: 15, // would be ideal
        apparentTemperature: 30, // temperature score 50
        precipitationProbability: 0,
        relativeHumidity: 50,
        windSpeed: 5,
        uvIndex: 1,
        weatherCode: 0,
      );

      // 100 - (50 points lost × 0.35) = 82.5
      expect(calculator.scoreHour(hour).score, closeTo(82.5, 0.001));
    });
  });

  group('bestWindow', () {
    test('finds the consecutive 2 hours with the highest average', () {
      // Rain only: hour score = 100 - 0.3 × rain.
      final hours = [
        hourAt(5, rain: 0), //   100  <- best single hour...
        hourAt(6, rain: 100), //  70
        hourAt(7, rain: 30), //   91  <- ...but 07:00–09:00 is the best pair
        hourAt(8, rain: 30), //   91
        hourAt(9, rain: 100), //  70
      ];

      final window = calculator.bestWindow(hours)!;

      expect(window.start, DateTime(2026, 9, 30, 7));
      expect(window.end, DateTime(2026, 9, 30, 9));
      expect(window.score, closeTo(91, 0.001));
      expect(window.hourlyScores, hasLength(2));
      expect(window.hourlyScores.first.hour.time, DateTime(2026, 9, 30, 7));
    });

    test('picks the earliest window on a tie', () {
      final hours = [hourAt(6), hourAt(7), hourAt(8)];

      final window = calculator.bestWindow(hours)!;

      expect(window.start, DateTime(2026, 9, 30, 6));
      expect(window.score, 100);
    });

    test('ignores hours that are not back-to-back', () {
      final hours = [
        hourAt(6), //          100, but 8:00 is not the next hour
        hourAt(8),
        hourAt(9, rain: 100), // 70
      ];

      final window = calculator.bestWindow(hours)!;

      expect(window.start, DateTime(2026, 9, 30, 8));
      expect(window.end, DateTime(2026, 9, 30, 10));
      expect(window.score, closeTo(85, 0.001));
    });

    test('returns null when there are fewer than 2 hours', () {
      expect(calculator.bestWindow([]), isNull);
      expect(calculator.bestWindow([hourAt(6)]), isNull);
    });
  });
}
