/// Day names, Monday first, matching [DateTime.weekday] - 1.
const weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Month names, matching [DateTime.month] - 1.
const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Formats a time like "02:42 pm".
String formatTime(DateTime time) {
  final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final period = time.hour < 12 ? 'am' : 'pm';
  final hh = hour12.toString().padLeft(2, '0');
  final mm = time.minute.toString().padLeft(2, '0');
  return '$hh:$mm $period';
}

/// Formats an hour like "5 PM".
String formatHour(DateTime time) {
  final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final period = time.hour < 12 ? 'AM' : 'PM';
  return '$hour12 $period';
}

/// Formats a date and time like "28 Sep, 4:32 PM".
String formatShortDateTime(DateTime time) {
  final month = monthNames[time.month - 1].substring(0, 3);
  final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minutes = time.minute.toString().padLeft(2, '0');
  final period = time.hour < 12 ? 'AM' : 'PM';
  return '${time.day} $month, $hour12:$minutes $period';
}
