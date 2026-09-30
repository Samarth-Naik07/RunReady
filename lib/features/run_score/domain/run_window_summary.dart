import '../../weather/data/weather_models.dart';
import 'run_score_models.dart';

/// A short, human-readable reason for a recommended [window], built from the
/// average weather across its hours. The same window always gives the same
/// text.
///
/// Example: "Low rain chance and light wind. Hot, so take water."
String describeRunWindow(RunWindow window) {
  final hours = [for (final s in window.hourlyScores) s.hour];

  double average(num Function(HourlyWeather hour) value) {
    return hours.map(value).reduce((a, b) => a + b) / hours.length;
  }

  final rain = average((h) => h.precipitationProbability);
  final feelsLike = average((h) => h.apparentTemperature);
  final wind = average((h) => h.windSpeed);
  final uv = average((h) => h.uvIndex);

  // Good things about the window, most important first.
  final positives = <String>[
    if (rain <= 20) 'low rain chance',
    if (feelsLike >= 10 && feelsLike <= 24) 'comfortable temperature',
    if (wind <= 15) 'light wind',
    if (uv <= 2) 'low UV',
  ];

  // The single most important concern, if any.
  String? caution;
  if (rain >= 50) {
    caution = 'Rain is likely, so plan for wet roads.';
  } else if (feelsLike > 30) {
    caution = 'Hot, so take water.';
  } else if (feelsLike < 5) {
    caution = 'Cold, so dress in layers.';
  } else if (wind > 25) {
    caution = 'Windy, so expect some headwind.';
  } else if (uv >= 6) {
    caution = 'High UV, so wear sunscreen.';
  }

  final sentences = <String>[
    if (positives.isNotEmpty)
      '${_capitalize(positives.take(2).join(' and '))}.',
    ?caution, // added only when it isn't null
  ];

  if (sentences.isEmpty) return 'The best conditions coming up.';
  return sentences.join(' ');
}

String _capitalize(String text) => text[0].toUpperCase() + text.substring(1);
