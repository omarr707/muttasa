import 'day.dart';
import 'format.dart';
import 'plan.dart';
import 'profile.dart';
import 'records.dart';
import 'rules.dart';

/// تنبيه واحد مخطط.
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.date,
    required this.minute,
    required this.kind,
    required this.itemKey,
    required this.title,
    required this.body,
    this.actionable = false,
  });

  /// مشتق من (date, itemKey)، فالتحديث يستبدل ولا يكرّر.
  final int id;
  final Day date;

  /// دقيقة الإرسال من منتصف ليل [date] (قد تكون سالبة لليوم السابق).
  final int minute;
  final NotifyKind kind;
  final String itemKey;
  final String title;
  final String body;

  /// أزرار «تمت» و«أجّل ساعة» داخل التنبيه.
  final bool actionable;

  DateTime get when =>
      DateTime(date.year, date.month, date.day).add(Duration(minutes: minute));
}

class DroppedNotification {
  const DroppedNotification(this.title, this.minute, this.reason);
  final String title;
  final int minute;
  final String reason;
}

class NotificationPlan {
  const NotificationPlan(this.send, this.dropped);
  final List<PlannedNotification> send;
  final List<DroppedNotification> dropped;
}

/// معرّف ثابت 31 بت من (date, itemKey) بـ FNV-1a.
int notificationId(Day date, String itemKey) {
  var h = 0x811c9dc5;
  for (final c in '${date.key}|$itemKey'.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

NotifyKind? _kindFor(PlanItem i) {
  switch (i.kind) {
    case ItemKind.prayer:
      return NotifyKind.prayer;
    case ItemKind.kid:
    case ItemKind.klass:
    case ItemKind.event:
    case ItemKind.period:
      return NotifyKind.appointments;
    case ItemKind.task:
      return i.fixed ? NotifyKind.appointments : NotifyKind.routine;
    case ItemKind.adhkar:
    case ItemKind.quran:
    case ItemKind.habit:
    case ItemKind.meal:
      return NotifyKind.routine;
    case ItemKind.work:
      return null; // لا تنبيه للدوام والنوم.
  }
}

bool _inQuiet(int minute, AppSettings s) {
  final m = minute % minutesPerDay;
  if (s.quietStart == s.quietEnd) return false;
  if (s.quietStart < s.quietEnd) return m >= s.quietStart && m < s.quietEnd;
  return m >= s.quietStart || m < s.quietEnd;
}

/// NotificationPlanner: يأخذ خطة اليوم والإعدادات ويرجع ما يُرسل وما أُسقط مع السبب.
/// الأنواع بالأولوية: الصلاة، المواعيد، الروتين، الماء. الصلاة فوق القاعدتين.
NotificationPlan planNotifications(
  DayPlan plan,
  AppSettings s, {
  required Day today,
  required int now,
}) {
  final candidates = <PlannedNotification>[];
  final dropped = <DroppedNotification>[];
  final d = plan.date;
  final isToday = d == today;
  for (final i in plan.items) {
    final kind = _kindFor(i);
    if (kind == null) continue;
    if (i.status != ItemStatus.pending)
      continue; // لا تنبيه لمنجز أو مؤجل أو مستثنى.
    if (!s.notifyEnabled.contains(kind)) continue;
    final at = kind == NotifyKind.prayer ? i.start : i.start - s.leadMinutes;
    if (isToday && at <= now) continue;
    final body = kind == NotifyKind.prayer
        ? 'حان وقت ${i.title.replaceFirst('صلاة ', '')} · ${fmtTime(i.start)}'
        : '${fmtRange(i.start, i.end)}${i.subtitle == null || i.subtitle!.isEmpty ? '' : ' · ${i.subtitle}'}';
    candidates.add(
      PlannedNotification(
        id: notificationId(d, i.key),
        date: d,
        minute: at,
        kind: kind,
        itemKey: i.key,
        title: kind == NotifyKind.prayer
            ? i.title
            : (s.leadMinutes > 0
                  ? 'بعد ${s.leadMinutes} دقائق: ${i.title}'
                  : i.title),
        body: body,
        actionable:
            i.track == TrackMode.confirm || i.track == TrackMode.autocount,
      ),
    );
  }
  if (s.notifyEnabled.contains(NotifyKind.water)) {
    for (final l in plan.lines.where(
      (l) => l.kind == LineKind.water && !l.done,
    )) {
      if (isToday && l.minute <= now) continue;
      candidates.add(
        PlannedNotification(
          id: notificationId(d, l.key),
          date: d,
          minute: l.minute,
          kind: NotifyKind.water,
          itemKey: l.key,
          title: 'اشرب ماء',
          body: 'كوب ماء الحين؟',
        ),
      );
    }
  }
  if (s.eveningReview && plan.bedtime < minutesPerDay) {
    final at = plan.bedtime - 30;
    if (!isToday || at > now) {
      candidates.add(
        PlannedNotification(
          id: notificationId(d, 'review'),
          date: d,
          minute: at,
          kind: NotifyKind.routine,
          itemKey: 'review',
          title: 'راجع يومك',
          body: 'سجّل اللي سويته قبل تنام',
        ),
      );
    }
  }

  final prayers = candidates.where((c) => c.kind == NotifyKind.prayer).toList();
  final others = <PlannedNotification>[];
  for (final c in candidates.where((c) => c.kind != NotifyKind.prayer)) {
    if (_inQuiet(c.minute, s)) {
      dropped.add(DroppedNotification(c.title, c.minute, 'في أوقات الهدوء'));
    } else {
      others.add(c);
    }
  }
  // الحد اليومي: الزائد يُسقط بحسب الأولوية ثم الوقت.
  others.sort(
    (a, b) => a.kind.index != b.kind.index
        ? a.kind.index - b.kind.index
        : a.minute - b.minute,
  );
  final kept = others.take(s.dailyCap).toList();
  for (final c in others.skip(s.dailyCap)) {
    dropped.add(
      DroppedNotification(
        c.title,
        c.minute,
        'تجاوز الحد اليومي (${s.dailyCap})',
      ),
    );
  }
  final send = [...prayers, ...kept]..sort((a, b) => a.minute - b.minute);
  dropped.sort((a, b) => a.minute - b.minute);
  return NotificationPlan(send, dropped);
}
