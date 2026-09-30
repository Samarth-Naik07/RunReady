import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One saved forecast: where it is for, when it was fetched, and the raw
/// Open-Meteo JSON.
class CachedForecast {
  const CachedForecast({
    required this.latitude,
    required this.longitude,
    required this.cachedAt,
    required this.forecastJson,
  });

  factory CachedForecast.fromJson(Map<String, dynamic> json) {
    return CachedForecast(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      cachedAt: DateTime.parse(json['cachedAt'] as String).toLocal(),
      forecastJson: json['forecast'] as Map<String, dynamic>,
    );
  }

  final double latitude;
  final double longitude;

  /// When the forecast was fetched from the network.
  final DateTime cachedAt;

  /// The forecast exactly as the API returned it.
  final Map<String, dynamic> forecastJson;

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    // Stored in UTC so it reads back as the same moment after a restart.
    'cachedAt': cachedAt.toUtc().toIso8601String(),
    'forecast': forecastJson,
  };
}

/// Saves the latest forecast per location on the device, so it can be shown
/// when the network is unavailable. Survives app restarts.
///
/// Each location has its own entry, keyed by its coordinates, so a cached
/// Panaji forecast is never returned for Mumbai.
class WeatherCache {
  WeatherCache({this._preferences});

  /// All cache keys start with this, so [clear] only touches weather data.
  static const _keyPrefix = 'weather_cache_';

  Future<SharedPreferences>? _preferences;

  /// Opened on first use rather than at startup.
  Future<SharedPreferences> get _prefs =>
      _preferences ??= SharedPreferences.getInstance();

  /// One key per location, e.g. "weather_cache_15.4909_73.8278".
  ///
  /// Four decimals is about 11 m, so tiny floating-point differences in the
  /// same place's coordinates still find the same entry.
  static String keyFor(double latitude, double longitude) =>
      '$_keyPrefix${latitude.toStringAsFixed(4)}_'
      '${longitude.toStringAsFixed(4)}';

  /// Saves [forecastJson] for this location, replacing any older entry.
  Future<void> save({
    required double latitude,
    required double longitude,
    required Map<String, dynamic> forecastJson,
    required DateTime cachedAt,
  }) async {
    final entry = CachedForecast(
      latitude: latitude,
      longitude: longitude,
      cachedAt: cachedAt,
      forecastJson: forecastJson,
    );
    final prefs = await _prefs;
    await prefs.setString(
      keyFor(latitude, longitude),
      jsonEncode(entry.toJson()),
    );
  }

  /// The saved forecast for this location, or `null` if there is none.
  ///
  /// An unreadable entry (for example from an older app version) counts as
  /// "no cache" rather than crashing.
  Future<CachedForecast?> load({
    required double latitude,
    required double longitude,
  }) async {
    final prefs = await _prefs;
    final raw = prefs.getString(keyFor(latitude, longitude));
    if (raw == null) return null;

    try {
      return CachedForecast.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Removes every cached forecast.
  Future<void> clear() async {
    final prefs = await _prefs;
    for (final key in prefs.getKeys().where((k) => k.startsWith(_keyPrefix))) {
      await prefs.remove(key);
    }
  }
}
