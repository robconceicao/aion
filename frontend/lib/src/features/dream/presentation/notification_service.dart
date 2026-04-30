import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AionNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // IDs de notificação
  static const int _morningId = 1001;
  static const int _nightId = 1002;

  // Mensagens matinais variadas — tom da Jornada do Herói
  static const List<String> _morningMessages = [
    'O Herói desperta. O que você trouxe do outro lado esta noite?',
    'As imagens da noite estão sumindo... Grave agora, antes que atravessem o limiar.',
    'Seu sonho de hoje está esperando. Capture-o antes de esquecer.',
    'Qual foi o último símbolo que você viu antes de despertar?',
    'A jornada continuou enquanto você dormia. O que aconteceu?',
    'O inconsciente falou esta noite. Você se lembra do que disse?',
    'Cada sonho é uma mensagem. A de hoje ainda está fresca.',
  ];

  static const List<String> _nightMessages = [
    'Prepare o seu santuário. O que você espera encontrar na jornada desta noite?',
    'Antes de dormir: o que ficou inacabado hoje que pode aparecer no seu sonho?',
    'A noite começa. Aion estará esperando de manhã.',
  ];

  /// Inicializa o serviço — chamar em main.dart
  static Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    _initialized = true;
  }

  /// Solicita permissão e agenda notificações
  static Future<void> requestAndSchedule(TimeOfDay wakeUpTime) async {
    final status = await Permission.notification.request();
    if (!status.isGranted) return;

    await _saveWakeUpTime(wakeUpTime);
    await _scheduleMorningNotification(wakeUpTime);
    await _scheduleNightNotification();
  }

  /// Cancela a notificação matinal do dia (usuário já registrou o sonho)
  static Future<void> cancelTodaysMorning() async {
    await _plugin.cancel(_morningId);
  }

  /// Cancela todas as notificações
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Retorna o horário de despertar salvo (ou null)
  static Future<TimeOfDay?> getSavedWakeUpTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('wake_hour');
    final minute = prefs.getInt('wake_minute');
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static Future<void> _saveWakeUpTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('wake_hour', time.hour);
    await prefs.setInt('wake_minute', time.minute);
  }

  static Future<void> _scheduleMorningNotification(TimeOfDay time) async {
    await _plugin.cancel(_morningId);

    final message = _morningMessages[
      DateTime.now().millisecondsSinceEpoch % _morningMessages.length
    ];

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, time.hour, time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _morningId,
      'Aion — Registre seu sonho',
      message,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'aion_morning',
          'Lembrete Matinal',
          channelDescription: 'Lembrete para registrar sonhos ao acordar',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFFC8A84A),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> _scheduleNightNotification() async {
    await _plugin.cancel(_nightId);

    final message = _nightMessages[
      DateTime.now().millisecondsSinceEpoch % _nightMessages.length
    ];

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, 22, 0,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _nightId,
      'Aion — A jornada de hoje',
      message,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'aion_night',
          'Lembrete Noturno',
          channelDescription: 'Reflexão antes de dormir',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          color: Color(0xFFC8A84A),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
