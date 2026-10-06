import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

const attendanceTimezone = 'America/Toronto';
bool _loaded = false;
tz.Location get workspaceLocation {
  if (!_loaded) {
    data.initializeTimeZones();
    _loaded = true;
  }
  return tz.getLocation(attendanceTimezone);
}

DateTime workspaceTime(DateTime date) =>
    tz.TZDateTime.from(date, workspaceLocation);
DateTime workspaceNow() => workspaceTime(DateTime.now());
String attendanceDayKey(DateTime date) {
  final d = workspaceTime(date);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

DateTime workdayTime(DateTime date, int minutes) {
  final d = workspaceTime(date);
  return tz.TZDateTime(
    workspaceLocation,
    d.year,
    d.month,
    d.day,
    minutes ~/ 60,
    minutes % 60,
  );
}

DateTime workdayEnd(DateTime date) {
  final d = workspaceTime(date);
  return tz.TZDateTime(workspaceLocation, d.year, d.month, d.day + 1);
}
