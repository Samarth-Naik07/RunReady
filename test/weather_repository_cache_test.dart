import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:run_ready/core/errors/app_error.dart';
import 'package:run_ready/core/network/api_client.dart';
import 'package:run_ready/core/storage/weather_cache.dart';
import 'package:run_ready/features/weather/data/weather_repository.dart';

const panaji = (lat: 15.4909, lon: 73.8278);
const mumbai = (lat: 19.07283, lon: 72.88261);

/// A valid Open-Meteo forecast response with one hour at [temperature].
Map<String, dynamic> forecastJson({double temperature = 25.5}) => {
  'timezone': 'Asia/Kolkata',
  'utc_offset_seconds': 19800,
  'hourly': {
    'time': ['2026-09-30T06:00'],
    'temperature_2m': [temperature],
    'apparent_temperature': [28.0],
    'precipitation_probability': [10],
    'relative_humidity_2m': [80],
    'wind_speed_10m': [6.1],
    'uv_index': [0.0],
    'weather_code': [0],
  },
};

/// Returns [response], or throws [error] when set.
class FakeApiClient implements ApiClient {
  Map<String, dynamic> response = forecastJson();
  Object? error;
  final requests = <(double, double)>[];

  @override
  Future<Map<String, dynamic>> fetchHourlyWeather({
    required double latitude,
    required double longitude,
  }) async {
    requests.add((latitude, longitude));
    if (error != null) throw error!;
    return response;
  }
}

DioException networkError(DioExceptionType type) => DioException(
  requestOptions: RequestOptions(path: '/forecast'),
  type: type,
);

void main() {
  late FakeApiClient api;
  late WeatherCache cache;
  final fetchedAt = DateTime(2026, 9, 28, 16, 32);

  WeatherRepository repository({DateTime? now}) =>
      WeatherRepository(api, cache: cache, clock: () => now ?? fetchedAt);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = FakeApiClient();
    cache = WeatherCache();
  });

  test('a successful response is cached and returned as fresh', () async {
    final forecast = await repository().getHourlyForecast(
      latitude: panaji.lat,
      longitude: panaji.lon,
    );

    expect(forecast.isFromCache, isFalse);
    expect(forecast.hours.single.temperature, 25.5);

    final entry = await cache.load(latitude: panaji.lat, longitude: panaji.lon);
    expect(entry!.cachedAt, fetchedAt);
    expect(entry.forecastJson, forecastJson());
  });

  for (final type in [
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.badResponse,
  ]) {
    test(
      'network failure ($type) returns the matching cached forecast',
      () async {
        await repository().getHourlyForecast(
          latitude: panaji.lat,
          longitude: panaji.lon,
        );

        api.error = networkError(type);
        final forecast = await repository(now: DateTime(2026, 9, 29))
            .getHourlyForecast(latitude: panaji.lat, longitude: panaji.lon);

        expect(forecast.isFromCache, isTrue);
        expect(forecast.cachedAt, fetchedAt); // when it was really fetched
        expect(forecast.hours.single.temperature, 25.5);
      },
    );
  }

  test('network failure without a cache still throws the error', () async {
    api.error = networkError(DioExceptionType.connectionError);

    expect(
      () => repository().getHourlyForecast(
        latitude: panaji.lat,
        longitude: panaji.lon,
      ),
      throwsA(isA<NetworkError>()),
    );
  });

  test('a cache for location A is not used for location B', () async {
    await repository().getHourlyForecast(
      latitude: panaji.lat,
      longitude: panaji.lon,
    );

    api.error = networkError(DioExceptionType.connectionError);

    expect(
      () => repository().getHourlyForecast(
        latitude: mumbai.lat,
        longitude: mumbai.lon,
      ),
      throwsA(isA<NetworkError>()),
    );
  });

  test('a newer successful response replaces the cache', () async {
    await repository().getHourlyForecast(
      latitude: panaji.lat,
      longitude: panaji.lon,
    );
    api.response = forecastJson(temperature: 30);
    final later = DateTime(2026, 9, 28, 18);
    await repository(now: later)
        .getHourlyForecast(latitude: panaji.lat, longitude: panaji.lon);

    api.error = networkError(DioExceptionType.connectionError);
    final forecast = await repository().getHourlyForecast(
      latitude: panaji.lat,
      longitude: panaji.lon,
    );

    expect(forecast.hours.single.temperature, 30);
    expect(forecast.cachedAt, later);
  });

  test('errors that are not network failures are not hidden', () async {
    await repository().getHourlyForecast(
      latitude: panaji.lat,
      longitude: panaji.lon,
    );

    // The API answers, but with data the app can't read.
    api.response = {'timezone': 'Asia/Kolkata'};

    expect(
      () => repository().getHourlyForecast(
        latitude: panaji.lat,
        longitude: panaji.lon,
      ),
      throwsA(isNot(isA<DioException>())),
    );
  });

  test('a cancelled request is not treated as offline', () async {
    await repository().getHourlyForecast(
      latitude: panaji.lat,
      longitude: panaji.lon,
    );
    api.error = networkError(DioExceptionType.cancel);

    expect(
      () => repository().getHourlyForecast(
        latitude: panaji.lat,
        longitude: panaji.lon,
      ),
      throwsA(isA<DioException>()),
    );
  });
}
