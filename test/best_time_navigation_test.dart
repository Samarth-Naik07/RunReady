import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:run_ready/features/run_score/presentation/best_time_screen.dart';
import 'package:run_ready/features/weather/data/weather_models.dart';
import 'package:run_ready/features/weather/providers/weather_provider.dart';
import 'package:run_ready/main.dart';

void main() {
  testWidgets('button opens Best Time screen without refetching', (
    tester,
  ) async {
    var fetches = 0;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final hours = [
      for (var h = 0; h < 48; h++)
        HourlyWeather(
          time: start.add(Duration(hours: h)),
          temperature: 15,
          apparentTemperature: 15,
          precipitationProbability: h % 5 * 10,
          relativeHumidity: 50,
          windSpeed: 5,
          uvIndex: 1,
          weatherCode: 0,
        ),
    ];

    tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weatherForecastProvider.overrideWith((ref) async {
            fetches++;
            return HourlyForecast(timezone: 'Asia/Kolkata', hours: hours);
          }),
        ],
        child: const RunReadyApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Home shows the prompt instead of the recommendation card.
    expect(find.text('When should you run?'), findsOneWidget);
    expect(find.text('Best Time to Run'), findsNothing);

    await tester.tap(find.text('Find Best Running Time'));
    await tester.pumpAndSettle();

    expect(find.byType(BestTimeScreen), findsOneWidget);
    expect(find.text('Best Time to Run'), findsOneWidget);
    expect(find.text('Other good times'), findsOneWidget);
    expect(fetches, 1);

    // The AppBar back button returns home.
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(BestTimeScreen), findsNothing);
    expect(find.text('When should you run?'), findsOneWidget);
  });
}
