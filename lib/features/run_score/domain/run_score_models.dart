import '../../weather/data/weather_models.dart';

/// The Run Score for a single forecast hour.
class HourlyRunScore {
  const HourlyRunScore({required this.hour, required this.score});

  /// The forecast hour that was scored.
  final HourlyWeather hour;

  /// Run Score from 0 (don't run) to 100 (perfect running weather).
  final double score;
}

/// A block of consecutive hours and its average Run Score.
class RunWindow {
  const RunWindow({
    required this.start,
    required this.end,
    required this.score,
    required this.hourlyScores,
  });

  /// When the window starts, e.g. 06:00.
  final DateTime start;

  /// When the window ends, e.g. 08:00 for a window covering 06:00 and 07:00.
  final DateTime end;

  /// Average Run Score of the hours in the window, 0–100.
  final double score;

  /// The individual hours in the window, in order.
  final List<HourlyRunScore> hourlyScores;
}
