import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/weather_cache.dart';
import '../../location/providers/location_provider.dart';
import '../data/weather_models.dart';
import '../data/weather_repository.dart';

/// The single shared [ApiClient] (and its Dio instance) for the app.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

/// The on-device forecast cache used when the network is unavailable.
final weatherCacheProvider = Provider<WeatherCache>((ref) {
  return WeatherCache();
});

/// The [WeatherRepository], built from whatever [apiClientProvider] and
/// [weatherCacheProvider] provide.
final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final cache = ref.watch(weatherCacheProvider);
  return WeatherRepository(apiClient, cache: cache);
});

/// The hourly forecast for the selected location.
///
/// Watches [selectedLocationProvider], so choosing a new place refetches the
/// forecast automatically. Widgets watching this get an
/// `AsyncValue<HourlyForecast>`, which is either loading, data, or an error
/// (an `AppError` from the repository).
///
/// Automatic retries are off: an error shows straight away and the user
/// retries with the Retry button (`ref.invalidate(weatherForecastProvider)`).
final weatherForecastProvider = FutureProvider<HourlyForecast>((ref) {
  final repository = ref.watch(weatherRepositoryProvider);
  final location = ref.watch(selectedLocationProvider);
  return repository.getHourlyForecast(
    latitude: location.latitude,
    longitude: location.longitude,
  );
}, retry: (retryCount, error) => null);
