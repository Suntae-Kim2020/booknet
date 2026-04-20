import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: iOS),
    );

    // iOS 권한 요청
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  /// 모임 리마인더 예약 (하루 전, 1시간 전)
  static Future<void> scheduleMeetingReminder({
    required String meetingId,
    required String title,
    required DateTime scheduledAt,
    String? location,
  }) async {
    await init();

    final body = location != null ? '$location에서 모임이 있습니다.' : '모임이 예정되어 있습니다.';

    // 하루 전 알림
    final dayBefore = scheduledAt.subtract(const Duration(hours: 24));
    if (dayBefore.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        meetingId.hashCode,
        '내일 $title',
        body,
        tz.TZDateTime.from(dayBefore, tz.local),
        _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // 1시간 전 알림
    final hourBefore = scheduledAt.subtract(const Duration(hours: 1));
    if (hourBefore.isAfter(DateTime.now())) {
      await _plugin.zonedSchedule(
        meetingId.hashCode + 1,
        '1시간 후 $title',
        body,
        tz.TZDateTime.from(hourBefore, tz.local),
        _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// 즉시 알림
  static Future<void> showNow({
    required String title,
    required String body,
    int id = 0,
  }) async {
    await init();
    await _plugin.show(id, title, body, _notificationDetails);
  }

  /// 알림 취소
  static Future<void> cancel(int id) async {
    await _plugin.cancel(id);
    await _plugin.cancel(id + 1);
  }

  /// 전체 취소
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'meeting_reminder',
      '모임 알림',
      channelDescription: '독서토론 모임 리마인더',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );
}
