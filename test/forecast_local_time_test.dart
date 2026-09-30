import 'package:flutter_test/flutter_test.dart';

import 'package:run_ready/features/weather/data/weather_models.dart';

void main() {
  group('HourlyForecast.nowAtLocation', () {
    final instant = DateTime.utc(2026, 9, 30, 10, 15); // 10:15 UTC

    test('converts to the location clock using the UTC offset', () {
      const london = HourlyForecast(
        timezone: 'Europe/London',
        hours: [],
        utcOffsetSeconds: 3600, // +1:00
      );
      const kolkata = HourlyForecast(
        timezone: 'Asia/Kolkata',
        hours: [],
        utcOffsetSeconds: 19800, // +5:30
      );

      expect(london.nowAtLocation(instant), DateTime(2026, 9, 30, 11, 15));
      expect(kolkata.nowAtLocation(instant), DateTime(2026, 9, 30, 15, 45));
    });

    test('uses the device clock when the offset is unknown', () {
      const forecast = HourlyForecast(timezone: 'x', hours: []);
      final deviceNow = DateTime(2026, 9, 30, 7, 30);

      expect(forecast.nowAtLocation(deviceNow), deviceNow);
    });

    test('fromJson reads utc_offset_seconds', () {
      final forecast = HourlyForecast.fromJson({
        'timezone': 'Europe/London',
        'utc_offset_seconds': 3600,
        'hourly': {
          'time': <String>[],
          'temperature_2m': <num>[],
          'apparent_temperature': <num>[],
          'precipitation_probability': <num>[],
          'relative_humidity_2m': <num>[],
          'wind_speed_10m': <num>[],
          'uv_index': <num>[],
          'weather_code': <num>[],
        },
      });

      expect(forecast.utcOffsetSeconds, 3600);
    });
  });
}
