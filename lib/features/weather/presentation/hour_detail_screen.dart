import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_format.dart';
import '../../../core/layout.dart';
import '../../run_score/domain/hour_score_breakdown.dart';
import '../../run_score/providers/run_score_provider.dart';
import '../data/weather_models.dart';
import 'weather_display.dart';

/// Full details and the Run Score for one forecast hour.
///
/// Uses only the [hour] passed in, so opening it makes no API request.
class HourDetailScreen extends ConsumerWidget {
  const HourDetailScreen({
    super.key,
    required this.hour,
    required this.timezone,
  });

  /// The forecast hour the user tapped.
  final HourlyWeather hour;

  /// The forecast's timezone, e.g. "Asia/Kolkata". [hour]'s time is already
  /// local to it, so it is shown as-is, exactly like the hourly forecast.
  final String timezone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calculator = ref.watch(runScoreCalculatorProvider);
    final score = calculator.scoreHour(hour).score;
    final breakdown = scoreBreakdown(hour, calculator);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hour Details'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false, // the AppBar already handles the top inset
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sidePadding = contentSidePadding(constraints.maxWidth);

            return ListView(
              padding: EdgeInsets.fromLTRB(sidePadding, 8, sidePadding, 24),
              children: [
                _HourHero(hour: hour, timezone: timezone),
                const SizedBox(height: 16),
                _RunScoreCard(score: score),
                const SizedBox(height: 16),
                _ConditionsGrid(hour: hour),
                const SizedBox(height: 16),
                _WhyThisScoreCard(breakdown: breakdown),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// White rounded card used by every section on this screen.
class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child, this.padding = 20});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: child,
    );
  }
}

/// Date, time, icon, temperature, condition, and feels-like.
class _HourHero extends StatelessWidget {
  const _HourHero({required this.hour, required this.timezone});

  final HourlyWeather hour;
  final String timezone;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final time = hour.time;
    final (condition, icon) = weatherInfo(
      hour.weatherCode,
      time.hour,
      size: 80,
    );

    return _WhiteCard(
      padding: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${weekdayNames[time.weekday - 1]}, '
            '${time.day} ${monthNames[time.month - 1]}',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatHour(time),
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${hour.temperature.round()}°C',
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w600,
                      height: 1,
                      letterSpacing: -2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              icon,
            ],
          ),
          const SizedBox(height: 12),
          Text(
            condition,
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Feels like ${hour.apparentTemperature.round()}°C',
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Local time · $timezone',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The Run Score with a rating and a bar.
class _RunScoreCard extends StatelessWidget {
  const _RunScoreCard({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Run Score',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  runScoreRating(score),
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              text: '${score.round()}',
              style: textTheme.displaySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
              children: [
                TextSpan(
                  text: ' / 100',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 6,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rain, wind, humidity, and UV in a 2 × 2 grid of tiles.
class _ConditionsGrid extends StatelessWidget {
  const _ConditionsGrid({required this.hour});

  final HourlyWeather hour;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight + stretch keeps both tiles in a row the same height.
    Widget row(Widget left, Widget right) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      ),
    );

    return Column(
      children: [
        row(
          _ConditionTile(
            icon: Icons.water_drop_outlined,
            label: 'Rain chance',
            value: '${hour.precipitationProbability}%',
          ),
          _ConditionTile(
            icon: Icons.air_rounded,
            label: 'Wind',
            value: '${hour.windSpeed.round()} km/h',
          ),
        ),
        const SizedBox(height: 12),
        row(
          _ConditionTile(
            icon: Icons.opacity_rounded,
            label: 'Humidity',
            value: '${hour.relativeHumidity}%',
          ),
          _ConditionTile(
            icon: Icons.wb_sunny_outlined,
            label: 'UV index',
            value: '${hour.uvIndex.round()}',
            note: uvLevel(hour.uvIndex),
          ),
        ),
      ],
    );
  }
}

/// One condition: icon, label, value, and an optional note.
class _ConditionTile extends StatelessWidget {
  const _ConditionTile({
    required this.icon,
    required this.label,
    required this.value,
    this.note,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      // Icon on top so the text gets the full tile width on narrow phones.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: colorScheme.primary),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (note != null)
            Text(
              note!,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.primary),
            ),
        ],
      ),
    );
  }
}

/// The explanation plus each factor's contribution to the score.
class _WhyThisScoreCard extends StatelessWidget {
  const _WhyThisScoreCard({required this.breakdown});

  final List<FactorContribution> breakdown;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why this score?',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            explainScore(breakdown),
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          for (final factor in breakdown) _FactorRow(factor: factor),
        ],
      ),
    );
  }
}

/// "Rain chance · 30%        21 / 30 pts" with a small bar underneath.
class _FactorRow extends StatelessWidget {
  const _FactorRow({required this.factor});

  final FactorContribution factor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: factor.label,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      TextSpan(
                        text: ' · ${factor.value}',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${factor.points.round()} / ${factor.maxPoints.round()} pts',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: factor.factorScore / 100,
              minHeight: 4,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
