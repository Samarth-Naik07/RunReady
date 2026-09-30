import 'package:dio/dio.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/weather_cache.dart';
import 'weather_models.dart';

/// Gives the rest of the app typed weather data, hiding where it comes from.
///
/// With a [WeatherCache], every successful forecast is saved, and a failed
/// network request falls back to the saved forecast for the same location.
class WeatherRepository {
  const WeatherRepository(
    this._apiClient, {
    this._cache,
    this._clock = DateTime.now,
  });

  final ApiClient _apiClient;
  final WeatherCache? _cache;

  /// Supplies the "fetched at" time. Tests pass a fixed time.
  final DateTime Function() _clock;

  /// Fetches the hourly forecast for the given coordinates as a typed model.
  ///
  /// - Network success: saves the forecast to the cache and returns it.
  /// - Network failure with a cached forecast for these coordinates: returns
  ///   the cached one, marked with [HourlyForecast.cachedAt].
  /// - Network failure without a cache: throws the matching [AppError]
  ///   ([NetworkError], [TimeoutError], [ServerError], ...).
  /// - A response that can't be read: throws [InvalidDataError]. The cache is
  ///   neither used nor overwritten.
  /// - Cancelled request: rethrows the [DioException] unchanged.
  Future<HourlyForecast> getHourlyForecast({
    required double latitude,
    required double longitude,
  }) async {
    final Map<String, dynamic> json;
    try {
      json = await _apiClient.fetchHourlyWeather(
        latitude: latitude,
        longitude: longitude,
      );
    } on DioException catch (error, stackTrace) {
      // A cancelled request was stopped on purpose; that isn't "offline".
      if (error.type == DioExceptionType.cancel) rethrow;

      final cached = await _loadFromCache(latitude, longitude);
      if (cached != null) return cached;
      Error.throwWithStackTrace(AppError.fromDio(error), stackTrace);
    } catch (error, stackTrace) {
      // Not a network failure (e.g. an empty body), so no cache fallback.
      Error.throwWithStackTrace(AppError.from(error), stackTrace);
    }

    // Parse first, so only valid forecasts are ever saved.
    final HourlyForecast forecast;
    try {
      forecast = HourlyForecast.fromJson(json);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(InvalidDataError(error), stackTrace);
    }

    await _saveToCache(latitude, longitude, json);
    return forecast;
  }

  Future<HourlyForecast?> _loadFromCache(
    double latitude,
    double longitude,
  ) async {
    final cache = _cache;
    if (cache == null) return null;

    try {
      final entry = await cache.load(latitude: latitude, longitude: longitude);
      if (entry == null) return null;
      return HourlyForecast.fromJson(entry.forecastJson)
          .asCached(entry.cachedAt);
    } on Exception {
      // If the cache itself can't be read, report the network error instead.
      return null;
    }
  }

  Future<void> _saveToCache(
    double latitude,
    double longitude,
    Map<String, dynamic> json,
  ) async {
    final cache = _cache;
    if (cache == null) return;

    try {
      await cache.save(
        latitude: latitude,
        longitude: longitude,
        forecastJson: json,
        cachedAt: _clock(),
      );
    } on Exception {
      // Failing to save must not throw away fresh data we already have.
    }
  }
}
