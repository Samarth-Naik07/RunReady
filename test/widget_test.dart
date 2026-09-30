import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:run_ready/features/weather/data/weather_models.dart';
import 'package:run_ready/features/weather/providers/weather_provider.dart';
import 'package:run_ready/main.dart';

void main() {
  testWidgets('Home screen shows a spinner, then the current weather', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 1800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Two days of plain hours, with distinctive values for the current hour
    // so the test can tell it apart from the rest.
    final now = DateTime.now();
    final currentHourStart = DateTime(now.year, now.month, now.day, now.hour);
    final start = DateTime(now.year, now.month, now.day);
    final hours = [
      for (var h = 0; h < 48; h++)
        start.add(Duration(hours: h)) == currentHourStart
            ? HourlyWeather(
                time: currentHourStart,
                temperature: 27.4,
                apparentTemperature: 31.2,
                precipitationProbability: 10,
                relativeHumidity: 78,
                windSpeed: 12.4,
                uvIndex: 6.2,
                weatherCode: 3, // cloudy
              )
            : HourlyWeather(
                time: start.add(Duration(hours: h)),
                temperature: 20,
                apparentTemperature: 20,
                precipitationProbability: 0,
                relativeHumidity: 50,
                windSpeed: 5,
                uvIndex: 0,
                weatherCode: 0,
              ),
    ];

    // The test decides when the "API call" finishes. No network is used.
    final response = Completer<HourlyForecast>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weatherForecastProvider.overrideWith((ref) => response.future),
        ],
        child: const RunReadyApp(),
      ),
    );

    // While loading: header and spinner, no weather yet.
    expect(find.text('Panaji, Goa'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('27°C'), findsNothing);

    response.complete(HourlyForecast(timezone: 'Asia/Kolkata', hours: hours));
    await tester.pumpAndSettle();

    // Current conditions for this hour.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('27°C'), findsOneWidget);
    expect(find.text('Cloudy'), findsOneWidget);
    expect(
      find.textContaining('Feels like 31°C', findRichText: true),
      findsOneWidget,
    );

    // Metric cards.
    expect(find.text('12 km/h'), findsOneWidget);
    expect(find.text('78%'), findsOneWidget);
    expect(find.text('High'), findsOneWidget); // UV 6

    // Hourly forecast starting at the current hour.
    expect(find.text('Hourly Forecast'), findsOneWidget);
    expect(find.text('Now'), findsOneWidget);

    // The way into the running planner.
    expect(find.text('When should you run?'), findsOneWidget);
    expect(find.text('Find Best Running Time'), findsOneWidget);
  });
}
