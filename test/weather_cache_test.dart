import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:run_ready/core/storage/weather_cache.dart';

const panaji = (lat: 15.4909, lon: 73.8278);
const mumbai = (lat: 19.07283, lon: 72.88261);

Map<String, dynamic> forecastJson(String timezone) => {
  'timezone': timezone,
  'utc_offset_seconds': 19800,
  'hourly': {
    'time': ['2026-09-30T06:00'],
    'temperature_2m': [25.5],
  },
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saves and loads a forecast for the same location', () async {
    final cache = WeatherCache();
    final cachedAt = DateTime(2026, 9, 28, 16, 32);

    await cache.save(
      latitude: panaji.lat,
      longitude: panaji.lon,
      forecastJson: forecastJson('Asia/Kolkata'),
      cachedAt: cachedAt,
    );
    final entry = await cache.load(latitude: panaji.lat, longitude: panaji.lon);

    expect(entry, isNotNull);
    expect(entry!.latitude, panaji.lat);
    expect(entry.longitude, panaji.lon);
    expect(entry.cachedAt, cachedAt); // timestamp preserved
    expect(entry.forecastJson, forecastJson('Asia/Kolkata'));
  });

  test('a cache for location A is not returned for location B', () async {
    final cache = WeatherCache();
    await cache.save(
      latitude: panaji.lat,
      longitude: panaji.lon,
      forecastJson: forecastJson('Asia/Kolkata'),
      cachedAt: DateTime(2026, 9, 28),
    );

    expect(
      await cache.load(latitude: mumbai.lat, longitude: mumbai.lon),
      isNull,
    );
  });

  test('each location keeps its own entry', () async {
    final cache = WeatherCache();
    await cache.save(
      latitude: panaji.lat,
      longitude: panaji.lon,
      forecastJson: forecastJson('panaji'),
      cachedAt: DateTime(2026, 9, 28, 8),
    );
    await cache.save(
      latitude: mumbai.lat,
      longitude: mumbai.lon,
      forecastJson: forecastJson('mumbai'),
      cachedAt: DateTime(2026, 9, 28, 9),
    );

    final p = await cache.load(latitude: panaji.lat, longitude: panaji.lon);
    final m = await cache.load(latitude: mumbai.lat, longitude: mumbai.lon);
    expect(p!.forecastJson['timezone'], 'panaji');
    expect(m!.forecastJson['timezone'], 'mumbai');
  });

  test('the cache survives an app restart (serialized to storage)', () async {
    final cachedAt = DateTime(2026, 9, 28, 16, 32);
    await WeatherCache().save(
      latitude: panaji.lat,
      longitude: panaji.lon,
      forecastJson: forecastJson('Asia/Kolkata'),
      cachedAt: cachedAt,
    );

    // Everything the device would keep is a plain string.
    final key = WeatherCache.keyFor(panaji.lat, panaji.lon);
    final stored = (await SharedPreferences.getInstance()).getString(key)!;

    // "Restart": fresh preferences holding only that string, fresh cache.
    SharedPreferences.setMockInitialValues({key: stored});
    final entry = await WeatherCache().load(
      latitude: panaji.lat,
      longitude: panaji.lon,
    );

    expect(entry!.cachedAt, cachedAt);
    expect(entry.forecastJson, forecastJson('Asia/Kolkata'));
  });

  test('a corrupted entry counts as no cache', () async {
    final key = WeatherCache.keyFor(panaji.lat, panaji.lon);
    SharedPreferences.setMockInitialValues({key: 'not json'});

    expect(
      await WeatherCache().load(latitude: panaji.lat, longitude: panaji.lon),
      isNull,
    );
  });

  test('clear removes cached forecasts but nothing else', () async {
    SharedPreferences.setMockInitialValues({'other_setting': true});
    final cache = WeatherCache();
    await cache.save(
      latitude: panaji.lat,
      longitude: panaji.lon,
      forecastJson: forecastJson('Asia/Kolkata'),
      cachedAt: DateTime(2026, 9, 28),
    );

    await cache.clear();

    expect(
      await cache.load(latitude: panaji.lat, longitude: panaji.lon),
      isNull,
    );
    expect(
      (await SharedPreferences.getInstance()).getBool('other_setting'),
      isTrue,
    );
  });
}
