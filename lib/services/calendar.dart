import 'package:device_calendar_plus/device_calendar_plus.dart' as dc;
import 'package:flutter/foundation.dart';
import 'package:schedule_core/schedule_core.dart';

import '../data/calendar_link.dart';

/// التقويمات: قراءة فقط من التقويمات المختارة، ولا نكتب فيها أبدًا.
class CalendarService {
  static dc.DeviceCalendar get _plugin => dc.DeviceCalendar.instance;

  /// اسم المصدر كما يعرفه المستخدم.
  static String sourceLabel(String? accountType, String? accountName) {
    final t = (accountType ?? '').toLowerCase();
    final n = (accountName ?? '').toLowerCase();
    if (t.contains('google') || n.endsWith('@gmail.com')) return 'Google';
    if (t.contains('icloud') ||
        t.contains('caldav') && n.contains('icloud') ||
        n.contains('icloud')) {
      return 'Apple';
    }
    if (t.contains('exchange') || t.contains('outlook')) return 'Outlook';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'Apple';
    return 'التقويم';
  }

  /// يطلب الإذن عند الحاجة. false إذا رفض المستخدم.
  static Future<bool> ensurePermission() async {
    try {
      var s = await _plugin.hasPermissions();
      if (s == dc.CalendarPermissionStatus.granted) return true;
      s = await _plugin.requestPermissions();
      return s == dc.CalendarPermissionStatus.granted;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasPermission() async {
    try {
      return await _plugin.hasPermissions() ==
          dc.CalendarPermissionStatus.granted;
    } catch (_) {
      return false;
    }
  }

  static Future<List<DeviceCal>> calendars() async {
    if (!await ensurePermission()) return const [];
    final list = await _plugin.listCalendars();
    return [
      for (final c in list.where((c) => !c.hidden))
        DeviceCal(
          id: c.id,
          name: c.name,
          source: sourceLabel(c.accountType, c.accountName),
          colorHex: c.colorHex,
        ),
    ];
  }

  /// مواعيد التقويمات المختارة من أمس إلى [days] يومًا قدام.
  /// المواعيد الممتدة على أكثر من يوم تُقسم على أيامها.
  static Future<List<ImportedEvent>> fetch(
    List<DeviceCal> chosen, {
    required Day from,
    int days = 30,
  }) async {
    if (chosen.isEmpty || !await hasPermission()) return const [];
    final byId = {for (final c in chosen) c.id: c};
    final start = DateTime(from.year, from.month, from.day);
    final end = start.add(Duration(days: days));
    final events = await _plugin.listEvents(
      start,
      end,
      calendarIds: byId.keys.toList(),
    );
    final out = <ImportedEvent>[];
    for (final e in events) {
      final cal = byId[e.calendarId];
      final source = cal?.source ?? 'التقويم';
      final title = e.title.trim().isEmpty ? 'موعد' : e.title.trim();
      final id = e.instanceId.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
      if (e.isAllDay) {
        // التاريخ عائم: نأخذ مكوّنات التاريخ كما هي.
        var d = Day(e.startDate.year, e.startDate.month, e.startDate.day);
        final last = Day(e.endDate.year, e.endDate.month, e.endDate.day);
        var n = 0;
        do {
          out.add(
            ImportedEvent(
              id: '$id-$n',
              date: d,
              title: title,
              source: source,
              calendar: cal?.name,
            ),
          );
          d = d.next;
          n++;
        } while (d.isBefore(last) && n < 31);
        continue;
      }
      final s = e.startDate.toLocal();
      final en = e.endDate.toLocal();
      var d = Day(s.year, s.month, s.day);
      final lastDay = Day(en.year, en.month, en.day);
      var n = 0;
      while (!d.isAfter(lastDay) && n < 31) {
        final first = d == Day(s.year, s.month, s.day);
        final last = d == lastDay;
        final sm = first ? s.hour * 60 + s.minute : 0;
        final em = last ? en.hour * 60 + en.minute : minutesPerDay;
        if (em > sm) {
          out.add(
            ImportedEvent(
              id: '$id-$n',
              date: d,
              title: title,
              start: sm,
              end: em,
              source: source,
              calendar: cal?.name,
            ),
          );
        }
        d = d.next;
        n++;
      }
    }
    return out;
  }
}
