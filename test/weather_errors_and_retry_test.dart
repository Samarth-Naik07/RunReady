import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:run_ready/core/errors/app_error.dart';
import 'package:run_ready/core/network/api_client.dart';
import 'package:run_ready/core/storage/weather_cache.dart';
import 'package:run_ready/features/location/data/location_models.dart';
import 'package:run_ready/features/weather/data/weather_repository.dart';
import 'package:run_ready/features/weather/providers/weather_provider.dart';
import 'package:run_ready/main.dart';

/// A valid Open-Meteo response: 48 hours from midnight today, all at
/// [temperature] °C.
Map<String, dynamic> forecastJson({double temperature = 25}) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final times = [
    for (var h = 0; h < 48; h++)
      start.add(Duration(hours: h)).toIso8601String().substring(0, 16),
  ];
  List<num> all(num value) => List.filled(times.length, value);
  return {
    'timezone': 'Asia/Kolkata',
    'hourly': {
      'time': times,
      'temperature_2m': all(temperature),
      'apparent_temperature': all(temperature + 2),
      'precipitation_probability': all(10),
      'relative_humidity_2m': all(70),
      'wind_speed_10m': all(8),
      'uv_index': all(2),
      'weather_code': all(0),
    },
  };
}

/// Each call takes the next scripted outcome: a JSON map or an error.
class ScriptedApiClient implements ApiClient {
  ScriptedApiClient(this.outcomes);

  final List<Object> outcomes;
  var calls = 0;

  @override
  Future<Map<String, dynamic>> fetchHourlyWeather({
    required double latitude,
    required double longitude,
  }) async {
    final outcome =
        outcomes[calls < outcomes.length ? calls : outcomes.length - 1];
    calls++;
    if (outcome is Map<String, dynamic>) return outcome;
    throw outcome;
  }
}

DioException dio(DioExceptionType type) => DioException(
  requestOptions: RequestOptions(path: '/forecast'),
  type: type,
);

final offline = dio(DioExceptionType.connectionError);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<Object> errorFrom(ScriptedApiClient api, {WeatherCache? cache}) async {
    try {
      await WeatherRepository(api, cache: cache).getHourlyForecast(
        latitude: panaji.latitude,
        longitude: panaji.longitude,
      );
    } catch (error) {
      return error;
    }
    fail('expected an error');
  }

  group('repository error mapping', () {
    test('timeout → TimeoutError', () async {
      final api = ScriptedApiClient([dio(DioExceptionType.receiveTimeout)]);
      expect(await errorFrom(api), isA<TimeoutError>());
    });

    test('no connection → NetworkError', () async {
      expect(
        await errorFrom(ScriptedApiClient([offline])),
        isA<NetworkError>(),
      );
    });

    test('HTTP error → ServerError', () async {
      final options = RequestOptions(path: '/forecast');
      final api = ScriptedApiClient([
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: options, statusCode: 500),
        ),
      ]);

      final error = await errorFrom(api);
      expect(error, isA<ServerError>());
      expect((error as ServerError).statusCode, 500);
    });

    test('malformed response → InvalidDataError', () async {
      final api = ScriptedApiClient([
        {'timezone': 'Asia/Kolkata'}, // no "hourly"
      ]);
      expect(await errorFrom(api), isA<InvalidDataError>());
    });

    test('unexpected exception → UnknownError', () async {
      final api = ScriptedApiClient([StateError('boom')]);
      expect(await errorFrom(api), isA<UnknownError>());
    });

    test('cancellation is still rethrown as a DioException', () async {
      final api = ScriptedApiClient([dio(DioExceptionType.cancel)]);
      expect(await errorFrom(api), isA<DioException>());
    });
  });

  group('cache and errors', () {
    test('network failure with a cache still returns cached data', () async {
      final cache = WeatherCache();
      final api = ScriptedApiClient([forecastJson(), offline]);
      final repository = WeatherRepository(api, cache: cache);

      await repository.getHourlyForecast(
        latitude: panaji.latitude,
        longitude: panaji.longitude,
      );
      final forecast = await repository.getHourlyForecast(
        latitude: panaji.latitude,
        longitude: panaji.longitude,
      );

      expect(forecast.isFromCache, isTrue);
    });

    test('a parsing failure is not hidden by the cache, and does not '
        'overwrite it', () async {
      final cache = WeatherCache();
      final api = ScriptedApiClient([
        forecastJson(temperature: 25),
        {'timezone': 'broken'},
        offline,
      ]);
      final repository = WeatherRepository(api, cache: cache);
      Future<void> fetch() => repository.getHourlyForecast(
        latitude: panaji.latitude,
        longitude: panaji.longitude,
      );

      await fetch(); // good data, cached
      await expectLater(fetch(), throwsA(isA<InvalidDataError>()));

      // The good forecast is still what the cache holds.
      final cached = await repository.getHourlyForecast(
        latitude: panaji.latitude,
        longitude: panaji.longitude,
      );
      expect(cached.isFromCache, isTrue);
      expect(cached.hours.first.temperature, 25);
    });
  });

  group('retry via the provider', () {
    ProviderContainer containerWith(ApiClient api) {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          weatherCacheProvider.overrideWithValue(WeatherCache()),
        ],
      );
      addTearDown(container.dispose);
      container.listen(weatherForecastProvider, (_, _) {});
      return container;
    }

    Future<AsyncValue<Object>> settle(ProviderContainer container) async {
      try {
        await container.read(weatherForecastProvider.future);
      } catch (_) {}
      return container.read(weatherForecastProvider);
    }

    test('a retry that succeeds shows fresh data', () async {
      final api = ScriptedApiClient([offline, forecastJson()]);
      final container = containerWith(api);

      final first = await settle(container);
      expect(first.error, isA<NetworkError>());
      expect(api.calls, 1); // no automatic retries

      container.invalidate(weatherForecastProvider);
      final second = await settle(container);

      expect(api.calls, 2); // Retry made a new network request
      expect(second.hasError, isFalse);
      expect(
        container.read(weatherForecastProvider).value!.isFromCache,
        isFalse,
      );
    });

    test(
      'a retry that fails without a cache stays on the mapped error',
      () async {
        final api = ScriptedApiClient([
          dio(DioExceptionType.connectionTimeout),
          offline,
        ]);
        final container = containerWith(api);

        expect((await settle(container)).error, isA<TimeoutError>());

        container.invalidate(weatherForecastProvider);
        final retried = await settle(container);

        expect(api.calls, 2);
        expect(retried.error, isA<NetworkError>()); // the latest failure
      },
    );

    test('a retry that fails with a cache returns to cached data', () async {
      final api = ScriptedApiClient([forecastJson(), offline]);
      final container = containerWith(api);

      expect((await settle(container)).value, isNotNull); // fresh, cached

      container.invalidate(weatherForecastProvider);
      await settle(container);

      expect(api.calls, 2);
      expect(
        container.read(weatherForecastProvider).value!.isFromCache,
        isTrue,
      );
    });
  });

  testWidgets('home shows the mapped message, and Retry loads fresh data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final api = ScriptedApiClient([offline, forecastJson(temperature: 25)]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          weatherCacheProvider.overrideWithValue(WeatherCache()),
        ],
        child: const RunReadyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("You're offline. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.textContaining('DioException'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('25°C'), findsOneWidget);
    expect(find.textContaining("You're offline"), findsNothing);
    expect(find.textContaining('Last updated'), findsNothing); // fresh data
  });
}
