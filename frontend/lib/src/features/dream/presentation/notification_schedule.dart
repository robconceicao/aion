import 'package:timezone/timezone.dart' as tz;
tz.TZDateTime nextReminder(tz.TZDateTime now, int hour, int minute, {bool skipToday = false}) {
  var at = tz.TZDateTime(now.location, now.year, now.month, now.day, hour, minute);
  if (skipToday || !at.isAfter(now)) {
    at = tz.TZDateTime(now.location, now.year, now.month, now.day + 1, hour, minute);
  }
  return at;
}
