import 'dart:math';

import '../data/weather_models.dart';

/// Index of the forecast hour that contains [now] (the list starts at
/// midnight). Falls back to 0 if [now] is before the first hour.
int currentHourIndex(HourlyForecast forecast, DateTime now) {
  final index = forecast.hours.lastIndexWhere(
    (hour) => !hour.time.isAfter(now),
  );
  return max(index, 0);
}

/// The forecast hour that contains [now].
HourlyWeather currentHour(HourlyForecast forecast, DateTime now) {
  return forecast.hours[currentHourIndex(forecast, now)];
}

/// Up to [count] hours from the forecast, starting at [now].
///
/// With [includeCurrent] (the default) the list starts with the hour that
/// contains [now], e.g. 14:00 at 14:20. Without it, the list starts with the
/// first hour that has not begun yet, e.g. 15:00 at 14:20.
List<HourlyWeather> upcomingHours(
  HourlyForecast forecast,
  DateTime now, {
  int count = 12,
  bool includeCurrent = true,
}) {
  final start = includeCurrent
      ? currentHourIndex(forecast, now)
      : forecast.hours.indexWhere((hour) => hour.time.isAfter(now));

  // indexWhere returns -1 when every hour has already started.
  if (start < 0) return const [];

  return forecast.hours.skip(start).take(count).toList();
}
