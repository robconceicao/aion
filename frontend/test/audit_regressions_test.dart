import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;
import '../lib/src/core/retry_policy.dart';
import '../lib/src/features/dream/presentation/notification_schedule.dart';
void main() {
 test('ambiguous POST is never retried automatically', () {
  for (final method in ['POST','PUT','PATCH','DELETE']) { expect(mayRetryTransport(method), false); }
  expect(mayRetryTransport('GET'),true); expect(mayRetryTransport('head'),true);
 });
 test('local reminder and skip today preserve tomorrow at chosen hour', () {
  data.initializeTimeZones();
  final zone=tz.getLocation('America/Sao_Paulo');
  final now=tz.TZDateTime(zone,2026,9,27,6);
  final morning=nextReminder(now,7,0);
  expect(morning.toUtc().hour,10);
  final tomorrow=nextReminder(now,7,0,skipToday:true);
  expect(tomorrow.day,28);expect(tomorrow.hour,7);
 });
 test('calendar day across DST keeps local hour', () {
  data.initializeTimeZones();
  final zone=tz.getLocation('America/New_York');
  final tomorrow=nextReminder(tz.TZDateTime(zone,2026,3,7,8),7,0);
  expect(tomorrow.day,8); expect(tomorrow.hour,7);
 });
}
