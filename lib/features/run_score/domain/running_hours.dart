import '../../weather/data/weather_models.dart';

/// The earliest hour a running window may start (5:00 AM).
const firstRunStartHour = 5;

/// The latest hour a 2-hour running window may start (10:00 PM), so the last
/// window ends at midnight.
const lastRunStartHour = 22;

/// True if an hour starting at [time] can be part of a running window.
///
/// That is 5:00 AM up to and including the 11:00 PM hour, which is the second
/// hour of the 10:00 PM – 12:00 AM window.
bool isRunningHour(DateTime time) {
  return time.hour >= firstRunStartHour && time.hour <= lastRunStartHour + 1;
}

/// Keeps only the hours that can be part of a running window.
///
/// Windows are only built from back-to-back hours, so removing the night
/// hours (00:00–04:59) also means no window can start before 5:00 AM, start
/// after 10:00 PM, or run past midnight.
List<HourlyWeather> runningHoursOnly(List<HourlyWeather> hours) {
  return [
    for (final hour in hours)
      if (isRunningHour(hour.time)) hour,
  ];
}
