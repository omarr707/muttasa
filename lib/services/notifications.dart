import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Day;
import 'package:schedule_core/schedule_core.dart';
import 'package:timezone/timezone.dart' as tz;

/// ما يُرسل عند الضغط على تنبيه أو زر داخله.
class NotificationTap {
  const NotificationTap({
    required this.date,
    required this.itemKey,
    this.action,
  });
  final Day date;
  final String itemKey;

  /// 'done' أو 'snooze' أو 'call' أو null (فتح).
  final String? action;
}

/// NotificationScheduler: نافذة متحركة (اليوم والغد وبعده) بـ zonedSchedule.
/// iOS يسمح بـ 64 تنبيهًا معلّقًا فقط، فلا نجدول أبعد.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final taps = StreamController<NotificationTap>.broadcast();
  bool _ready = false;
  bool _exact = false;
  NotificationTap? launchTap;

  static const _channels = {
    NotifyKind.prayer: ('prayer', 'الصلاة', Importance.max),
    NotifyKind.appointments: ('appointments', 'المواعيد', Importance.high),
    NotifyKind.routine: ('routine', 'الروتين', Importance.defaultImportance),
    NotifyKind.water: ('water', 'الماء', Importance.low),
  };

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          'item',
          actions: [
            DarwinNotificationAction.plain(
              'done',
              'تمّ',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              'snooze',
              'بعد ساعة',
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
        DarwinNotificationCategory(
          'contact',
          actions: [
            DarwinNotificationAction.plain(
              'call',
              'اتصل',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              'snooze',
              'بعد ساعة',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              'done',
              'تمّ',
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
      ],
    );
    await _plugin.initialize(
      settings: InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: (r) {
        final t = _parse(r.payload, r.actionId);
        if (t != null) taps.add(t);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      launchTap = _parse(
        launch!.notificationResponse?.payload,
        launch.notificationResponse?.actionId,
      );
    }
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl != null) {
      // قناة لكل نوع، فيتحكم المستخدم بصوت الصلاة منفصلًا.
      for (final ch in _channels.values) {
        await androidImpl.createNotificationChannel(
          AndroidNotificationChannel(ch.$1, ch.$2, importance: ch.$3),
        );
      }
      _exact = await androidImpl.canScheduleExactNotifications() ?? false;
    }
    _ready = true;
  }

  NotificationTap? _parse(String? payload, String? action) {
    if (payload == null || !payload.contains('|')) return null;
    final i = payload.indexOf('|');
    return NotificationTap(
      date: Day.parse(payload.substring(0, i)),
      itemKey: payload.substring(i + 1),
      action: (action == null || action.isEmpty) ? null : action,
    );
  }

  /// Android 13+: نطلب الإذن بعد التهيئة مع شرح، لا عند أول فتح.
  /// Android 14+: المنبّه الدقيق غير ممنوح افتراضيًا، نطلبه لدقة الصلاة.
  Future<bool> requestPermissions() async {
    await init();
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl != null) {
      final ok = await androidImpl.requestNotificationsPermission() ?? false;
      if (!(await androidImpl.canScheduleExactNotifications() ?? false)) {
        await androidImpl.requestExactAlarmsPermission();
      }
      _exact = await androidImpl.canScheduleExactNotifications() ?? false;
      return ok;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  /// يستبدل كل التنبيهات المعلّقة بالخطة الجديدة. المعرّف مشتق من (date, itemKey).
  Future<void> reschedule(List<PlannedNotification> list) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAllPendingNotifications();
      final cap = defaultTargetPlatform == TargetPlatform.iOS ? 60 : 240;
      for (final n in list.take(cap)) {
        final ch = _channels[n.kind]!;
        final when = tz.TZDateTime.from(n.when, tz.local);
        if (when.isBefore(tz.TZDateTime.now(tz.local))) continue;
        await _plugin.zonedSchedule(
          id: n.id,
          scheduledDate: when,
          title: n.title,
          body: n.body,
          payload: '${n.date.key}|${n.itemKey}',
          androidScheduleMode: _exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              ch.$1,
              ch.$2,
              importance: ch.$3,
              priority: n.kind == NotifyKind.prayer
                  ? Priority.max
                  : Priority.defaultPriority,
              category: n.kind == NotifyKind.prayer
                  ? AndroidNotificationCategory.reminder
                  : null,
              actions: !n.actionable
                  ? null
                  : [
                      if (n.contact)
                        const AndroidNotificationAction(
                          'call',
                          'اتصل',
                          showsUserInterface: true,
                        ),
                      const AndroidNotificationAction(
                        'snooze',
                        'بعد ساعة',
                        showsUserInterface: true,
                      ),
                      const AndroidNotificationAction(
                        'done',
                        'تمّ',
                        showsUserInterface: true,
                      ),
                    ],
            ),
            iOS: DarwinNotificationDetails(
              categoryIdentifier: !n.actionable
                  ? null
                  : (n.contact ? 'contact' : 'item'),
              // مستوى الانتباه time-sensitive للصلاة والمواعيد فقط.
              interruptionLevel:
                  (n.kind == NotifyKind.prayer ||
                      n.kind == NotifyKind.appointments)
                  ? InterruptionLevel.timeSensitive
                  : InterruptionLevel.active,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('تعذّر جدولة التنبيهات: $e');
    }
  }
}

/// يجمع خطط التنبيه للأيام القادمة: أسبوع على أندرويد، وثلاثة أيام على iOS
/// (حد ٦٤ تنبيهًا معلّقًا). كل فتح للتطبيق يعيد الجدولة من جديد.
List<PlannedNotification> notificationWindow(
  ScheduleEngine engine,
  AppSettings s,
  Day today,
  int now,
) => [
  for (
    var k = 0;
    k < (defaultTargetPlatform == TargetPlatform.iOS ? 3 : 7);
    k++
  )
    ...planNotifications(
      engine.day(today.add(k)),
      s,
      today: today,
      now: now,
    ).send,
];

/// شاشة مساعدة: هل الإذن مطلوب؟
Future<bool?> askNotificationPermission(
  BuildContext context,
) => showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Text('نذكّرك في وقتك؟'),
    content: const Text(
      'نرسل تنبيهات محلية من جهازك فقط: الصلاة في وقتها، والمواعيد والروتين قبلها بدقائق. تقدر تتحكم بكل نوع من الإعدادات.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(ctx, false),
        child: const Text('لاحقًا'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(ctx, true),
        child: const Text('فعّل التنبيهات'),
      ),
    ],
  ),
);
