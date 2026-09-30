import '../../weather/data/weather_models.dart';
import 'run_score_models.dart';

/// Turns hourly weather into Run Scores and finds the best time to run.
///
/// Every factor is scored from 0 to 100, then combined with fixed weights.
/// There is no randomness or clock access, so the same input always gives the
/// same result.
class RunScoreCalculator {
  const RunScoreCalculator();

  // How much each factor counts towards the Run Score. They add up to 1.0.
  static const temperatureWeight = 0.35;
  static const rainWeight = 0.30;
  static const windWeight = 0.20;
  static const uvWeight = 0.10;
  static const humidityWeight = 0.05;

  /// Scores the feels-like temperature in °C.
  ///
  /// 10–20 °C is ideal (100). The score falls linearly to 0 at -10 °C on the
  /// cold side and at 40 °C on the hot side.
  double temperatureScore(double feelsLike) {
    const coldLimit = -10.0;
    const idealMin = 10.0;
    const idealMax = 20.0;
    const hotLimit = 40.0;

    if (feelsLike < idealMin) {
      return _scale(feelsLike, from: coldLimit, to: idealMin);
    }
    if (feelsLike > idealMax) {
      return 100 - _scale(feelsLike, from: idealMax, to: hotLimit);
    }
    return 100;
  }

  /// Scores the chance of rain (0–100 %): 0 % rain is 100, 100 % rain is 0.
  double rainScore(int precipitationProbability) {
    return 100 - _scale(precipitationProbability.toDouble(), from: 0, to: 100);
  }

  /// Scores wind speed in km/h: up to 10 km/h is 100, falling to 0 at 40 km/h.
  double windScore(double windSpeed) {
    return 100 - _scale(windSpeed, from: 10, to: 40);
  }

  /// Scores the UV index: up to 2 (low) is 100, falling to 0 at 10.
  double uvScore(double uvIndex) {
    return 100 - _scale(uvIndex, from: 2, to: 10);
  }

  /// Scores relative humidity (0–100 %): up to 60 % is 100, falling to 0 at
  /// 100 %.
  double humidityScore(int relativeHumidity) {
    return 100 - _scale(relativeHumidity.toDouble(), from: 60, to: 100);
  }

  /// The weighted Run Score (0–100) for one forecast hour.
  HourlyRunScore scoreHour(HourlyWeather hour) {
    final score =
        temperatureScore(hour.apparentTemperature) * temperatureWeight +
        rainScore(hour.precipitationProbability) * rainWeight +
        windScore(hour.windSpeed) * windWeight +
        uvScore(hour.uvIndex) * uvWeight +
        humidityScore(hour.relativeHumidity) * humidityWeight;

    return HourlyRunScore(hour: hour, score: score);
  }

  /// Scores every hour in [hours], keeping their order.
  List<HourlyRunScore> scoreHours(List<HourlyWeather> hours) {
    return [for (final hour in hours) scoreHour(hour)];
  }

  /// Finds the consecutive [windowHours]-hour block with the highest average
  /// Run Score.
  ///
  /// Only back-to-back hours (exactly one hour apart) form a window. On a tie,
  /// the earliest window wins. Returns null if no window fits.
  RunWindow? bestWindow(List<HourlyWeather> hours, {int windowHours = 2}) {
    RunWindow? best;
    for (final window in allWindows(hours, windowHours: windowHours)) {
      if (best == null || window.score > best.score) best = window;
    }
    return best;
  }

  /// Every consecutive [windowHours]-hour window in [hours], in time order.
  ///
  /// Only back-to-back hours (exactly one hour apart) form a window.
  List<RunWindow> allWindows(List<HourlyWeather> hours, {int windowHours = 2}) {
    final scores = scoreHours(hours);

    return [
      for (var i = 0; i + windowHours <= scores.length; i++)
        if (_areConsecutive(scores.sublist(i, i + windowHours)))
          _toWindow(scores.sublist(i, i + windowHours)),
    ];
  }

  /// Up to [maxCount] windows that don't overlap, best first.
  ///
  /// The first entry is always the same as [bestWindow]. Each next entry is
  /// the best remaining window that shares no hour with the ones already
  /// picked, so the list never repeats nearly the same time. Ties go to the
  /// earlier window.
  List<RunWindow> rankedWindows(
    List<HourlyWeather> hours, {
    int windowHours = 2,
    int maxCount = 5,
  }) {
    final candidates = allWindows(hours, windowHours: windowHours)
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        return byScore != 0 ? byScore : a.start.compareTo(b.start);
      });

    final picked = <RunWindow>[];
    for (final window in candidates) {
      if (picked.length == maxCount) break;
      final overlaps = picked.any(
        (p) => window.start.isBefore(p.end) && p.start.isBefore(window.end),
      );
      if (!overlaps) picked.add(window);
    }
    return picked;
  }

  /// Builds a [RunWindow] from consecutive scored hours.
  RunWindow _toWindow(List<HourlyRunScore> window) {
    final average =
        window.map((s) => s.score).reduce((a, b) => a + b) / window.length;

    return RunWindow(
      start: window.first.hour.time,
      end: window.last.hour.time.add(const Duration(hours: 1)),
      score: average,
      hourlyScores: List.unmodifiable(window),
    );
  }

  /// True if each hour is exactly one hour after the previous one.
  bool _areConsecutive(List<HourlyRunScore> window) {
    for (var i = 1; i < window.length; i++) {
      final gap = window[i].hour.time.difference(window[i - 1].hour.time);
      if (gap != const Duration(hours: 1)) return false;
    }
    return true;
  }

  /// Where [value] sits between [from] and [to], as 0–100 (clamped).
  ///
  /// For example, 25 between 10 and 40 is 50.
  double _scale(double value, {required double from, required double to}) {
    final fraction = (value - from) / (to - from);
    return fraction.clamp(0.0, 1.0) * 100;
  }
}
