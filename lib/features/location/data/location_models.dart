/// A place returned by the Open-Meteo Geocoding API.
class GeoLocation {
  const GeoLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.region,
    this.country,
    this.countryCode,
    this.timezone,
  });

  /// Builds a location from one entry of the geocoding `results` array.
  factory GeoLocation.fromJson(Map<String, dynamic> json) {
    return GeoLocation(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      region: json['admin1'] as String?,
      country: json['country'] as String?,
      countryCode: json['country_code'] as String?,
      timezone: json['timezone'] as String?,
    );
  }

  /// Geocoding ID, unique per place.
  final int id;

  /// Place name, e.g. "Mumbai".
  final String name;

  final double latitude;
  final double longitude;

  /// State or region (`admin1`), e.g. "Maharashtra". Not always present.
  final String? region;

  /// Country name, e.g. "India". Not always present.
  final String? country;

  /// ISO country code, e.g. "IN".
  final String? countryCode;

  /// IANA timezone, e.g. "Asia/Kolkata".
  final String? timezone;

  /// Short name for headers, e.g. "Panaji, Goa" or "Paris, Île-de-France".
  String get displayName {
    if (region == null || region == name) return name;
    return '$name, $region';
  }

  /// Where the place is, e.g. "Goa, India". Empty if nothing is known.
  String get areaDescription {
    return [?region, ?country].join(', ');
  }
}

/// Parses a geocoding response into locations.
///
/// Open-Meteo leaves out the `results` key entirely when nothing matches, so
/// that case returns an empty list.
List<GeoLocation> parseGeocodingResults(Map<String, dynamic> json) {
  final results = json['results'] as List<dynamic>? ?? const [];
  return List.unmodifiable([
    for (final result in results)
      GeoLocation.fromJson(result as Map<String, dynamic>),
  ]);
}

/// The default location: Panaji, Goa.
const panaji = GeoLocation(
  id: 1260607,
  name: 'Panaji',
  latitude: 15.4909,
  longitude: 73.8278,
  region: 'Goa',
  country: 'India',
  countryCode: 'IN',
  timezone: 'Asia/Kolkata',
);
