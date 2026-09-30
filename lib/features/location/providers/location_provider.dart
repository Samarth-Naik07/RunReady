import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/geocoding_api_client.dart';
import '../data/location_models.dart';
import '../data/location_repository.dart';

/// The single shared [GeocodingApiClient].
final geocodingApiClientProvider = Provider<GeocodingApiClient>((ref) {
  return GeocodingApiClient();
});

/// The [LocationRepository], built from [geocodingApiClientProvider].
final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(ref.watch(geocodingApiClientProvider));
});

/// The location the weather is shown for. Starts as Panaji.
final selectedLocationProvider =
    NotifierProvider<SelectedLocationNotifier, GeoLocation>(
      SelectedLocationNotifier.new,
    );

class SelectedLocationNotifier extends Notifier<GeoLocation> {
  @override
  GeoLocation build() => panaji;

  /// Switches the app to [location]. The forecast refetches automatically.
  void select(GeoLocation location) => state = location;
}

/// How long typing must pause before a search is sent.
final searchDebounceProvider = Provider<Duration>((ref) {
  return const Duration(milliseconds: 400);
});

/// Search results for the text in the search box.
///
/// The state is:
/// - `null` while the query is too short to search (the idle state),
/// - `AsyncLoading` while waiting for the debounce or the API,
/// - `AsyncData` with the results (possibly an empty list),
/// - `AsyncError` if the request failed.
///
/// Auto-disposed, so it resets each time the search screen closes.
final locationSearchProvider =
    NotifierProvider.autoDispose<
      LocationSearchNotifier,
      AsyncValue<List<GeoLocation>>?
    >(LocationSearchNotifier.new);

class LocationSearchNotifier extends Notifier<AsyncValue<List<GeoLocation>>?> {
  Timer? _debounce;

  /// The latest query, used by [retry] and to ignore out-of-date responses.
  String _query = '';

  @override
  AsyncValue<List<GeoLocation>>? build() {
    ref.onDispose(() => _debounce?.cancel());
    return null;
  }

  /// Call on every keystroke. Waits for typing to pause before searching.
  void onQueryChanged(String text) {
    _query = text.trim();
    _debounce?.cancel();

    if (_query.length < LocationRepository.minQueryLength) {
      state = null;
      return;
    }

    state = const AsyncLoading();
    _debounce = Timer(ref.read(searchDebounceProvider), () => _search(_query));
  }

  /// Searches the latest query again straight away, e.g. after an error.
  void retry() {
    _debounce?.cancel();
    if (_query.length < LocationRepository.minQueryLength) return;
    state = const AsyncLoading();
    _search(_query);
  }

  Future<void> _search(String query) async {
    final result = await AsyncValue.guard(
      () => ref.read(locationRepositoryProvider).search(query),
    );

    // Drop the result if the screen closed or the user typed something else
    // while this request was running.
    if (!ref.mounted || query != _query) return;
    state = result;
  }
}
