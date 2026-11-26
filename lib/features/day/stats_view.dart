import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';

const categoryLabels = {
  'prayer': 'الصلاة والأذكار',
  'quran': 'القرآن',
  'habits': 'العادات',
  'freelance': 'العمل الحر',
  'meals': 'الوجبات',
  'fixed': 'المواعيد الثابتة',
  'tasks': 'المهام',
};

/// الإحصائيات: الأسبوع. تقرير الالتزام الشهري والسنوي في المرحلة الثانية.
class StatsView extends ConsumerWidget {
  const StatsView({super.key, required this.date});
  final Day date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final engine = ref.watch(engineProvider);
    final today = ref.watch(todayProvider);
    final week = engine.week(date);
    final total = week.map(dayProgress).fold(Progress.zero, (a, b) => a + b);
    final soFar = week
        .where((p) => !p.date.isAfter(today))
        .map(dayProgress)
        .fold(Progress.zero, (a, b) => a + b);
    final byCat = progressByCategory(week.where((p) => !p.date.isAfter(today)));
    final maxTotal = week
        .map((p) => dayProgress(p).total)
        .fold(1, (a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: ProgressRing(
              progress: soFar.ratio,
              size: 140,
              color: c.accent2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${soFar.percent}%',
                    style: const TextStyle(
                      fontFamily: fontDisplay,
                      fontWeight: FontWeight.w700,
                      fontSize: 26,
                    ),
                  ),
                  Text(
                    'حتى اليوم',
                    style: TextStyle(fontSize: 12, color: c.muted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'الأسبوع: ${fmtCount(total.done, total.total)} · حتى اليوم ${fmtCount(soFar.done, soFar.total)}',
              style: TextStyle(color: c.ink2),
            ),
          ),
          const SectionTitle('أيام الأسبوع'),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final p in week)
                  Expanded(
                    child: Builder(
                      builder: (_) {
                        final pr = dayProgress(p);
                        final future = p.date.isAfter(today);
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              future ? '' : '${pr.percent}%',
                              style: TextStyle(fontSize: 11, color: c.muted),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 22,
                              height: 100 * (pr.total / maxTotal).clamp(.05, 1),
                              decoration: BoxDecoration(
                                color: c.line,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: pr.ratio,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: p.date == date ? c.ink : c.accent2,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              arabicWeekdayLetters[p.date.weekday]!,
                              style: TextStyle(
                                fontSize: 12,
                                color: c.ink2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SectionTitle('حسب النوع'),
          if (byCat.isEmpty)
            Text(
              'ما فيه بيانات بعد هذا الأسبوع.',
              style: TextStyle(color: c.muted),
            ),
          for (final e in byCat.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          categoryLabels[e.key] ?? e.key,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        fmtCount(e.value.done, e.value.total),
                        style: TextStyle(color: c.ink2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: e.value.ratio,
                      minHeight: 8,
                      backgroundColor: c.line,
                      color: c.accent2,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          MCard(
            child: Row(
              children: [
                Icon(Icons.insights_outlined, color: c.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تقرير الالتزام الشهري والسنوي يجي مع المرحلة الثانية.',
                    style: TextStyle(color: c.ink2, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
