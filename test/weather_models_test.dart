import 'package:flutter_test/flutter_test.dart';

import 'package:run_ready/features/weather/data/weather_models.dart';

void main() {
  test('HourlyForecast.fromJson zips the hourly arrays into hours', () {
    final json = <String, dynamic>{
      'timezone': 'Asia/Kolkata',
      'hourly': <String, dynamic>{
        'time': ['2026-09-28T06:00', '2026-09-28T07:00'],
        'temperature_2m': [25.9, 27],
        'apparent_temperature': [31.0, 32.4],
        'precipitation_probability': [0, 20],
        'relative_humidity_2m': [88, 80],
        'wind_speed_10m': [5.3, 6.1],
        'uv_index': [0.0, 1.5],
        'weather_code': [0, 61],
      },
    };

    final forecast = HourlyForecast.fromJson(json);

    expect(forecast.timezone, 'Asia/Kolkata');
    expect(forecast.hours, hasLength(2));

    final second = forecast.hours[1];
    expect(second.time, DateTime(2026, 9, 28, 7));
    expect(second.temperature, 27.0);
    expect(second.apparentTemperature, 32.4);
    expect(second.precipitationProbability, 20);
    expect(second.relativeHumidity, 80);
    expect(second.windSpeed, 6.1);
    expect(second.uvIndex, 1.5);
    expect(second.weatherCode, 61);
  });
}
