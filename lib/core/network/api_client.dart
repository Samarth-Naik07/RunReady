import 'package:dio/dio.dart';

/// Thin wrapper around Dio for talking to the Open-Meteo API.
class ApiClient {
  ApiClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.open-meteo.com/v1',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  final Dio _dio;

  /// Fetches the hourly forecast for the given coordinates.
  ///
  /// Returns the raw JSON response body. Throws a [DioException] if the
  /// request fails.
  Future<Map<String, dynamic>> fetchHourlyWeather({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/forecast',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'hourly': [
          'temperature_2m',
          'apparent_temperature',
          'precipitation_probability',
          'relative_humidity_2m',
          'wind_speed_10m',
          'uv_index',
          'weather_code',
        ].join(','),
        'timezone': 'auto',
      },
    );
    return response.data!;
  }
}
