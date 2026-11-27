import 'day.dart';
import 'engine.dart';
import 'format.dart';
import 'plan.dart';
import 'records.dart';
import 'rules.dart';

/// نتيجة فحص نقل عنصر: السبب، وأقرب وقت فاضٍ.
class MoveCheck {
  const MoveCheck.ok() : ok = true, reason = null, suggestion = null;
  const MoveCheck.blocked(this.reason, this.suggestion) : ok = false;
  final bool ok;
  final String? reason;
  final int? suggestion;
}

/// ConflictChecker: السحب أو النقل يحافظ على المدة، ويرد بالسبب.
MoveCheck checkMove(
  DayPlan plan,
  PlanItem item,
  int newStart, {
  Set<String> soft = const {},
}) {
  final s = newStart, e = newStart + item.duration;
  if (s < 0 || e > minutesPerDay) {
    return MoveCheck.blocked('خارج اليوم', nearestFree(plan, item, newStart));
  }
  for (final b in plan.busy) {
    if (b.key == item.key || soft.contains(b.key)) continue;
    if (!b.span.overlapsRange(s, e)) continue;
    String reason;
    switch (b.kind) {
      case BusyKind.sleep:
        reason = 'في وقت النوم';
      case BusyKind.work:
        reason = 'داخل الدوام خارج الاستراحة';
      case BusyKind.fixed:
        reason = 'يتعارض مع «${b.label}» وهو موعد ثابت';
      case BusyKind.flex:
        // المرن الآخر يتزحزح عند إعادة التوليد، فلا نمنع.
        continue;
    }
    return MoveCheck.blocked(reason, nearestFree(plan, item, newStart));
  }
  return const MoveCheck.ok();
}

/// أقرب وقت فاضٍ: بحث للأمام والخلف بخطوة 5 دقائق حتى 10 ساعات.
int? nearestFree(
  DayPlan plan,
  PlanItem item,
  int around, {
  bool includeFlex = false,
}) {
  final hard = plan.busy
      .where((b) => includeFlex || b.kind != BusyKind.flex)
      .toList();
  final base = (around ~/ 5) * 5;
  for (var delta = 0; delta <= 600; delta += 5) {
    for (final t in [base + delta, base - delta]) {
      if (ScheduleEngine.isFree(
        hard,
        t,
        t + item.duration,
        ignoreKey: item.key,
      )) {
        return t;
      }
    }
  }
  return null;
}

/// أول فراغ بعد [after] حتى وقت النوم، مع احترام كل المحجوز.
int? firstFreeAfter(
  DayPlan plan,
  int duration,
  int after, {
  String? ignoreKey,
  List<Busy>? extra,
}) {
  final busy = [...plan.busy, ...?extra];
  final end = plan.bedtime.clamp(0, minutesPerDay);
  for (var t = ((after + 4) ~/ 5) * 5; t + duration <= end; t += 5) {
    if (ScheduleEngine.isFree(busy, t, t + duration, ignoreKey: ignoreKey)) {
      return t;
    }
  }
  return null;
}

/// «أعد ترتيب يومي»: كل عنصر مرن متأخر وغير مسجّل ينتقل لأقرب فراغ
/// بعد الآن بـ 5 دقائق، بترتيب مواعيده الأصلية. الثابت والمنجز لا يُلمسان.
class RearrangeResult {
  const RearrangeResult(this.moves, this.failed);

  /// itemKey → البداية الجديدة.
  final Map<String, int> moves;

  /// ما لا يجد وقتًا يُعرض مع زر «أجّل».
  final List<PlanItem> failed;
}

RearrangeResult rearrangeDay(DayPlan plan, int now) {
  final late =
      plan.items
          .where(
            (i) =>
                !i.fixed &&
                i.status == ItemStatus.pending &&
                i.start < now &&
                i.log?.timerRunning != true &&
                i.counted,
          )
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  final lateKeys = late.map((i) => i.key).toSet();
  final busy = plan.busy.where((b) => !lateKeys.contains(b.key)).toList();
  final moves = <String, int>{};
  final failed = <PlanItem>[];
  final end = plan.bedtime.clamp(0, minutesPerDay);
  for (final i in late) {
    int? found;
    for (var t = ((now + 5 + 4) ~/ 5) * 5; t + i.duration <= end; t += 5) {
      if (ScheduleEngine.isFree(busy, t, t + i.duration)) {
        found = t;
        break;
      }
    }
    if (found == null) {
      failed.add(i);
    } else {
      moves[i.key] = found;
      busy.add(
        Busy(
          Span(found, found + i.duration),
          BusyKind.flex,
          i.title,
          key: i.key,
        ),
      );
    }
  }
  return RearrangeResult(moves, failed);
}

/// «أجّل ساعة»: أول فراغ بعد ساعة من الآن.
int? postponeHourSlot(DayPlan plan, PlanItem item, int now) =>
    firstFreeAfter(plan, item.duration, now + 60, ignoreKey: item.key);

/// «أجّل لبكرة»: لا يتكرر إذا العنصر موجود أصلًا بكرة.
bool needsCarry(ScheduleEngine engine, PlanItem item, Day from) {
  final tomorrow = engine.day(from.next);
  return !tomorrow.hasKey(item.key);
}

/// وصف مختصر لحالة البطاقة.
String statusLabel(PlanItem i, {required bool isToday, required int now}) {
  switch (i.status) {
    case ItemStatus.done:
      if (i.doneAt != null && (i.doneAt! - i.start).abs() > 20) {
        return 'نفّذتها ${fmtTime(i.doneAt!)}';
      }
      return 'تمت';
    case ItemStatus.auto:
      return 'تُحسب تلقائيًا';
    case ItemStatus.missed:
      return 'فاتت';
    case ItemStatus.notDone:
      return 'لم أنفّذها';
    case ItemStatus.skipped:
      return 'مستثناة';
    case ItemStatus.postponed:
      return 'مؤجلة';
    case ItemStatus.preJoin:
      return 'قبل انضمامك';
    case ItemStatus.pending:
      if (isToday && i.end <= now && i.track != TrackMode.auto) {
        return 'فات وقتها';
      }
      if (isToday && i.start <= now && now < i.end) return 'الآن';
      return '';
  }
}

/// نتيجة «نزحزح اللي بعده؟»: البدايات الجديدة للعناصر اللاحقة.
class ReflowResult {
  const ReflowResult(this.moves, this.overlapped);

  /// itemKey → البداية الجديدة.
  final Map<String, int> moves;

  /// العناصر القابلة للتحريك التي يتداخل معها الوقت الجديد مباشرة.
  final List<PlanItem> overlapped;

  bool get needed => overlapped.isNotEmpty;
}

/// يُحرَّك تلقائيًا: ليس صلاة ولا دوامًا ولا مشوار أولاد ولا حصة، وليس من تقويم
/// أو للشريك، ولم يُسجَّل بعد.
bool isMovable(PlanItem i) =>
    !{
      ItemKind.prayer,
      ItemKind.work,
      ItemKind.kid,
      ItemKind.klass,
    }.contains(i.kind) &&
    !i.partner &&
    i.source == null &&
    i.status == ItemStatus.pending;

/// عند وضع [item] في [newStart]: نزحزح العناصر اللاحقة المتداخلة واحدًا بعد واحد
/// إلى أول فراغ بعد سابقتها، مع احترام الثابت والنوم.
ReflowResult reflowAfter(DayPlan plan, PlanItem item, int newStart) {
  final s = newStart, e = newStart + item.duration;
  final later =
      plan.items
          .where((i) => i.key != item.key && isMovable(i) && i.start >= s)
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  final overlapped = [
    for (final i in plan.items)
      if (i.key != item.key && isMovable(i) && i.start < e && s < i.end) i,
  ];
  if (overlapped.isEmpty) return const ReflowResult({}, []);
  final laterKeys = {for (final i in later) i.key, item.key};
  // المحجوز الثابت فقط، والعناصر اللاحقة تُضاف بأماكنها الجديدة.
  final busy = <Busy>[
    for (final b in plan.busy)
      if (!laterKeys.contains(b.key)) b,
    Busy(Span(s, e), BusyKind.fixed, item.title, key: item.key),
  ];
  final end = plan.bedtime.clamp(0, minutesPerDay);
  final moves = <String, int>{};
  for (final i in later) {
    if (ScheduleEngine.isFree(busy, i.start, i.end)) {
      busy.add(Busy(Span(i.start, i.end), BusyKind.fixed, i.title, key: i.key));
      continue;
    }
    int? t;
    for (var m = ((i.start + 4) ~/ 5) * 5; m + i.duration <= end; m += 5) {
      if (ScheduleEngine.isFree(busy, m, m + i.duration)) {
        t = m;
        break;
      }
    }
    if (t == null) continue;
    moves[i.key] = t;
    busy.add(
      Busy(Span(t, t + i.duration), BusyKind.fixed, i.title, key: i.key),
    );
  }
  return ReflowResult(moves, overlapped);
}
