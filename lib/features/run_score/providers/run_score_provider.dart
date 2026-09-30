import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../weather/data/weather_models.dart';
import '../../weather/domain/forecast_hours.dart';
import '../../weather/providers/weather_provider.dart';
import '../domain/run_score_calculator.dart';
import '../domain/run_score_models.dart';
import '../domain/run_window_sort.dart';
import '../domain/running_hours.dart';

/// How far ahead to look for the best time to run.
const _searchHours = 24;

/// Alternatives scoring below this are not worth suggesting.
const _minSuitableScore = 60.0;

/// How many windows to show in total, including the best one.
const _maxWindows = 5;

/// Returns the current time. Tests override this to use a fixed time.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The shared [RunScoreCalculator].
final runScoreCalculatorProvider = Provider<RunScoreCalculator>((ref) {
  return const RunScoreCalculator();
});

/// The forecast hours to search: the next [_searchHours] hours that haven't
/// started yet, so a suggested window is never in the past, limited to
/// running hours so every window starts between 5:00 AM and 10:00 PM.
///
/// Follows [weatherForecastProvider]: loading and error states pass straight
/// through.
final runSearchHoursProvider = Provider<AsyncValue<List<HourlyWeather>>>((ref) {
  final forecast = ref.watch(weatherForecastProvider);
  final now = ref.watch(clockProvider)();

  return forecast.whenData(
    (forecast) => runningHoursOnly(
      upcomingHours(
        forecast,
        forecast.nowAtLocation(now), // compare in the location's local time
        count: _searchHours,
        includeCurrent: false,
      ),
    ),
  );
});

/// The best 2-hour running window in the next [_searchHours] hours.
///
/// The data is `null` when fewer than 2 upcoming hours are available.
final bestRunWindowProvider = Provider<AsyncValue<RunWindow?>>((ref) {
  final hours = ref.watch(runSearchHoursProvider);
  final calculator = ref.watch(runScoreCalculatorProvider);

  return hours.whenData(calculator.bestWindow);
});

/// Other good 2-hour windows after the best one, best first.
///
/// They never overlap the best window or each other, and each scores at least
/// [_minSuitableScore]. The list is empty when there are none.
final otherRunWindowsProvider = Provider<AsyncValue<List<RunWindow>>>((ref) {
  final hours = ref.watch(runSearchHoursProvider);
  final calculator = ref.watch(runScoreCalculatorProvider);

  return hours.whenData(
    (hours) => calculator
        .rankedWindows(hours, maxCount: _maxWindows)
        .skip(1) // the first one is the best window
        .where((window) => window.score >= _minSuitableScore)
        .toList(),
  );
});

/// The order chosen for the alternative windows. Starts as highest score and
/// resets each time the Plan Your Run screen closes.
final runWindowSortProvider =
    NotifierProvider.autoDispose<RunWindowSortNotifier, RunWindowSort>(
      RunWindowSortNotifier.new,
    );

class RunWindowSortNotifier extends Notifier<RunWindowSort> {
  @override
  RunWindowSort build() => RunWindowSort.highestScore;

  void select(RunWindowSort sort) => state = sort;
}

/// [otherRunWindowsProvider] in the order chosen by [runWindowSortProvider].
///
/// Each window keeps its score rank (the best window is #1, so these start at
/// #2) whichever order is chosen.
final sortedOtherRunWindowsProvider =
    Provider.autoDispose<AsyncValue<List<RankedRunWindow>>>((ref) {
      final others = ref.watch(otherRunWindowsProvider);
      final sort = ref.watch(runWindowSortProvider);

      return others.whenData(
        (windows) => sortRunWindows([
          for (final (index, window) in windows.indexed)
            (rank: index + 2, window: window),
        ], sort),
      );
    });
