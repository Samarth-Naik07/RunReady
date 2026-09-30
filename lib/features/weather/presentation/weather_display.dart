import 'package:flutter/material.dart';

/// WHO UV index category for a value.
String uvLevel(double uv) {
  if (uv < 3) return 'Low';
  if (uv < 6) return 'Moderate';
  if (uv < 8) return 'High';
  if (uv < 11) return 'Very high';
  return 'Extreme';
}

const _sun = Color(0xFFFFB300);
const _cloud = Color(0xFF8FB8E8);
const _rain = Color(0xFF3D8BF2);

/// Maps a WMO weather code to a label and an icon widget of [size].
/// [hourOfDay] picks night icons between 7 pm and 6 am.
(String, Widget) weatherInfo(int code, int hourOfDay, {double size = 96}) {
  final isNight = hourOfDay < 6 || hourOfDay >= 19;

  // A single weather icon at the requested size.
  Widget icon(IconData data, Color color) =>
      Icon(data, size: size, color: color);

  return switch (code) {
    0 when isNight => ('Clear night', icon(Icons.nightlight_round, _cloud)),
    0 => ('Sunny', icon(Icons.wb_sunny_rounded, _sun)),
    1 || 2 when isNight => (
      'Partly cloudy',
      icon(Icons.nights_stay_rounded, _cloud),
    ),
    1 || 2 => ('Partly cloudy', SunBehindCloud(size: size)),
    3 => ('Cloudy', icon(Icons.cloud_rounded, _cloud)),
    45 || 48 => ('Foggy', icon(Icons.foggy, _cloud)),
    >= 51 && <= 57 => ('Drizzle', icon(Icons.grain_rounded, _rain)),
    >= 61 && <= 67 ||
    >= 80 && <= 82 => ('Rain', icon(Icons.umbrella_rounded, _rain)),
    >= 71 && <= 77 || 85 || 86 => ('Snow', icon(Icons.ac_unit_rounded, _cloud)),
    >= 95 => ('Thunderstorm', icon(Icons.thunderstorm_rounded, _rain)),
    _ => ('Unknown', icon(Icons.help_outline_rounded, _cloud)),
  };
}

/// A sun peeking out from behind a cloud, like the reference design.
class SunBehindCloud extends StatelessWidget {
  const SunBehindCloud({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.15,
      height: size,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Icon(Icons.wb_sunny_rounded, size: size * 0.67, color: _sun),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: Icon(Icons.cloud_rounded, size: size * 0.92, color: _cloud),
          ),
        ],
      ),
    );
  }
}
