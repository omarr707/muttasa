import 'day.dart';
import 'engine.dart';
import 'plan.dart';
import 'progress.dart';

/// مجموعات تقرير الالتزام.
enum ReportGroup {
  prayer('الصلوات'),
  goals('العادات والقرآن'),
  contacts('التواصل'),
  other('باقي المهام');

  const ReportGroup(this.label);
  final String label;

  static ReportGroup of(PlanItem i) => switch (i.kind) {
    ItemKind.prayer || ItemKind.adhkar => prayer,
    ItemKind.quran || ItemKind.habit => goals,
    ItemKind.contact => contacts,
    _ => other,
  };
}

/// إحصاء فترة: من [from] إلى [to] (شامل)، لا يتجاوز اليوم ولا يسبق الانضمام.
class RangeReport {
  const RangeReport({
    required this.from,
    required this.to,
    required this.total,
    required this.days,
    required this.byGroup,
    required this.contacted,
  });
  final Day from;
  final Day to;
  final Progress total;

  /// كل يوم محسوب في الفترة مع إنجازه.
  final Map<Day, Progress> days;
  final Map<ReportGroup, Progress> byGroup;

  /// من تواصلت معه في الفترة (معرّفات الأشخاص).
  final Set<String> contacted;

  bool get isEmpty => total.total == 0;

  /// نسبة كل يوم من أيام الأسبوع (1..7)، للأقوى والأضعف.
  Map<int, Progress> get byWeekday {
    final out = <int, Progress>{};
    for (final e in days.entries) {
      if (e.value.total == 0) continue;
      out[e.key.weekday] = (out[e.key.weekday] ?? Progress.zero) + e.value;
    }
    return out;
  }

  /// (أقوى يوم، أضعف يوم) بالنسبة.
  (int, int)? get bestWorstWeekday {
    final w = byWeekday.entries.toList();
    if (w.isEmpty) return null;
    w.sort((a, b) => b.value.ratio.compareTo(a.value.ratio));
    return (w.first.key, w.last.key);
  }

  /// أطول سلسلة أيام متتالية بإنجاز 80% فأكثر.
  int get longestStreak {
    var run = 0, best = 0;
    final keys = days.keys.toList()..sort();
    for (final d in keys) {
      final p = days[d]!;
      if (p.total > 0 && p.percent >= 80) {
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }
    return best;
  }
}

extension ReportOnEngine on ScheduleEngine {
  RangeReport rangeReport(Day from, Day to) {
    final today = input.today;
    final join = input.profile.joinDay;
    final lo = from.isBefore(join) ? join : from;
    final days = <Day, Progress>{};
    final groups = <ReportGroup, Progress>{};
    final contacted = <String>{};
    var total = Progress.zero;
    for (var d = lo; !d.isAfter(to) && !d.isAfter(today); d = d.next) {
      final plan = day(d);
      final p = dayProgress(plan);
      days[d] = p;
      total = total + p;
      for (final i in plan.items) {
        if (!i.inDenominator) continue;
        final g = ReportGroup.of(i);
        groups[g] =
            (groups[g] ?? Progress.zero) + Progress(i.isDoneLike ? 1 : 0, 1);
        if (i.isDoneLike && i.kind == ItemKind.contact && i.personId != null) {
          contacted.add(i.personId!);
        }
      }
    }
    return RangeReport(
      from: lo,
      to: to,
      total: total,
      days: days,
      byGroup: groups,
      contacted: contacted,
    );
  }

  RangeReport monthReport(int year, int month) =>
      rangeReport(Day(year, month, 1), Day(year, month + 1, 1).prev);

  RangeReport yearReport(int year) =>
      rangeReport(Day(year, 1, 1), Day(year, 12, 31));
}
