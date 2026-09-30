import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:run_ready/features/run_score/domain/run_score_models.dart';
import 'package:run_ready/features/run_score/domain/run_window_sort.dart';
import 'package:run_ready/features/run_score/presentation/best_time_screen.dart';
import 'package:run_ready/features/run_score/providers/run_score_provider.dart';
import 'package:run_ready/features/weather/data/weather_models.dart';
import 'package:run_ready/features/weather/providers/weather_provider.dart';

RankedRunWindow ranked(int rank, int startHour, double score) {
  return (
    rank: rank,
    window: RunWindow(
      start: DateTime(2026, 9, 30, startHour),
      end: DateTime(2026, 9, 30, startHour + 2),
      score: score,
      hourlyScores: const [],
    ),
  );
}

/// 30 Sep, 05:00–23:00. Hour score = 100 - 0.3 × rain.
///
/// Non-overlapping windows by score: 05–07 (100, the best window), then
/// 11–13 (97), 17–19 (94), 07–09 (88), 09–11 (70).
HourlyForecast sampleForecast() {
  int rainAt(int h) => switch (h) {
    5 || 6 => 0,
    7 || 8 => 40,
    11 || 12 => 10,
    17 || 18 => 20,
    _ => 100,
  };
  return HourlyForecast(
    timezone: 'Asia/Kolkata',
    hours: [
      for (var h = 5; h < 24; h++)
        HourlyWeather(
          time: DateTime(2026, 9, 30, h),
          temperature: 15,
          apparentTemperature: 15,
          precipitationProbability: rainAt(h),
          relativeHumidity: 50,
          windSpeed: 5,
          uvIndex: 1,
          weatherCode: 0,
        ),
    ],
  );
}

final overrides = [
  weatherForecastProvider.overrideWith((ref) async => sampleForecast()),
  clockProvider.overrideWithValue(() => DateTime(2026, 9, 30, 4, 30)),
];

void main() {
  group('sortRunWindows', () {
    final windows = [
      ranked(2, 11, 97),
      ranked(3, 17, 94),
      ranked(4, 7, 88),
      ranked(5, 9, 70),
    ];

    test('Highest Run Score puts the best scores first', () {
      final sorted = sortRunWindows([
        ...windows.reversed,
      ], RunWindowSort.highestScore);

      expect([for (final w in sorted) w.window.score], [97, 94, 88, 70]);
    });

    test('Earliest Time orders by start time', () {
      final sorted = sortRunWindows(windows, RunWindowSort.earliestTime);

      expect([for (final w in sorted) w.window.start.hour], [7, 9, 11, 17]);
    });

    test('ranks stay with their windows', () {
      final sorted = sortRunWindows(windows, RunWindowSort.earliestTime);

      expect([for (final w in sorted) w.rank], [4, 5, 2, 3]);
    });

    test('equal scores go to the earlier window', () {
      final sorted = sortRunWindows([
        ranked(3, 15, 80),
        ranked(2, 8, 80),
      ], RunWindowSort.highestScore);

      expect([for (final w in sorted) w.window.start.hour], [8, 15]);
    });

    test('does not change the input list', () {
      final input = [...windows];
      sortRunWindows(input, RunWindowSort.earliestTime);

      expect(input, windows);
    });
  });

  test(
    'providers default to Highest Run Score and re-sort on change',
    () async {
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);
      container.listen(sortedOtherRunWindowsProvider, (_, _) {});
      await container.read(weatherForecastProvider.future);

      List<int> startHours() => [
        for (final w in container.read(sortedOtherRunWindowsProvider).value!)
          w.window.start.hour,
      ];

      expect(container.read(runWindowSortProvider), RunWindowSort.highestScore);
      expect(startHours(), [11, 17, 7, 9]);

      container
          .read(runWindowSortProvider.notifier)
          .select(RunWindowSort.earliestTime);

      expect(startHours(), [7, 9, 11, 17]);
      // The best window itself is unaffected by the sort.
      expect(container.read(bestRunWindowProvider).value!.start.hour, 5);
    },
  );

  testWidgets('tapping Earliest Time reorders the other windows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(home: BestTimeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Top-to-bottom order of the window rows, by their time text.
    List<String> rowOrder() {
      const ranges = [
        '7:00 AM – 9:00 AM',
        '9:00 AM – 11:00 AM',
        '11:00 AM – 1:00 PM',
        '5:00 PM – 7:00 PM',
      ];
      return [...ranges]..sort(
        (a, b) => tester
            .getTopLeft(find.text(a))
            .dy
            .compareTo(tester.getTopLeft(find.text(b)).dy),
      );
    }

    expect(find.text('Highest Run Score'), findsOneWidget);
    expect(find.text('Earliest Time'), findsOneWidget);
    expect(rowOrder(), [
      '11:00 AM – 1:00 PM',
      '5:00 PM – 7:00 PM',
      '7:00 AM – 9:00 AM',
      '9:00 AM – 11:00 AM',
    ]);

    await tester.tap(find.text('Earliest Time'));
    await tester.pumpAndSettle();

    expect(rowOrder(), [
      '7:00 AM – 9:00 AM',
      '9:00 AM – 11:00 AM',
      '11:00 AM – 1:00 PM',
      '5:00 PM – 7:00 PM',
    ]);
    // The best-window card still shows 5:00–7:00 AM at the top.
    expect(find.text('5:00 AM – 7:00 AM'), findsOneWidget);
  });
}
