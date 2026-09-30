import 'package:flutter_test/flutter_test.dart';

import 'package:run_ready/features/location/data/location_models.dart';

void main() {
  group('parseGeocodingResults', () {
    test('parses a full Open-Meteo result', () {
      final json = <String, dynamic>{
        'results': [
          {
            'id': 1275339,
            'name': 'Mumbai',
            'latitude': 19.07283,
            'longitude': 72.88261,
            'elevation': 14.0,
            'feature_code': 'PPLA',
            'country_code': 'IN',
            'timezone': 'Asia/Kolkata',
            'country': 'India',
            'admin1': 'Maharashtra',
          },
        ],
        'generationtime_ms': 0.5,
      };

      final results = parseGeocodingResults(json);

      expect(results, hasLength(1));
      final mumbai = results.single;
      expect(mumbai.id, 1275339);
      expect(mumbai.name, 'Mumbai');
      expect(mumbai.latitude, 19.07283);
      expect(mumbai.longitude, 72.88261);
      expect(mumbai.region, 'Maharashtra');
      expect(mumbai.country, 'India');
      expect(mumbai.countryCode, 'IN');
      expect(mumbai.timezone, 'Asia/Kolkata');
      expect(mumbai.displayName, 'Mumbai, Maharashtra');
      expect(mumbai.areaDescription, 'Maharashtra, India');
    });

    test('handles missing optional fields and whole-number coordinates', () {
      final json = <String, dynamic>{
        'results': [
          {'id': 7, 'name': 'Somewhere', 'latitude': 10, 'longitude': -5},
        ],
      };

      final place = parseGeocodingResults(json).single;

      expect(place.latitude, 10.0);
      expect(place.longitude, -5.0);
      expect(place.region, isNull);
      expect(place.country, isNull);
      expect(place.displayName, 'Somewhere');
      expect(place.areaDescription, '');
    });

    test('returns an empty list when Open-Meteo omits "results"', () {
      // This is what the API sends when nothing matches.
      expect(parseGeocodingResults({'generationtime_ms': 0.5}), isEmpty);
    });
  });

  test('the default location is Panaji, Goa', () {
    expect(panaji.displayName, 'Panaji, Goa');
    expect(panaji.latitude, 15.4909);
    expect(panaji.longitude, 73.8278);
  });
}
