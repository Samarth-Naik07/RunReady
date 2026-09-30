import '../../../core/network/geocoding_api_client.dart';
import 'location_models.dart';

/// Gives the rest of the app typed location search results.
class LocationRepository {
  const LocationRepository(this._apiClient);

  /// Queries shorter than this are not sent to the API.
  static const minQueryLength = 2;

  final GeocodingApiClient _apiClient;

  /// Finds places matching [query].
  ///
  /// Returns an empty list, without a request, when the trimmed query is
  /// shorter than [minQueryLength].
  Future<List<GeoLocation>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < minQueryLength) return const [];

    final json = await _apiClient.searchLocations(trimmed);
    return parseGeocodingResults(json);
  }
}
