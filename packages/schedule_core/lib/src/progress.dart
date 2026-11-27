import 'day.dart';
import 'engine.dart';
import 'plan.dart';
import 'records.dart';
import 'recurrence.dart';
import 'rules.dart';

/// عدّ بسيط مثل «5 من 18».
class Progress {
  const Progress(this.done, this.total);
  final int done;
  final int total;
  double get ratio => total == 0 ? 0 : done / total;
  int get percent => (ratio * 100).round();
  Progress operator +(Progress o) => Progress(done + o.done, total + o.total);
  static const zero = Progress(0, 0);
}

/// المقام: العناصر المحسوبة التي ليست مؤجلة ولا مستثناة ولا قبل الانضمام.
/// البسط: done وauto. الجلسة الإضافية تدخل فقط عندما تتم.
Progress dayProgress(DayPlan plan, {bool Function(PlanItem)? where}) {
  var done = 0, total = 0;
  for (final i in plan.items) {
    if (where != null && !where(i)) continue;
    if (!i.inDenominator) continue;
    total++;
    if (i.isDoneLike) done++;
  }
  return Progress(done, total);
}

Progress weekProgress(ScheduleEngine engine, Day anyDay) =>
    engine.week(anyDay).map(dayProgress).fold(Progress.zero, (a, b) => a + b);

/// تقدم عادة في الأسبوع: «X من Y» حيث Y هو الهدف الذي اختاره المستخدم.
class HabitWeek {
  const HabitWeek({
    required this.rule,
    required this.done,
    required this.target,
    required this.unplaced,
    required this.doneDays,
    required this.plannedDays,
  });
  final Rule rule;
  final int done;
  final int target;

  /// الجلسات بلا مكان هذا الأسبوع: «N ما لقت وقت».
  final int unplaced;
  final Set<Day> doneDays;
  final Set<Day> plannedDays;
}

HabitWeek habitWeek(ScheduleEngine engine, Rule rule, Day anyDay) {
  final c = rule.config as FlexConfig;
  final ws = anyDay.weekStart;
  var target = 0;
  switch (c.recurrence) {
    case TimesPerWeek(:final n):
      target = n * c.perDay;
    case Daily():
      target = 7 * c.perDay;
    case Weekdays(:final days):
      target = days.length * c.perDay;
    case Once():
      target = c.perDay;
  }
  var done = 0, unplaced = 0;
  final doneDays = <Day>{};
  final plannedDays = <Day>{};
  bool mine(String k) => k == rule.key || k.startsWith('${rule.key}#');
  for (var i = 0; i < 7; i++) {
    final plan = engine.day(ws.add(i));
    for (final it in plan.items) {
      final isMine = mine(it.key) || (it.isExtra && it.ruleKey == rule.key);
      if (!isMine) continue;
      if (!it.isExtra) plannedDays.add(plan.date);
      if (it.isDoneLike) {
        done++;
        doneDays.add(plan.date);
      }
    }
    unplaced += plan.unplaced
        .where((u) => u.ruleKey == rule.key && mine(u.key))
        .length;
  }
  return HabitWeek(
    rule: rule,
    done: done,
    target: target,
    unplaced: unplaced,
    doneDays: doneDays,
    plannedDays: plannedDays,
  );
}

/// ما لم يُسجّل أمس: شريط «أمس فيه N ما سجلتها».
List<PlanItem> unloggedItems(DayPlan plan) => plan.items
    .where((i) => i.counted && i.status == ItemStatus.missed)
    .toList();

/// الإنجاز حسب الفئة للإحصائيات.
Map<String, Progress> progressByCategory(Iterable<DayPlan> plans) {
  final out = <String, Progress>{};
  for (final p in plans) {
    for (final i in p.items) {
      if (!i.inDenominator) continue;
      out[i.category] =
          (out[i.category] ?? Progress.zero) +
          Progress(i.isDoneLike ? 1 : 0, 1);
    }
  }
  return out;
}
