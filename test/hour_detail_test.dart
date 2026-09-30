import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:run_ready/core/date_format.dart';
import 'package:run_ready/features/run_score/domain/run_score_calculator.dart';
import 'package:run_ready/features/weather/data/weather_models.dart';
import 'package:run_ready/features/weather/domain/forecast_hours.dart';
import 'package:run_ready/features/weather/presentation/hour_detail_screen.dart';
import 'package:run_ready/features/weather/providers/weather_provider.dart';
import 'package:run_ready/main.dart';

void useTallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 1800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('shows every detail of the selected hour', (tester) async {
    useTallPhone(tester);
    final hour = HourlyWeather(
      time: DateTime(2026, 9, 30, 17),
      temperature: 29.6,
      apparentTemperature: 33.2,
      precipitationProbability: 40,
      relativeHumidity: 78,
      windSpeed: 12.4,
      uvIndex: 3.2,
      weatherCode: 61,
    );
    final expectedScore = const RunScoreCalculator().scoreHour(hour).score;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: HourDetailScreen(hour: hour, timezone: 'Asia/Kolkata'),
        ),
      ),
    );

    expect(find.text('Wednesday, 30 September'), findsOneWidget);
    expect(find.text('5 PM'), findsOneWidget);
    expect(find.text('Local time · Asia/Kolkata'), findsOneWidget);
    expect(find.text('Rain'), findsOneWidget); // weather code 61
    expect(find.text('30°C'), findsOneWidget);
    expect(find.text('Feels like 33°C'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('12 km/h'), findsOneWidget);
    expect(find.text('78%'), findsOneWidget);
    expect(find.text('Moderate'), findsOneWidget); // UV 3
    expect(find.text('Why this score?'), findsOneWidget);
    expect(
      find.textContaining('${expectedScore.round()}', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('tapping an hourly item opens its details without refetching', (
    tester,
  ) async {
    useTallPhone(tester);
    var fetches = 0;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final forecast = HourlyForecast(
      timezone: 'Asia/Kolkata',
      hours: [
        for (var h = 0; h < 48; h++)
          HourlyWeather(
            time: start.add(Duration(hours: h)),
            temperature: 20.0 + h % 24,
            apparentTemperature: 22,
            precipitationProbability: h % 24,
            relativeHumidity: 60,
            windSpeed: 8,
            uvIndex: 1,
            weatherCode: 0,
          ),
      ],
    );
    // The item after "Now" in the hourly strip.
    final next = forecast.hours[currentHourIndex(forecast, now) + 1];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weatherForecastProvider.overrideWith((ref) async {
            fetches++;
            return forecast;
          }),
        ],
        child: const RunReadyApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(formatHour(next.time)));
    await tester.pumpAndSettle();

    expect(find.byType(HourDetailScreen), findsOneWidget);
    expect(find.text('Hour Details'), findsOneWidget);
    expect(find.text('${next.temperature.round()}°C'), findsOneWidget);
    expect(find.text('Local time · Asia/Kolkata'), findsOneWidget);
    expect(fetches, 1);

    // The AppBar back button returns home.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HourDetailScreen), findsNothing);
  });
}
