import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:run_ready/features/weather/data/weather_models.dart';
import 'package:run_ready/features/weather/providers/weather_provider.dart';
import 'package:run_ready/main.dart';

HourlyForecast sampleForecast() {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  return HourlyForecast(
    timezone: 'Asia/Kolkata',
    hours: [
      for (var h = 0; h < 48; h++)
        HourlyWeather(
          time: start.add(Duration(hours: h)),
          temperature: 25,
          apparentTemperature: 27,
          precipitationProbability: 10,
          relativeHumidity: 70,
          windSpeed: 8,
          uvIndex: 2,
          weatherCode: 0,
        ),
    ],
  );
}

Future<void> pumpHome(WidgetTester tester, HourlyForecast forecast) async {
  tester.view.physicalSize = const Size(390 * 3, 1800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        weatherForecastProvider.overrideWith((ref) async => forecast),
      ],
      child: const RunReadyApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('fresh data shows no "Last updated" label', (tester) async {
    await pumpHome(tester, sampleForecast());

    expect(find.textContaining('Last updated'), findsNothing);
  });

  testWidgets('cached data shows when it was last updated', (tester) async {
    // No UTC offset in this forecast, so the label uses the device clock.
    final cached = sampleForecast().asCached(DateTime(2026, 9, 28, 16, 32));

    await pumpHome(tester, cached);

    expect(find.text('Last updated 28 Sep, 4:32 PM'), findsOneWidget);
    // The weather itself is still shown normally.
    expect(find.text('25°C'), findsOneWidget);
  });
}
