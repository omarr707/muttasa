import 'actions.dart';
import 'day.dart';
import 'engine.dart';
import 'plan.dart';
import 'records.dart';
import 'rules.dart';

// ---------------------------------------------------------------------------
// «يوم خفيف»: الثابت والأولويات تبقى، والمرن يتأجل. المستخدم يراجع قبل التطبيق.
// ---------------------------------------------------------------------------

enum LightAction {
  keep('خلّه'),
  evening('المساء'),
  tomorrow('بكرة');

  const LightAction(this.label);
  final String label;
}

class LightProposal {
  const LightProposal(this.item, this.action, {this.eveningAt});
  final PlanItem item;
  final LightAction action;

  /// وقت فاضٍ في المساء (للتواصل غالبًا).
  final int? eveningAt;
}

/// ما يبقى في مكانه دائمًا: الصلاة والدوام والالتزامات والصحة والوجبات والأذكار.
bool staysOnLightDay(PlanItem i) =>
    !isMovable(i) ||
    i.fixed ||
    i.kind == ItemKind.meal ||
    i.kind == ItemKind.adhkar ||
    i.category == 'health';

/// اقتراح «يوم خفيف» لـ[plan]. [now] للعناصر اللي فاتت اليوم.
/// [priorities] مفاتيح اختار المستخدم إبقاءها.
List<LightProposal> lightDay(
  DayPlan plan, {
  required int now,
  required bool isToday,
  Set<String> priorities = const {},
}) {
  final out = <LightProposal>[];
  final taken = <Busy>[];
  for (final i in plan.items) {
    if (i.status != ItemStatus.pending) continue;
    if (staysOnLightDay(i)) continue;
    if (isToday && i.end <= now) continue;
    if (priorities.contains(i.key)) {
      out.add(LightProposal(i, LightAction.keep));
      continue;
    }
    if (i.kind == ItemKind.contact) {
      // الاتصال ينتقل للمساء إن فيه وقت، وإلا بكرة.
      final from = [
        19 * 60,
        if (isToday) now + 10,
        i.end,
      ].reduce((a, b) => a > b ? a : b);
      final t = firstFreeAfter(
        plan,
        i.duration,
        from,
        ignoreKey: i.key,
        extra: taken,
      );
      if (t != null) {
        taken.add(Busy(Span(t, t + i.duration), BusyKind.flex, i.title));
        out.add(LightProposal(i, LightAction.evening, eveningAt: t));
        continue;
      }
    }
    out.add(LightProposal(i, LightAction.tomorrow));
  }
  return out;
}

// ---------------------------------------------------------------------------
// المراجعة الأسبوعية: ملاحظات قابلة للتصرف، والمستخدم يقرر.
// ---------------------------------------------------------------------------

class WeeklyNote {
  const WeeklyNote({
    required this.ruleKey,
    required this.title,
    required this.missed,
    required this.total,
    this.suggestWindow,
  });
  final String ruleKey;
  final String title;

  /// كم مرة تأجلت أو فاتت أو ما تنفّذت في الأيام السبعة.
  final int missed;
  final int total;

  /// فترة بديلة نقترح تجربتها (الأقل ازدحامًا بالتأجيل).
  final Window? suggestWindow;
}

/// يمر على الأيام السبعة قبل [today] ويرجع العادات اللي تعثرت مرتين أو أكثر.
List<WeeklyNote> weeklyNotes(ScheduleEngine engine, Day today) {
  final counts = <String, (int, int, String, Window)>{};
  for (var k = 1; k <= 7; k++) {
    final plan = engine.day(today.add(-k));
    for (final i in plan.items) {
      final rk = i.ruleKey;
      if (rk == null || i.fixed || !isMovable(i)) continue;
      if (i.status == ItemStatus.preJoin) continue;
      final bad = {
        ItemStatus.postponed,
        ItemStatus.missed,
        ItemStatus.notDone,
      }.contains(i.status);
      final cur = counts[rk];
      counts[rk] = (
        (cur?.$1 ?? 0) + (bad ? 1 : 0),
        (cur?.$2 ?? 0) + 1,
        i.title,
        windowOf(i.start, plan),
      );
    }
  }
  final rules = {for (final r in engine.rulesOn(today)) r.key: r};
  final out = <WeeklyNote>[];
  for (final e in counts.entries) {
    final (missed, total, title, usual) = e.value;
    if (missed < 2) continue;
    final cfg = rules[e.key]?.config;
    Window? alt;
    if (cfg is FlexConfig) {
      alt = usual == Window.morning ? Window.night : Window.morning;
    }
    out.add(
      WeeklyNote(
        ruleKey: e.key,
        title: title,
        missed: missed,
        total: total,
        suggestWindow: alt,
      ),
    );
  }
  out.sort((a, b) => b.missed.compareTo(a.missed));
  return out;
}

/// فترة الوقت حسب ساعة البداية.
Window windowOf(int minute, DayPlan plan) {
  if (minute < 12 * 60) return Window.morning;
  if (minute < 17 * 60) return Window.afternoon;
  return Window.night;
}
