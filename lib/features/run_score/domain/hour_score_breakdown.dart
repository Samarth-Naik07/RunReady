import '../../weather/data/weather_models.dart';
import 'run_score_calculator.dart';

/// How one weather factor contributed to an hour's Run Score.
class FactorContribution {
  const FactorContribution({
    required this.label,
    required this.sentenceName,
    required this.value,
    required this.factorScore,
    required this.weight,
  });

  /// Name of the factor, e.g. "Rain chance".
  final String label;

  /// The name as used mid-sentence, e.g. "rain chance".
  final String sentenceName;

  /// The weather value, formatted for display, e.g. "30%".
  final String value;

  /// The factor's own score, 0–100, from [RunScoreCalculator].
  final double factorScore;

  /// The factor's weight in the Run Score, e.g. 0.30.
  final double weight;

  /// Points this factor added to the Run Score.
  double get points => factorScore * weight;

  /// The most points this factor can add.
  double get maxPoints => 100 * weight;

  /// Points lost compared with perfect conditions for this factor.
  double get pointsLost => maxPoints - points;
}

/// Splits an hour's Run Score into its five weighted factors, most important
/// first. All scores come from [calculator]; nothing is recalculated here.
///
/// The points add up to `calculator.scoreHour(hour).score`.
List<FactorContribution> scoreBreakdown(
  HourlyWeather hour,
  RunScoreCalculator calculator,
) {
  return [
    FactorContribution(
      label: 'Feels-like temperature',
      sentenceName: 'feels-like temperature',
      value: '${hour.apparentTemperature.round()}°C',
      factorScore: calculator.temperatureScore(hour.apparentTemperature),
      weight: RunScoreCalculator.temperatureWeight,
    ),
    FactorContribution(
      label: 'Rain chance',
      sentenceName: 'rain chance',
      value: '${hour.precipitationProbability}%',
      factorScore: calculator.rainScore(hour.precipitationProbability),
      weight: RunScoreCalculator.rainWeight,
    ),
    FactorContribution(
      label: 'Wind',
      sentenceName: 'wind',
      value: '${hour.windSpeed.round()} km/h',
      factorScore: calculator.windScore(hour.windSpeed),
      weight: RunScoreCalculator.windWeight,
    ),
    FactorContribution(
      label: 'UV index',
      sentenceName: 'UV index',
      value: '${hour.uvIndex.round()}',
      factorScore: calculator.uvScore(hour.uvIndex),
      weight: RunScoreCalculator.uvWeight,
    ),
    FactorContribution(
      label: 'Humidity',
      sentenceName: 'humidity',
      value: '${hour.relativeHumidity}%',
      factorScore: calculator.humidityScore(hour.relativeHumidity),
      weight: RunScoreCalculator.humidityWeight,
    ),
  ];
}

/// A one-word rating for a Run Score.
String runScoreRating(double score) {
  if (score >= 80) return 'Great';
  if (score >= 60) return 'Good';
  if (score >= 40) return 'Fair';
  return 'Poor';
}

/// A short sentence naming what lowered the score the most.
///
/// Factors that lost at least 3 points count, biggest loss first, up to two.
/// Example: "Lowered mostly by the rain chance (70%) and feels-like
/// temperature (34°C)."
String explainScore(List<FactorContribution> breakdown) {
  final concerns = breakdown.where((f) => f.pointsLost >= 3).toList()
    ..sort((a, b) => b.pointsLost.compareTo(a.pointsLost));

  if (concerns.isEmpty) {
    return 'Close to ideal running conditions on every factor.';
  }

  final names = [
    for (final f in concerns.take(2)) '${f.sentenceName} (${f.value})',
  ];
  return 'Lowered mostly by the ${names.join(' and ')}.';
}
