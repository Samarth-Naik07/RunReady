import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/date_format.dart';
import 'core/errors/app_error.dart';
import 'core/layout.dart';
import 'core/theme/app_theme.dart';
import 'features/location/presentation/location_search_screen.dart';
import 'features/location/providers/location_provider.dart';
import 'features/run_score/presentation/best_time_screen.dart';
import 'features/weather/data/weather_models.dart';
import 'features/weather/domain/forecast_hours.dart';
import 'features/weather/presentation/hour_detail_screen.dart';
import 'features/weather/presentation/weather_display.dart';
import 'features/weather/providers/weather_provider.dart';

void main() {
  runApp(const ProviderScope(child: RunReadyApp()));
}

/// The root widget. Sets up the Material 3 themes and the first screen.
class RunReadyApp extends StatelessWidget {
  const RunReadyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RunReady',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Follow the device's light/dark setting.
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

/// The RunReady home screen. Shows the forecast from [weatherForecastProvider].
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecast = ref.watch(weatherForecastProvider);
    final location = ref.watch(selectedLocationProvider);

    // Dates, "Now", and the hero time use the location's own clock.
    final deviceNow = DateTime.now();
    final now = forecast.value?.nowAtLocation(deviceNow) ?? deviceNow;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sidePadding = contentSidePadding(constraints.maxWidth);

            return ListView(
              padding: EdgeInsets.fromLTRB(sidePadding, 16, sidePadding, 24),
              children: [
                _LocationHeader(
                  name: location.displayName,
                  date: now,
                  onTap: () => _openLocationSearch(context),
                ),

                // Only when the network failed and saved data is shown.
                if (forecast.value case final data? when data.isFromCache) ...[
                  const SizedBox(height: 8),
                  _CachedDataNotice(
                    // Shown on the location's clock, like the rest of the
                    // screen.
                    lastUpdated: data.nowAtLocation(data.cachedAt!),
                    onRetry: () => ref.invalidate(weatherForecastProvider),
                  ),
                ],
                const SizedBox(height: 24),

                // Weather hero: loading, error, or the current conditions.
                forecast.when(
                  // Show the spinner while Retry is running, too.
                  skipLoadingOnRefresh: false,
                  loading: () => const _HeroCard(
                    child: SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (error, stackTrace) => _HeroCard(
                    // At least as tall as the loading card, but free to grow
                    // when the message wraps (e.g. with large text sizes).
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 200),
                      child: _WeatherErrorMessage(
                        message: AppError.from(error).userMessage,
                        onRetry: () => ref.invalidate(weatherForecastProvider),
                      ),
                    ),
                  ),
                  data: (forecast) {
                    final hour = currentHour(forecast, now);
                    return Column(
                      children: [
                        _WeatherHero(hour: hour, now: now),
                        const SizedBox(height: 16),
                        _MetricsRow(hour: hour),
                        const SizedBox(height: 16),
                        _HourlyForecastSection(
                          // The next 24 hours always reach past midnight.
                          hours: upcomingHours(forecast, now, count: 24),
                          onHourTap: (hour) =>
                              _openHourDetail(context, hour, forecast.timezone),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                _FindBestTimePrompt(onTap: () => _openBestTime(context)),
                const SizedBox(height: 16),

                FilledButton.icon(
                  onPressed: () => _openBestTime(context),
                  icon: const Icon(Icons.directions_run),
                  label: const Text('Find Best Running Time'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(60),
                    textStyle: const TextStyle(fontSize: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A friendly error message with a Retry button, inside the weather card.
class _WeatherErrorMessage extends StatelessWidget {
  const _WeatherErrorMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 36, color: colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Small pill saying the weather is saved data, with when it was fetched.
/// Tapping it tries the network again.
class _CachedDataNotice extends StatelessWidget {
  const _CachedDataNotice({required this.lastUpdated, required this.onRetry});

  final DateTime lastUpdated;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: colorScheme.onSurfaceVariant);

    return Center(
      child: Material(
        color: Theme.of(context).cardColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onRetry,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  semanticLabel: 'Offline',
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Last updated ${formatShortDateTime(lastUpdated)}',
                    style: style,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.refresh_rounded,
                  size: 14,
                  color: colorScheme.primary,
                  semanticLabel: 'Retry',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the location search screen on top of the home screen.
void _openLocationSearch(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (context) => const LocationSearchScreen()),
  );
}

/// Opens the details for one forecast [hour] on top of the home screen.
void _openHourDetail(
  BuildContext context,
  HourlyWeather hour,
  String timezone,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => HourDetailScreen(hour: hour, timezone: timezone),
    ),
  );
}

/// Opens the Best Time screen on top of the home screen.
void _openBestTime(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (context) => const BestTimeScreen()));
}

/// A compact card inviting the user to find the best time to run.
class _FindBestTimePrompt extends StatelessWidget {
  const _FindBestTimePrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.directions_run_rounded,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'When should you run?',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'We score the next 24 hours for heat, rain, wind, '
                      'and UV.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered location title with today's date underneath.
/// Tappable location name with the date underneath. Tapping opens search.
class _LocationHeader extends StatelessWidget {
  const _LocationHeader({
    required this.name,
    required this.date,
    required this.onTap,
  });

  /// The selected location, e.g. "Panaji, Goa".
  final String name;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: colorScheme.primary,
                  semanticLabel: 'Search location',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${date.day} ${monthNames[date.month - 1]}, ${weekdayNames[date.weekday - 1]}',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The large white rounded card that holds the weather hero.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(32),
      ),
      child: child,
    );
  }
}

/// Current conditions: day and time, big temperature, icon, and feels-like.
class _WeatherHero extends StatelessWidget {
  const _WeatherHero({required this.hour, required this.now});

  final HourlyWeather hour;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final (condition, icon) = weatherInfo(hour.weatherCode, hour.time.hour);

    return _HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day on the left, time on the right.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                weekdayNames[now.weekday - 1],
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(formatTime(now), style: textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 28),

          // Big temperature on the left, weather icon on the right.
          Row(
            children: [
              Expanded(
                // Shrinks the text on very narrow phones instead of overflowing.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${hour.temperature.round()}°C',
                    style: const TextStyle(
                      fontSize: 72,
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
          Text.rich(
            TextSpan(
              text: 'Feels like ',
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              children: [
                TextSpan(
                  text: '${hour.apparentTemperature.round()}°C',
                  style: TextStyle(color: colorScheme.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Three small cards under the hero: wind, humidity, and UV index.
class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.hour});

  final HourlyWeather hour;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight + stretch makes all three cards as tall as the tallest.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _MetricCard(
              icon: Icons.air_rounded,
              label: 'Wind',
              value: '${hour.windSpeed.round()} km/h',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              icon: Icons.water_drop_outlined,
              label: 'Humidity',
              value: '${hour.relativeHumidity}%',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              icon: Icons.wb_sunny_outlined,
              label: 'UV Index',
              value: '${hour.uvIndex.round()}',
              note: uvLevel(hour.uvIndex),
            ),
          ),
        ],
      ),
    );
  }
}

/// One white rounded card with an icon, a label, a value, and an optional note.
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.note,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Small extra text under the value, e.g. "Very high" for UV.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Blue icon in a pale blue circle.
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: colorScheme.primary),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (note != null)
            Text(
              note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.primary),
            ),
        ],
      ),
    );
  }
}

/// White rounded card with a horizontally scrolling list of hours.
class _HourlyForecastSection extends StatelessWidget {
  const _HourlyForecastSection({required this.hours, required this.onHourTap});

  final List<HourlyWeather> hours;

  /// Called with the hour the user tapped.
  final void Function(HourlyWeather hour) onHourTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Hourly Forecast',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // A horizontal list needs a fixed height inside a vertical list.
          SizedBox(
            height: 132,
            // Flutter only drag-scrolls with touch by default. This also
            // allows mouse and trackpad dragging on web and desktop.
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context)
                  .copyWith(dragDevices: PointerDeviceKind.values.toSet()),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: hours.length,
                separatorBuilder: (context, index) => const SizedBox(width: 4),
                itemBuilder: (context, index) => _HourlyItem(
                  hour: hours[index],
                  isNow: index == 0,
                  onTap: () => onHourTap(hours[index]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One compact column: time, icon, temperature, and chance of rain.
class _HourlyItem extends StatelessWidget {
  const _HourlyItem({
    required this.hour,
    required this.isNow,
    required this.onTap,
  });

  final HourlyWeather hour;

  /// Highlights the current hour with a pale blue background.
  final bool isNow;

  /// Opens this hour's details.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final (_, icon) = weatherInfo(hour.weatherCode, hour.time.hour, size: 28);

    return Material(
      color: isNow
          ? colorScheme.primary.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isNow ? 'Now' : formatHour(hour.time),
                style: textTheme.bodySmall?.copyWith(
                  color: isNow
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: isNow ? FontWeight.w600 : null,
                ),
              ),
              SizedBox(height: 28, child: Center(child: icon)),
              Text(
                '${hour.temperature.round()}°',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.water_drop_rounded,
                    size: 12,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${hour.precipitationProbability}%',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
