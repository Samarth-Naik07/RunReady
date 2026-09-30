import 'package:dio/dio.dart';

/// Thin wrapper around Dio for the Open-Meteo Geocoding API.
///
/// Geocoding lives on a different host from the forecast, so it has its own
/// base URL. Otherwise it follows the same pattern as `ApiClient`.
class GeocodingApiClient {
  GeocodingApiClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://geocoding-api.open-meteo.com/v1',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  final Dio _dio;

  /// Searches places by name, e.g. "Mumbai".
  ///
  /// Returns the raw JSON response body. Throws a [DioException] if the
  /// request fails.
  Future<Map<String, dynamic>> searchLocations(
    String name, {
    int count = 10,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/search',
      queryParameters: {
        'name': name,
        'count': count,
        'language': 'en',
        'format': 'json',
      },
    );
    return response.data!;
  }
}
