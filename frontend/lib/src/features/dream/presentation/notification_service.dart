import 'package:flutter_timezone/flutter_timezone.dart';
import 'notification_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AionNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static final _observer = _NotificationObserver();

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
    await _refreshTimezone();

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
    WidgetsBinding.instance.addObserver(_observer);
  }

  static String _today() => DateTime.now().toIso8601String().substring(0, 10);
  static Future<void> _refreshTimezone() async {
    final identifier = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(identifier));
  }
  static Future<void> refreshOnResume() async {
    try {
      await initialize();
      await _refreshTimezone();
      final prefs = await SharedPreferences.getInstance();
      final time = await getSavedWakeUpTime();
      if (prefs.getBool('notifications_enabled') == true && time != null) {
        await _scheduleMorningNotification(time, skipToday: prefs.getString('dream_registered_day') == _today());
        await _scheduleNightNotification();
      }
    } catch (error) { debugPrint('Lembretes indisponíveis: $error'); }
  }

  /// Solicita permissão e agenda notificações.
  /// Retorna true se agendado com sucesso; false se permissão negada
  /// ou alarme exato indisponível (Android 12).
  static Future<bool> requestAndSchedule(TimeOfDay wakeUpTime) async {
    try {
      await initialize();
      await _refreshTimezone();
      final status = await Permission.notification.request();
      if (!status.isGranted) return false;

      // Android 12 (API 31–32): SCHEDULE_EXACT_ALARM requer opt-in em
      // Configurações → Apps → Aion → Acesso especial. Verificar antes
      // de agendar para evitar falha silenciosa.
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final canSchedule = await androidImpl.canScheduleExactNotifications();
        if (canSchedule == false) return false;
      }

      await _scheduleMorningNotification(wakeUpTime);
      await _scheduleNightNotification();
      await _saveWakeUpTime(wakeUpTime);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', true);
      return true;
    } catch (error) {
      debugPrint('Não foi possível agendar lembretes: $error');
      return false;
    }
  }

  /// Cancela a notificação matinal do dia (usuário já registrou o sonho)
  static Future<void> cancelTodaysMorning() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dream_registered_day', _today());
    final time = await getSavedWakeUpTime();
    if (time != null && prefs.getBool('notifications_enabled') == true) {
      await _refreshTimezone();
      await _scheduleMorningNotification(time, skipToday: true);
    }
  }

  /// Cancela todas as notificações
  static Future<void> cancelAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', false);
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

  static Future<void> _scheduleMorningNotification(TimeOfDay time, {bool skipToday = false}) async {
    await _plugin.cancel(_morningId);

    final message = _morningMessages[
      DateTime.now().millisecondsSinceEpoch % _morningMessages.length
    ];

    final now = tz.TZDateTime.now(tz.local);
    final scheduled = nextReminder(now, time.hour, time.minute, skipToday: skipToday);

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
    final scheduled = nextReminder(now, 22, 0);

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

class _NotificationObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) { AionNotificationService.refreshOnResume(); }
  }
}
