import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';
import '../routine/labels.dart';
import '../routine/preview.dart';
import '../routine/rule_editors.dart';
import 'amount_sheet.dart';
import 'goal_editor.dart';

/// «أهدافي»: الأهداف بالنتيجة والموعد (الحالة، المطلوب، التحذير)، ثم العادات.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final engine = ref.watch(engineProvider);
    final today = ref.watch(todayProvider);
    final userGoals = ref.watch(appDataProvider.select((d) => d.goals));
    final targets = [...engine.derivedGoals(userGoals), ...userGoals];
    final habits = engine
        .rulesOn(today, includePaused: true)
        .where(
          (r) =>
              r.config is FlexConfig &&
              (r.kind == RuleKind.habit || r.kind == RuleKind.quran),
        )
        .toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            const Text(
              'أهدافي',
              style: TextStyle(
                fontFamily: fontDisplay,
                fontWeight: FontWeight.w600,
                fontSize: 19,
              ),
            ),
            Text(
              'الهدف نتيجة لها موعد، والعادات هي اللي توصلك له. نقارن وين وصلت بوين المفروض تكون اليوم.',
              style: TextStyle(color: c.ink2),
            ),
            const SectionTitle('الأهداف'),
            if (targets.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  nums('ما عندك هدف بموعد. مثلًا: «أقرأ 12 كتاب هالسنة».'),
                  style: TextStyle(color: c.muted),
                ),
              ),
            for (final g in targets)
              _GoalCard(status: engine.goalStatus(g), today: today),
            PillButton(
              label: '+ هدف جديد',
              expand: true,
              onPressed: () => openGoalEditor(context),
            ),
            const SectionTitle('العادات'),
            if (habits.isEmpty)
              Text(
                'ما عندك عادات بعد. أضفها من «روتيني» ← المكتبة.',
                style: TextStyle(color: c.muted),
              ),
            for (final r in habits)
              _HabitCard(
                rule: r,
                engine: engine,
                today: today,
                feeds: targets
                    .where((g) => g.linkKey == r.key)
                    .map((g) => g.title)
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _HabitCard extends ConsumerWidget {
  const _HabitCard({
    required this.rule,
    required this.engine,
    required this.today,
    this.feeds = const [],
  });
  final Rule rule;
  final ScheduleEngine engine;
  final Day today;

  /// الأهداف اللي تغذيها هذه العادة.
  final List<String> feeds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final cfg = rule.config as FlexConfig;
    final w = habitWeek(engine, rule, today);
    final ws = today.weekStart;
    final paused = rule.pausedOn(today);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(iconFor(cfg.icon), color: c.ink),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cfg.title,
                        style: const TextStyle(
                          fontFamily: fontDisplay,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        ruleSummary(cfg),
                        style: TextStyle(fontSize: 12, color: c.ink2),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'إعدادات ${cfg.title}',
                  icon: Icon(Icons.settings_outlined, color: c.muted),
                  onPressed: () async {
                    final next = await editRuleConfig(context, cfg);
                    if (next != null && context.mounted) {
                      await saveWithPreview(context, ref, rule, next);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  fmtCount(w.done, w.target),
                  style: const TextStyle(
                    fontFamily: fontDisplay,
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
                Text(
                  '  هذا الأسبوع',
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
                const Spacer(),
                if (paused)
                  Text(
                    'موقوفة مؤقتًا',
                    style: TextStyle(color: c.warn, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: w.target == 0 ? 0 : (w.done / w.target).clamp(0, 1),
                minHeight: 8,
                backgroundColor: c.line,
                color: c.accent2,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var k = 0; k < 7; k++)
                  Expanded(
                    child: Builder(
                      builder: (_) {
                        final d = ws.add(k);
                        final done = w.doneDays.contains(d);
                        final planned = w.plannedDays.contains(d);
                        return Column(
                          children: [
                            Text(
                              arabicWeekdayLetters[d.weekday]!,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: d == today ? c.ink : c.muted,
                                fontWeight: d == today
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: done
                                    ? c.good
                                    : (planned ? c.card : Colors.transparent),
                                border: Border.all(
                                  color: done
                                      ? c.good
                                      : (planned ? c.accent2 : c.line),
                                ),
                              ),
                              child: done
                                  ? const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
            if (feeds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  nums('تغذي: ${feeds.join('، ')}'),
                  style: TextStyle(color: c.ink2, fontSize: 12.5),
                ),
              ),
            if (w.unplaced > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${nums(w.unplaced)} ما لقت وقت',
                  style: TextStyle(
                    color: c.warn,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            PillButton(
              label: '+ جلسة إضافية اليوم',
              soft: true,
              dense: true,
              onPressed: () async {
                final o = OneOff(
                  id: newId(),
                  kind: OneOffKind.habitSession,
                  title: 'جلسة إضافية: ${cfg.title}',
                  date: today,
                  duration: cfg.duration,
                  window: Window.any,
                  habitKey: rule.key,
                );
                await ref.read(appDataProvider.notifier).addOneOff(o);
                if (!context.mounted) return;
                final placed = ref
                    .read(dayPlanProvider(today))
                    .byKey(o.itemKey);
                toast(
                  context,
                  placed == null
                      ? 'ما لقت وقت فاضي اليوم'
                      : 'انضافت ${fmtTime(placed.start)} في «يومي»',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة هدف: الحالة، شريط التقدم مع علامة «المفروض»، والإجراء.
class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.status, required this.today});
  final GoalStatus status;
  final Day today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final g = status.goal;
    final ctrl = ref.read(appDataProvider.notifier);
    final engine = ref.watch(engineProvider);
    final currency = ref.watch(
      appDataProvider.select((d) => d.profile?.currency ?? 'ريال'),
    );
    final unit = g.unitLabel(currency);
    final feeds = switch (g.metric) {
      GoalMetric.khatma => 'ورد القرآن',
      GoalMetric.money =>
        engine
                .rulesOn(today)
                .where((r) => r.config is SavingsConfig)
                .map((r) => 'يوم الراتب ${(r.config as SavingsConfig).payDay}')
                .firstOrNull ??
            '',
      _ =>
        engine
                .rulesOn(today, includePaused: true)
                .where((r) => r.key == g.linkKey && r.config is FlexConfig)
                .map((r) => (r.config as FlexConfig).title)
                .firstOrNull ??
            '',
    };
    final sub = [
      g.due == null ? 'بدون موعد' : fmtDue(g.due!, today),
      if (feeds.isNotEmpty) 'تغذيه: $feeds',
    ].join(' · ');
    final st = status.state;
    final (chipBg, chipFg) = st.good
        ? (c.goodSoft, c.good)
        : st.late
        ? (c.amberSoft, c.amber)
        : (c.sunk, c.ink2);

    Future<void> edit() async {
      if (!g.derived) return openGoalEditor(context, goal: g);
      final rule = engine
          .rulesOn(today, includePaused: true)
          .where((r) => r.key == g.linkKey)
          .firstOrNull;
      if (rule == null) return;
      final next = await editRuleConfig(context, rule.config);
      if (next != null && context.mounted) {
        await saveWithPreview(context, ref, rule, next);
      }
    }

    Widget? action;
    if (g.metric.manual && !g.derived) {
      action = SmallButton(
        label: nums('+1 $unit'),
        primary: true,
        onTap: () async {
          await ctrl.addGoalEntry(g.id, 1);
          if (context.mounted) {
            toast(
              context,
              nums('+1 $unit في «${g.title}»'),
              actionLabel: 'تراجع',
              onAction: () => ctrl.addGoalEntry(g.id, -1),
            );
          }
        },
      );
    } else if (g.metric == GoalMetric.money) {
      action = SmallButton(
        label: 'سجّل مبلغ',
        primary: true,
        onTap: () async {
          final planned =
              engine
                  .rulesOn(today)
                  .where((r) => r.config is SavingsConfig)
                  .map((r) => (r.config as SavingsConfig).monthly)
                  .firstOrNull ??
              500;
          final amount = await showAmountSheet(
            context,
            planned: planned,
            currency: currency,
          );
          if (amount == null) return;
          await ctrl.logSaving(amount);
          if (context.mounted) {
            toast(context, nums('سجّلنا ${fmtThousands(amount)} $currency'));
          }
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MCard(
        onTap: edit,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconSquare(iconFor(g.metric.icon)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nums(g.title), style: T.cardTitle),
                      Text(
                        nums(sub),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.meta.copyWith(color: c.muted),
                      ),
                    ],
                  ),
                ),
                if (st != GoalState.noDue)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      st.label,
                      style: T.label.copyWith(color: chipFg, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _ProgressBar(
              ratio: status.ratio,
              expected: status.expected == null || g.target == 0
                  ? null
                  : (status.expected! / g.target).clamp(0, 1).toDouble(),
              color: st.good ? c.good : c.accent,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: nums(fmtThousands(status.value)),
                          style: T.stat.copyWith(fontSize: 17),
                        ),
                        TextSpan(
                          text: nums(' من ${fmtThousands(g.target)} $unit'),
                          style: TextStyle(color: c.ink2, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                ?action,
                IconButton(
                  tooltip: 'تعديل ${g.title}',
                  icon: Icon(Icons.edit_outlined, size: 20, color: c.muted),
                  onPressed: edit,
                ),
              ],
            ),
            Text(
              nums(status.message),
              style: T.meta.copyWith(
                color: st.late ? c.amber : c.ink2,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// شريط تقدم مع علامة رفيعة عند «المفروض تكون الحين».
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.ratio, this.expected, required this.color});
  final double ratio;
  final double? expected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 12,
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: c.line,
                color: color,
              ),
            ),
            if (expected != null)
              PositionedDirectional(
                start: (box.maxWidth * expected!).clamp(0, box.maxWidth - 2),
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: c.ink2),
              ),
          ],
        ),
      ),
    );
  }
}
