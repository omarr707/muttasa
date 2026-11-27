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

/// «أهدافي»: العادات وتقدمها في الأسبوع. الأهداف بالنتيجة والموعد في المرحلة الثانية.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final engine = ref.watch(engineProvider);
    final today = ref.watch(todayProvider);
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
            MCard(
              dashed: true,
              color: c.bg,
              border: c.accent,
              child: Row(
                children: [
                  Icon(Icons.flag_outlined, color: c.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'الأهداف بالنتيجة والموعد، والختمة والادخار، تجي مع المرحلة الثانية. الحين تابع عاداتك تحت.',
                      style: TextStyle(color: c.ink2, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            const SectionTitle('العادات'),
            if (habits.isEmpty)
              Text(
                'ما عندك عادات بعد. أضفها من «روتيني» ← المكتبة.',
                style: TextStyle(color: c.muted),
              ),
            for (final r in habits)
              _HabitCard(rule: r, engine: engine, today: today),
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
  });
  final Rule rule;
  final ScheduleEngine engine;
  final Day today;

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
