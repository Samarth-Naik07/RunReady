import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:run_ready/features/weather/data/weather_models.dart';
import 'package:run_ready/features/weather/providers/weather_provider.dart';
import 'package:run_ready/main.dart';

void main() {
  testWidgets('hourly forecast scrolls by mouse drag to past midnight', (
    tester,
  ) async {
    var fetches = 0;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final hours = [
      for (var h = 0; h < 72; h++)
        HourlyWeather(
          time: start.add(Duration(hours: h)),
          temperature: 20,
          apparentTemperature: 20,
          precipitationProbability: 0,
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

    // The horizontal list is the nearest scrollable above the "Now" item.
    // Look it up once, so the finder still works after "Now" scrolls away.
    final listElement = find
        .ancestor(of: find.text('Now'), matching: find.byType(Scrollable))
        .first
        .evaluate()
        .single;
    final hourlyList = find.byElementPredicate((e) => e == listElement);
    double scrollOffset() =>
        tester.state<ScrollableState>(hourlyList).position.pixels;

    expect(scrollOffset(), 0);

    // A mouse drag (as on web/desktop) moves the list.
    await tester.drag(
      hourlyList,
      const Offset(-200, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(scrollOffset(), greaterThan(0));

    // Keep scrolling until the midnight item is on screen.
    await tester.scrollUntilVisible(
      find.text('12 AM'),
      200,
      scrollable: hourlyList,
    );
    expect(find.text('12 AM').hitTestable(), findsOneWidget);

    // Scrolling only moves through the forecast already loaded.
    expect(fetches, 1);
  });
}
