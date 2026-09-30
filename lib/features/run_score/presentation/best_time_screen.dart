import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout.dart';
import '../../weather/providers/weather_provider.dart';
import '../domain/run_score_models.dart';
import '../providers/run_score_provider.dart';
import '../domain/run_window_sort.dart';
import 'best_time_card.dart';
import 'run_window_format.dart';

/// Shows the best 2-hour running window and other good options.
///
/// Reads the Run Score providers, which reuse the forecast already loaded for
/// the home screen, so opening this screen makes no new API request.
class BestTimeScreen extends ConsumerWidget {
  const BestTimeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final best = ref.watch(bestRunWindowProvider);
    final others = ref.watch(sortedOtherRunWindowsProvider);
    final sort = ref.watch(runWindowSortProvider);
    // "Today"/"Tomorrow" labels use the location's own date.
    final deviceNow = DateTime.now();
    final now =
        ref.watch(weatherForecastProvider).value?.nowAtLocation(deviceNow) ??
        deviceNow;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Your Run'),
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
                Text(
                  'Scored for the next 24 hours using feels-like temperature, '
                  'rain, wind, UV, and humidity.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // Best window, with loading, error + retry, and "none" states.
                BestTimeCard(
                  window: best,
                  now: now,
                  onRetry: () => ref.invalidate(weatherForecastProvider),
                ),

                // Other options, only once there is a best window to compare.
                if (best.value != null && others.hasValue) ...[
                  const SizedBox(height: 16),
                  _OtherWindowsCard(
                    windows: others.value!,
                    now: now,
                    sort: sort,
                    onSortChanged: ref
                        .read(runWindowSortProvider.notifier)
                        .select,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// White rounded card listing alternative windows, in the chosen order.
class _OtherWindowsCard extends StatelessWidget {
  const _OtherWindowsCard({
    required this.windows,
    required this.now,
    required this.sort,
    required this.onSortChanged,
  });

  /// Already sorted by the providers; shown in this order.
  final List<RankedRunWindow> windows;
  final DateTime now;
  final RunWindowSort sort;
  final void Function(RunWindowSort sort) onSortChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Other good times',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),

          // Sorting only matters with two or more windows.
          if (windows.length > 1) ...[
            const SizedBox(height: 8),
            _SortControl(sort: sort, onChanged: onSortChanged),
            const SizedBox(height: 4),
          ],
          if (windows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Text(
                'No other suitable times in the next 24 hours.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final (index, item) in windows.indexed) ...[
              if (index > 0) const Divider(height: 1),
              _WindowRow(rank: item.rank, window: item.window, now: now),
            ],
        ],
      ),
    );
  }
}

/// Two-option segmented control: Highest Run Score or Earliest Time.
class _SortControl extends StatelessWidget {
  const _SortControl({required this.sort, required this.onChanged});

  final RunWindowSort sort;
  final void Function(RunWindowSort sort) onChanged;

  @override
  Widget build(BuildContext context) {
    // Full width, so both labels fit on narrow phones and stay tidy in
    // landscape.
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<RunWindowSort>(
        segments: [
          for (final option in RunWindowSort.values)
            ButtonSegment(
              value: option,
              // Shrinks slightly on very narrow phones instead of cutting
              // the label off.
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(option.label, maxLines: 1),
              ),
            ),
        ],
        selected: {sort},
        onSelectionChanged: (selection) => onChanged(selection.single),
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          textStyle: Theme.of(context).textTheme.labelMedium,
        ),
      ),
    );
  }
}

/// One ranked row: rank number, day and time range, and score.
class _WindowRow extends StatelessWidget {
  const _WindowRow({
    required this.rank,
    required this.window,
    required this.now,
  });

  /// Position in the Run Score ranking; the best window is #1. It stays the
  /// same whichever sort order is chosen.
  final int rank;
  final RunWindow window;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
            child: Text(
              '$rank',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayLabel(window.start, now),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  formatWindowRange(window),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text.rich(
            TextSpan(
              text: '${window.score.round()}',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
              children: [
                TextSpan(
                  text: ' / 100',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
