import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';

/// «تقرير الالتزام»: شهري (تقويم حرارة، أقوى وأضعف يوم، أطول سلسلة)
/// أو سنوي (عمود لكل شهر)، وفي الاثنين: حسب النوع، الأهداف، والتواصل.
class CommitmentReport extends ConsumerStatefulWidget {
  const CommitmentReport({
    super.key,
    required this.yearly,
    required this.anchor,
  });
  final bool yearly;
  final Day anchor;

  @override
  ConsumerState<CommitmentReport> createState() => _CommitmentReportState();
}

class _CommitmentReportState extends ConsumerState<CommitmentReport> {
  late int _year = widget.anchor.year;
  late int _month = widget.anchor.month;

  void _shift(int delta) => setState(() {
    if (widget.yearly) {
      _year += delta;
      return;
    }
    final m = _year * 12 + (_month - 1) + delta;
    _year = m ~/ 12;
    _month = m % 12 + 1;
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final engine = ref.watch(engineProvider);
    final today = ref.watch(todayProvider);
    final data = ref.watch(appDataProvider);
    final yearly = widget.yearly;
    final r = yearly
        ? engine.yearReport(_year)
        : engine.monthReport(_year, _month);
    final prevR = yearly
        ? engine.yearReport(_year - 1)
        : engine.monthReport(
            _month == 1 ? _year - 1 : _year,
            _month == 1 ? 12 : _month - 1,
          );
    final title = yearly
        ? nums('سنة $_year')
        : nums('${arabicMonths[_month - 1]} $_year');
    final canNext = yearly
        ? _year < today.year
        : (_year * 12 + _month) < (today.year * 12 + today.month);
    final join = data.profile!.joinDay;

    final children = <Widget>[
      Row(
        children: [
          IconButton(
            tooltip: yearly ? 'السنة السابقة' : 'الشهر السابق',
            onPressed: () => _shift(-1),
            icon: const Icon(Icons.chevron_right),
          ),
          Expanded(
            child: Text(title, textAlign: TextAlign.center, style: T.section),
          ),
          IconButton(
            tooltip: yearly ? 'السنة التالية' : 'الشهر التالي',
            onPressed: canNext ? () => _shift(1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
        ],
      ),
    ];

    if (r.isEmpty) {
      final before =
          (yearly ? Day(_year, 12, 31) : Day(_year, _month + 1, 1).prev)
              .isBefore(join);
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            before
                ? nums(
                    'بدأت معنا ${join.day} ${arabicMonths[join.month - 1]} ${join.year}.',
                  )
                : 'ما فيه سجل في هالفترة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted),
          ),
        ),
      );
    } else {
      final p = r.total.percent;
      final prev = prevR.isEmpty ? null : prevR.total.percent;
      children.addAll([
        const SizedBox(height: 4),
        Center(child: Text(nums('$p٪'), style: T.stat.copyWith(fontSize: 34))),
        Center(
          child: Text(
            nums(
              '${r.total.done} من ${r.total.total} مهمة'
              '${prev == null ? '' : ' · ${p >= prev ? 'أعلى' : 'أقل'} من ${yearly ? 'السنة اللي قبلها' : 'الشهر اللي قبله'} ($prev٪)'}',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: c.ink2, fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        if (!yearly) ...[
          _Heat(report: r, year: _year, month: _month),
          const SizedBox(height: 6),
          Text(
            'كل ما غمق المربع زاد إنجازك في اليوم.',
            style: T.meta.copyWith(color: c.muted),
          ),
          const SizedBox(height: 10),
          _Facts(report: r),
        ] else
          _YearBars(engine: engine, year: _year, today: today),
        const SectionTitle('حسب النوع'),
        for (final g in ReportGroup.values)
          if ((r.byGroup[g]?.total ?? 0) > 0)
            _GroupBar(label: g.label, p: r.byGroup[g]!),
        ..._goals(context, engine, data.goals),
        ..._contacts(context, r, data.people),
      ]);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      child: MCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  List<Widget> _goals(
    BuildContext context,
    ScheduleEngine engine,
    List<Goal> userGoals,
  ) {
    final c = context.c;
    final all = [...engine.derivedGoals(userGoals), ...userGoals];
    if (all.isEmpty) return const [];
    final currency = ref.read(appDataProvider).profile?.currency ?? 'ريال';
    return [
      const SectionTitle('الأهداف'),
      for (final g in all)
        Builder(
          builder: (_) {
            final s = engine.goalStatus(g);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(child: Text(nums(g.title))),
                  Text(
                    nums(
                      '${fmtThousands(s.value)} من ${fmtThousands(g.target)} ${g.unitLabel(currency)} · ',
                    ),
                    style: TextStyle(color: c.ink2, fontSize: 12.5),
                  ),
                  Text(
                    s.state.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: s.state.good
                          ? c.good
                          : (s.state.late ? c.amber : c.ink2),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
    ];
  }

  List<Widget> _contacts(
    BuildContext context,
    RangeReport r,
    List<Person> people,
  ) {
    final c = context.c;
    if (people.isEmpty) return const [];
    final missed = people.where((p) => !r.contacted.contains(p.id)).toList();
    return [
      const SectionTitle('التواصل'),
      Row(
        children: [
          const Expanded(child: Text('تواصلت مع')),
          Text(
            nums('${r.contacted.length} من ${people.length} أشخاص'),
            style: TextStyle(color: c.ink2),
          ),
        ],
      ),
      if (missed.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'ما تواصلت هالفترة مع: ${missed.take(4).map((p) => p.name).join('، ')}'
            '${missed.length > 4 ? ' وغيرهم' : ''}',
            style: T.meta.copyWith(color: c.muted, fontSize: 12.5),
          ),
        ),
    ];
  }
}

/// تقويم حرارة الشهر: أعمدة من السبت إلى الجمعة.
class _Heat extends StatelessWidget {
  const _Heat({required this.report, required this.year, required this.month});
  final RangeReport report;
  final int year;
  final int month;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final first = Day(year, month, 1);
    final last = Day(year, month + 1, 1).prev;
    final offset = weekOrder.indexOf(first.weekday);
    final cells = <Widget>[
      for (final d in weekOrder)
        Center(
          child: Text(
            arabicWeekdayLetters[d]!,
            style: T.label.copyWith(color: c.ink2, fontSize: 11.5),
          ),
        ),
      for (var i = 0; i < offset; i++) const SizedBox.shrink(),
    ];
    for (var d = first; !d.isAfter(last); d = d.next) {
      final p = report.days[d];
      final pct = p == null || p.total == 0 ? null : p.percent;
      final (bg, fg) = switch (pct) {
        null => (c.sunk.withValues(alpha: .5), c.muted),
        >= 80 => (c.accent, c.onAccent),
        >= 60 => (c.accent.withValues(alpha: .65), c.onAccent),
        >= 40 => (c.accent.withValues(alpha: .35), c.ink),
        _ => (c.accent.withValues(alpha: .15), c.ink2),
      };
      cells.add(
        Semantics(
          label: nums('${d.day}: ${pct == null ? 'بدون سجل' : '$pct٪'}'),
          excludeSemantics: true,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              nums('${d.day}'),
              style: TextStyle(fontSize: 11, color: fg),
            ),
          ),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 1.15,
      children: cells,
    );
  }
}

/// أقوى وأضعف يوم في الأسبوع، وأطول سلسلة فوق ٨٠٪.
class _Facts extends StatelessWidget {
  const _Facts({required this.report});
  final RangeReport report;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bw = report.bestWorstWeekday;
    final byW = report.byWeekday;
    final streak = report.longestStreak;
    Widget kv(String k, String v) => Expanded(
      child: Container(
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: c.sunk,
          borderRadius: BorderRadius.circular(R.sm + 4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: T.meta.copyWith(color: c.ink2)),
            Text(nums(v), style: T.cardTitle.copyWith(fontSize: 14)),
          ],
        ),
      ),
    );
    return Column(
      children: [
        if (bw != null)
          Row(
            children: [
              kv(
                'أقوى يوم',
                '${arabicWeekdays[bw.$1]} · ${byW[bw.$1]!.percent}٪',
              ),
              kv(
                'أضعف يوم',
                '${arabicWeekdays[bw.$2]} · ${byW[bw.$2]!.percent}٪',
              ),
            ],
          ),
        Row(
          children: [
            kv(
              'أطول سلسلة فوق ٨٠٪',
              streak == 0
                  ? 'ولا يوم للحين'
                  : '$streak ${streak >= 3 && streak <= 10 ? 'أيام' : 'يوم'}',
            ),
          ],
        ),
      ],
    );
  }
}

/// السنة: عمود لكل شهر.
class _YearBars extends StatelessWidget {
  const _YearBars({
    required this.engine,
    required this.year,
    required this.today,
  });
  final ScheduleEngine engine;
  final int year;
  final Day today;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var m = 1; m <= 12; m++)
            Expanded(
              child: Builder(
                builder: (_) {
                  final future = year * 12 + m > today.year * 12 + today.month;
                  final r = future ? null : engine.monthReport(year, m);
                  final pct = r == null || r.isEmpty ? null : r.total.percent;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FittedBox(
                        child: Text(
                          pct == null ? '–' : nums('$pct'),
                          style: TextStyle(fontSize: 10, color: c.muted),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: 14,
                        height: 100 * math.max(.04, (pct ?? 0) / 100),
                        decoration: BoxDecoration(
                          color: pct == null ? c.line : c.accent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        child: Text(
                          arabicMonths[m - 1].substring(0, 3),
                          style: TextStyle(fontSize: 10, color: c.ink2),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupBar extends StatelessWidget {
  const _GroupBar({required this.label, required this.p});
  final String label;
  final Progress p;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: T.body)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: p.ratio,
                minHeight: 8,
                backgroundColor: c.line,
                color: p.percent >= 70 ? c.good : c.accent,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              nums('${p.percent}٪'),
              textAlign: TextAlign.end,
              style: TextStyle(color: c.ink2, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
