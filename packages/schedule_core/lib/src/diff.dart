import 'day.dart';
import 'engine.dart';
import 'format.dart';
import 'records.dart';

enum ChangeType { moved, added, removed, unplaced }

class PlanChange {
  const PlanChange(this.type, this.title, {this.from, this.to, this.reason});
  final ChangeType type;
  final String title;
  final int? from;
  final int? to;
  final String? reason;

  String get label => switch (type) {
    ChangeType.moved => '$title: من ${fmtTime(from!)} إلى ${fmtTime(to!)}',
    ChangeType.added => '$title: جديد ${fmtTime(to!)}',
    ChangeType.removed => '$title: يُحذف',
    ChangeType.unplaced => '$title: ${reason ?? 'ما لقت وقت'}',
  };
}

class DayDiff {
  const DayDiff(this.date, this.changes, {required this.hasManualEdits});
  final Day date;
  final List<PlanChange> changes;

  /// يوم فيه تعديل يدوي: يُذكر في المعاينة.
  final bool hasManualEdits;
}

/// معاينة التغييرات: نولّد الأيام القادمة بالقواعد القديمة والجديدة ونعرض الفروق.
List<DayDiff> previewChanges(
  ScheduleEngine before,
  ScheduleEngine after,
  Day from, {
  int days = 7,
}) {
  final out = <DayDiff>[];
  for (var k = 0; k < days; k++) {
    final d = from.add(k);
    final a = before.day(d), b = after.day(d);
    final changes = <PlanChange>[];
    final oldByKey = {for (final i in a.items) i.key: i};
    final newByKey = {for (final i in b.items) i.key: i};
    for (final i in b.items) {
      final o = oldByKey[i.key];
      if (o == null) {
        changes.add(PlanChange(ChangeType.added, i.title, to: i.start));
      } else if (o.start != i.start) {
        changes.add(
          PlanChange(ChangeType.moved, i.title, from: o.start, to: i.start),
        );
      }
    }
    for (final o in a.items) {
      if (!newByKey.containsKey(o.key))
        changes.add(PlanChange(ChangeType.removed, o.title, from: o.start));
    }
    final oldUnplaced = a.unplaced.map((u) => u.key).toSet();
    for (final u in b.unplaced) {
      if (!oldUnplaced.contains(u.key)) {
        changes.add(
          PlanChange(ChangeType.unplaced, u.title, reason: u.reason.label),
        );
      }
    }
    final manual =
        after.input.overrides.values.any((o) => o.date == d) ||
        after.input.logs.values.any(
          (l) => l.date == d && l.status != ItemStatus.pending,
        );
    out.add(DayDiff(d, changes, hasManualEdits: manual));
  }
  return out;
}
