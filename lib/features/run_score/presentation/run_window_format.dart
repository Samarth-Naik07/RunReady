import '../domain/run_score_models.dart';

/// "Today", "Tomorrow", or the weekday name for later days.
String dayLabel(DateTime time, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  final daysAhead = day.difference(today).inDays;

  if (daysAhead == 0) return 'Today';
  if (daysAhead == 1) return 'Tomorrow';
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return weekdays[time.weekday - 1];
}

/// Formats a time like "6:00 PM".
String formatClock(DateTime time) {
  final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minutes = time.minute.toString().padLeft(2, '0');
  final period = time.hour < 12 ? 'AM' : 'PM';
  return '$hour12:$minutes $period';
}

/// Formats a window like "6:00 PM – 8:00 PM".
String formatWindowRange(RunWindow window) {
  return '${formatClock(window.start)} – ${formatClock(window.end)}';
}
