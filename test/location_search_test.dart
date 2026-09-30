import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:run_ready/core/network/geocoding_api_client.dart';
import 'package:run_ready/features/location/data/location_models.dart';
import 'package:run_ready/features/location/data/location_repository.dart';
import 'package:run_ready/features/location/providers/location_provider.dart';
import 'package:run_ready/features/weather/data/weather_models.dart';
import 'package:run_ready/features/weather/data/weather_repository.dart';
import 'package:run_ready/features/weather/providers/weather_provider.dart';
import 'package:run_ready/main.dart';

/// Records every query and answers with [results] (or throws if [fail]).
class FakeGeocodingApiClient implements GeocodingApiClient {
  final queries = <String>[];
  bool fail = false;
  List<Map<String, dynamic>> results = [mumbaiJson];

  @override
  Future<Map<String, dynamic>> searchLocations(
    String name, {
    int count = 10,
  }) async {
    queries.add(name);
    if (fail) throw Exception('offline');
    return {'results': results};
  }
}

/// Records the coordinates it was asked for.
class FakeWeatherRepository implements WeatherRepository {
  final requests = <(double, double)>[];

  @override
  Future<HourlyForecast> getHourlyForecast({
    required double latitude,
    required double longitude,
  }) async {
    requests.add((latitude, longitude));
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return HourlyForecast(
      timezone: 'Asia/Kolkata',
      hours: [
        for (var h = 0; h < 48; h++)
          HourlyWeather(
            time: start.add(Duration(hours: h)),
            temperature: 25,
            apparentTemperature: 27,
            precipitationProbability: 10,
            relativeHumidity: 70,
            windSpeed: 8,
            uvIndex: 2,
            weatherCode: 0,
          ),
      ],
    );
  }
}

const mumbaiJson = <String, dynamic>{
  'id': 1275339,
  'name': 'Mumbai',
  'latitude': 19.07283,
  'longitude': 72.88261,
  'country_code': 'IN',
  'timezone': 'Asia/Kolkata',
  'country': 'India',
  'admin1': 'Maharashtra',
};

void main() {
  group('LocationRepository', () {
    test('does not call the API for empty or 1-letter queries', () async {
      final api = FakeGeocodingApiClient();
      final repository = LocationRepository(api);

      expect(await repository.search(''), isEmpty);
      expect(await repository.search('   '), isEmpty);
      expect(await repository.search(' M '), isEmpty);
      expect(api.queries, isEmpty);
    });

    test('trims the query and returns typed results', () async {
      final api = FakeGeocodingApiClient();

      final results = await LocationRepository(api).search('  Mumbai ');

      expect(api.queries, ['Mumbai']);
      expect(results.single.displayName, 'Mumbai, Maharashtra');
    });
  });

  group('locationSearchProvider', () {
    // testWidgets runs timers on a fake clock that tester.pump() advances,
    // so the debounce can be tested without real waiting.
    late FakeGeocodingApiClient api;
    late ProviderContainer container;

    void setUpContainer() {
      api = FakeGeocodingApiClient();
      container = ProviderContainer(
        overrides: [geocodingApiClientProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      // Keep the auto-disposed provider alive for the whole test.
      container.listen(locationSearchProvider, (_, _) {});
    }

    LocationSearchNotifier notifier() =>
        container.read(locationSearchProvider.notifier);

    testWidgets('waits for typing to pause, then searches once', (
      tester,
    ) async {
      setUpContainer();

      notifier().onQueryChanged('Mu');
      await tester.pump(const Duration(milliseconds: 200));
      notifier().onQueryChanged('Mum');
      await tester.pump(const Duration(milliseconds: 200));
      notifier().onQueryChanged('Mumbai');
      await tester.pump(const Duration(milliseconds: 399));

      // Still inside the 400 ms pause: nothing sent yet, but loading shows.
      expect(api.queries, isEmpty);
      expect(container.read(locationSearchProvider), isA<AsyncLoading>());

      await tester.pump(const Duration(milliseconds: 1));

      expect(api.queries, ['Mumbai']); // one request, for the final text
      expect(
        container.read(locationSearchProvider)!.value!.single.name,
        'Mumbai',
      );
    });

    testWidgets('short queries stay idle and send nothing', (tester) async {
      setUpContainer();

      notifier().onQueryChanged('M');
      await tester.pump(const Duration(seconds: 1));

      expect(container.read(locationSearchProvider), isNull);
      expect(api.queries, isEmpty);
    });

    testWidgets('no matches gives an empty list', (tester) async {
      setUpContainer();
      api.results = [];

      notifier().onQueryChanged('zzqxw');
      await tester.pump(const Duration(milliseconds: 400));

      expect(container.read(locationSearchProvider)!.value, isEmpty);
    });

    testWidgets('errors can be retried', (tester) async {
      setUpContainer();
      api.fail = true;

      notifier().onQueryChanged('Mumbai');
      await tester.pump(const Duration(milliseconds: 400));
      expect(container.read(locationSearchProvider), isA<AsyncError>());

      api.fail = false;
      notifier().retry();
      await tester.pump();

      expect(api.queries, ['Mumbai', 'Mumbai']);
      expect(container.read(locationSearchProvider)!.value, hasLength(1));
    });
  });

  testWidgets('choosing a place updates the header and refetches weather', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final api = FakeGeocodingApiClient();
    final weather = FakeWeatherRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          geocodingApiClientProvider.overrideWithValue(api),
          weatherRepositoryProvider.overrideWithValue(weather),
        ],
        child: const RunReadyApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Starts in Panaji.
    expect(find.text('Panaji, Goa'), findsOneWidget);
    expect(weather.requests, [(panaji.latitude, panaji.longitude)]);

    // Open search from the header and look for Mumbai.
    await tester.tap(find.text('Panaji, Goa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Mumbai');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('Maharashtra, India'), findsOneWidget);

    // "Mumbai" is also in the text box, so tap the result row itself.
    await tester.tap(find.widgetWithText(ListTile, 'Mumbai'));
    await tester.pumpAndSettle();

    // Back home: new name, and the forecast was fetched for Mumbai.
    expect(find.text('Mumbai, Maharashtra'), findsOneWidget);
    expect(weather.requests.last, (19.07283, 72.88261));
    expect(weather.requests, hasLength(2));
  });
}
