import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:run_ready/core/theme/app_theme.dart';
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

/// Pumps the whole app with the device set to [brightness].
Future<void> pumpApp(WidgetTester tester, Brightness brightness) async {
  tester.view.physicalSize = const Size(390 * 3, 1800 * 3);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        weatherForecastProvider.overrideWith((ref) async => sampleForecast()),
      ],
      child: const RunReadyApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// The background colors of every [Container] on screen.
Iterable<Color?> containerColors(WidgetTester tester) {
  return tester
      .widgetList<Container>(find.byType(Container))
      .map((c) => c.decoration)
      .whereType<BoxDecoration>()
      .map((d) => d.color);
}

void main() {
  group('AppTheme', () {
    test('both themes use Material 3', () {
      expect(AppTheme.light.useMaterial3, isTrue);
      expect(AppTheme.dark.useMaterial3, isTrue);
    });

    test('light keeps the existing look; dark is dark', () {
      final light = AppTheme.light;
      expect(light.brightness, Brightness.light);
      expect(light.colorScheme.primary, AppTheme.accent);
      expect(light.scaffoldBackgroundColor, const Color(0xFFE4EBF3));
      expect(light.cardColor, Colors.white);

      final dark = AppTheme.dark;
      expect(dark.brightness, Brightness.dark);
      // Cards stand out from the page, and neither is white.
      expect(dark.cardColor, isNot(dark.scaffoldBackgroundColor));
      expect(dark.cardColor, isNot(Colors.white));
      expect(dark.colorScheme.onSurface.computeLuminance(), greaterThan(0.5));
    });
  });

  testWidgets('the app follows the system setting via ThemeMode.system', (
    tester,
  ) async {
    await pumpApp(tester, Brightness.light);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
    expect(app.theme?.useMaterial3, isTrue);
    expect(app.darkTheme?.useMaterial3, isTrue);
  });

  testWidgets('light mode renders the home screen with light colors', (
    tester,
  ) async {
    await pumpApp(tester, Brightness.light);

    final context = tester.element(find.byType(HomeScreen));
    expect(Theme.of(context).brightness, Brightness.light);
    expect(find.text('25°C'), findsOneWidget);
    expect(containerColors(tester), contains(Colors.white));
  });

  testWidgets('dark mode applies the dark theme with no white cards', (
    tester,
  ) async {
    await pumpApp(tester, Brightness.dark);

    final context = tester.element(find.byType(HomeScreen));
    final theme = Theme.of(context);
    expect(theme.brightness, Brightness.dark);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor ??
          theme.scaffoldBackgroundColor,
      AppTheme.dark.scaffoldBackgroundColor,
    );

    // The weather cards now use the dark card color…
    expect(containerColors(tester), contains(AppTheme.dark.cardColor));
    // …and nothing is left painted white.
    expect(containerColors(tester), isNot(contains(Colors.white)));
    expect(find.text('25°C'), findsOneWidget);
  });
}
