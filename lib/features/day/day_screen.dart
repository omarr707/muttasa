import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/hijri.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';
import 'add_sheet.dart';
import 'item_card.dart';
import 'item_sheet.dart';
import 'stats_view.dart';

enum _Tab { timeline, stats }

enum _Filter { all, done }

/// «يومي»: تنفّذ فيه.
class DayScreen extends ConsumerStatefulWidget {
  const DayScreen({super.key, this.focusKey});
  final String? focusKey;
  @override
  ConsumerState<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends ConsumerState<DayScreen> {
  _Tab _tab = _Tab.timeline;
  _Filter _filter = _Filter.all;
  bool _showPast = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final date = ref.watch(selectedDayProvider);
    final today = ref.watch(todayProvider);
    final plan = ref.watch(dayPlanProvider(date));
    final todayPlan = ref.watch(dayPlanProvider(today));
    final engine = ref.watch(engineProvider);
    final profile = ref.watch(appDataProvider.select((d) => d.profile))!;
    final todayProgress = dayProgress(todayPlan);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, color: c.accent2),
                    const SizedBox(width: 8),
                    const Text(
                      'مُتَّسَع',
                      style: TextStyle(
                        fontFamily: fontDisplay,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    const Spacer(),
                    _MiniRing(progress: todayProgress),
                    IconButton(
                      tooltip: 'الإعدادات',
                      onPressed: () => context.push('/settings'),
                      icon: const Icon(Icons.menu),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _WeekStrip(selected: date, engine: engine, today: today),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Segmented<_Tab>(
                  values: _Tab.values,
                  labels: const ['الجدول الزمني', 'الإحصائيات'],
                  selected: _tab,
                  onChanged: (t) => setState(() => _tab = t),
                ),
              ),
            ),
            if (_tab == _Tab.stats)
              SliverToBoxAdapter(child: StatsView(date: date))
            else ...[
              SliverToBoxAdapter(
                child: _Header(
                  date: date,
                  plan: plan,
                  engine: engine,
                  hijriOffset: profile.hijriOffset,
                  islam: profile.islam,
                ),
              ),
              SliverToBoxAdapter(
                child: _Actions(
                  date: date,
                  plan: plan,
                  filter: _filter,
                  onFilter: (f) => setState(() => _filter = f),
                ),
              ),
              SliverToBoxAdapter(
                child: _Banners(date: date, plan: plan, today: today),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
                sliver: SliverList.list(
                  children: _timeline(context, plan, date, today),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  child: Column(
                    children: [
                      if (date == today) _SleepCard(plan: plan),
                      const SizedBox(height: 12),
                      PillButton(
                        label: 'عرض اليوم التالي · ${fmtDayLong(date.next)}',
                        soft: true,
                        expand: true,
                        onPressed: () => ref
                            .read(selectedDayProvider.notifier)
                            .set(date.next),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _timeline(
    BuildContext context,
    DayPlan plan,
    Day date,
    Day today,
  ) {
    final c = context.c;
    final now = ref.watch(nowMinuteProvider);
    final water = (
      ref.watch(
            appDataProvider.select(
              (d) => d.logs[recordKey(date, 'water')]?.value,
            ),
          ) ??
          0,
      plan.lines.where((l) => l.kind == LineKind.water).length,
    );
    final items = plan.items
        .where((i) => _filter == _Filter.all || i.isDoneLike)
        .toList();
    final lines = _filter == _Filter.all
        ? plan.lines.where((l) => l.kind != LineKind.sleep).toList()
        : <ReminderLine>[];

    if (items.isEmpty && lines.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _filter == _Filter.done
                ? 'ما فيه شي منجز بعد.'
                : 'يومك فاضي. أضف من «روتيني» أو من «+ إضافة».',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted),
          ),
        ),
      ];
    }

    // ندمج البطاقات والخطوط بالترتيب الزمني.
    final entries = <(int, Object)>[
      for (final i in items) (i.start, i),
      for (final l in lines) (l.minute, l),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    Widget row(Object e, {int? hourOf}) {
      final hourLabel = hourOf == null ? '' : fmtHour(hourOf);
      final child = e is PlanItem
          ? ItemCard(item: e, date: date, highlight: widget.focusKey == e.key)
          : ReminderLineTile(line: e as ReminderLine, date: date, water: water);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: Padding(
                padding: EdgeInsets.only(top: e is PlanItem ? 14 : 4),
                child: Text(
                  hourLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: c.muted,
                    fontFamily: fontDisplay,
                  ),
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    List<Widget> build(List<(int, Object)> list) {
      final out = <Widget>[];
      int? lastHour;
      for (final (m, e) in list) {
        final h = m ~/ 60;
        out.add(row(e, hourOf: h != lastHour ? m : null));
        lastHour = h;
      }
      return out;
    }

    if (date != today || _filter == _Filter.done) return build(entries);

    // اليوم: مضى / الآن / لاحقًا مع خط «الآن».
    bool isPast((int, Object) e) {
      final o = e.$2;
      if (o is PlanItem) return o.end <= now && o.status != ItemStatus.pending;
      return (o as ReminderLine).minute < now;
    }

    final past = entries.where(isPast).toList();
    bool isLate((int, Object) e) {
      final o = e.$2;
      return o is PlanItem && o.end <= now;
    }

    final notPast = entries.where((e) => !isPast(e)).toList();
    final late = notPast.where(isLate).toList();
    final rest = notPast.where((e) => !isLate(e)).toList();
    final pastItems = past
        .where((e) => e.$2 is PlanItem)
        .map((e) => e.$2 as PlanItem);
    final upcomingItem = rest
        .map((e) => e.$2)
        .whereType<PlanItem>()
        .where((i) => i.start > now)
        .firstOrNull;
    final out = <Widget>[];
    out.add(
      _SectionHeader(
        title: 'مضى',
        trailing:
            '${pastItems.where((i) => i.isDoneLike).length} من ${pastItems.length} مهام',
        icon: _showPast ? Icons.expand_less : Icons.expand_more,
        onTap: () => setState(() => _showPast = !_showPast),
      ),
    );
    if (_showPast) out.addAll(build(past));
    if (late.isNotEmpty) {
      out.add(
        _SectionHeader(
          title: 'فاتت وتحتاج قرارك',
          trailing: '${late.length} ${late.length == 1 ? 'مهمة' : 'مهام'}',
        ),
      );
      out.addAll(build(late));
    }
    out.add(_NowLine(now: now));
    final current = rest
        .map((e) => e.$2)
        .whereType<PlanItem>()
        .where((i) => i.start <= now && i.end > now)
        .firstOrNull;
    if (current != null) {
      out.add(
        _SectionHeader(
          title: 'الحين',
          trailing: 'باقي ${fmtDuration(current.end - now)}',
        ),
      );
    } else if (upcomingItem != null) {
      out.add(
        _SectionHeader(
          title: 'التالي',
          trailing: 'بعد ${fmtDuration(upcomingItem.start - now)}',
        ),
      );
    }
    out.addAll(build(rest));
    return out;
  }
}

class _MiniRing extends StatelessWidget {
  const _MiniRing({required this.progress});
  final Progress progress;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 4, 12, 4),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          ProgressRing(progress: progress.ratio, size: 26, stroke: 3.5),
          const SizedBox(width: 6),
          Text(
            fmtCount(progress.done, progress.total),
            style: const TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends ConsumerWidget {
  const _WeekStrip({
    required this.selected,
    required this.engine,
    required this.today,
  });
  final Day selected;
  final ScheduleEngine engine;
  final Day today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final ws = selected.weekStart;
    final set = ref.read(selectedDayProvider.notifier).set;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'الأسبوع السابق',
            onPressed: () => set(selected.add(-7)),
            icon: const Icon(Icons.chevron_right),
          ),
          Expanded(
            child: Row(
              children: [
                for (var k = 0; k < 7; k++)
                  Expanded(
                    child: Builder(
                      builder: (_) {
                        final d = ws.add(k);
                        final on = d == selected;
                        final p = dayProgress(engine.day(d));
                        return Semantics(
                          button: true,
                          selected: on,
                          label: fmtDayLong(d),
                          child: GestureDetector(
                            onTap: () => set(d),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: on ? c.accent : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    d == today
                                        ? 'اليوم'
                                        : arabicWeekdayLetters[d.weekday]!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: on ? c.accentInk : c.muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${d.day}',
                                    style: TextStyle(
                                      fontFamily: fontDisplay,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: on ? c.accentInk : c.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 4,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: on ? Colors.white54 : c.line,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    alignment: AlignmentDirectional.centerStart,
                                    child: FractionallySizedBox(
                                      widthFactor: p.ratio,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: on ? c.accentInk : c.accent2,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'الأسبوع التالي',
            onPressed: () => set(selected.add(7)),
            icon: const Icon(Icons.chevron_left),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.date,
    required this.plan,
    required this.engine,
    required this.hijriOffset,
    required this.islam,
  });
  final Day date;
  final DayPlan plan;
  final ScheduleEngine engine;
  final int hijriOffset;
  final bool islam;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = dayProgress(plan);
    final w = weekProgress(engine, date);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
      child: Column(
        children: [
          Text(
            fmtDayLong(date),
            style: const TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
          ),
          if (islam)
            Text(
              hijriLabel(date, offset: hijriOffset),
              style: TextStyle(color: c.muted, fontSize: 13),
            ),
          const SizedBox(height: 14),
          Semantics(
            label: 'إنجاز اليوم ${p.done} من ${p.total}',
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ProgressRing(
                  progress: p.ratio,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fmtCount(p.done, p.total),
                        style: const TextStyle(
                          fontFamily: fontDisplay,
                          fontWeight: FontWeight.w700,
                          fontSize: 21,
                        ),
                      ),
                      Text(
                        'إنجاز اليوم',
                        style: TextStyle(fontSize: 11.5, color: c.muted),
                      ),
                    ],
                  ),
                ),
                PositionedDirectional(
                  bottom: 2,
                  end: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: c.pill,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: c.bg, width: 3),
                    ),
                    child: Text(
                      '${p.percent}%',
                      style: TextStyle(
                        color: c.pillInk,
                        fontSize: 12,
                        fontFamily: fontDisplay,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'الأسبوع: ',
                  style: TextStyle(color: c.muted),
                ),
                TextSpan(
                  text: fmtCount(w.done, w.total),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({
    required this.date,
    required this.plan,
    required this.filter,
    required this.onFilter,
  });
  final Day date;
  final DayPlan plan;
  final _Filter filter;
  final ValueChanged<_Filter> onFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: PillButton(
                  label: 'إضافة',
                  icon: Icons.add,
                  expand: true,
                  onPressed: () => showAddSheet(context, ref, date),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PillButton(
                  label: 'رتّب يومي',
                  icon: Icons.shuffle,
                  soft: true,
                  expand: true,
                  onPressed: date != today
                      ? null
                      : () => _rearrange(context, ref),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Segmented<_Filter>(
              small: true,
              values: _Filter.values,
              labels: const ['كل المهام', 'المنجزة'],
              selected: filter,
              onChanged: onFilter,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rearrange(BuildContext context, WidgetRef ref) async {
    final now = ref.read(nowMinuteProvider);
    final r = rearrangeDay(plan, now);
    if (r.moves.isEmpty && r.failed.isEmpty) {
      toast(context, 'يومك مرتب. ما فيه شي متأخر.');
      return;
    }
    final ctrl = ref.read(appDataProvider.notifier);
    await ctrl.applyRearrange(date, r.moves);
    if (!context.mounted) return;
    if (r.failed.isEmpty) {
      toast(
        context,
        'رتّبنا ${r.moves.length} مهام بعد الآن',
        actionLabel: 'تراجع',
        onAction: () async {
          for (final k in r.moves.keys) {
            await ctrl.clearOverride(date, k);
          }
        },
      );
    } else {
      await showModalBottomSheet<void>(
        useRootNavigator: true,
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'رتّبنا ${r.moves.length}، وهذي ما لقت وقت اليوم',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                for (final i in r.failed)
                  ListTile(
                    title: Text(i.title),
                    trailing: PillButton(
                      label: 'أجّل',
                      dense: true,
                      onPressed: () {
                        Navigator.pop(ctx);
                        showPostponeSheet(context, ref, i, date);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
  }
}

class _Banners extends ConsumerWidget {
  const _Banners({required this.date, required this.plan, required this.today});
  final Day date;
  final DayPlan plan;
  final Day today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = <Widget>[];
    for (final cf in plan.conflicts) {
      final target = cf.a.kind == ItemKind.work ? cf.b : cf.a;
      banners.add(
        _Banner(
          icon: Icons.warning_amber_rounded,
          title: 'تعارض بين «${cf.a.title}» و«${cf.b.title}»',
          body: 'ما نحرّك الثابت. عدّل هذا أو ذاك.',
          action: 'عدّل',
          onTap: () => showItemSheet(context, ref, target, date),
        ),
      );
    }
    if (date == today) {
      final y = ref.watch(dayPlanProvider(today.prev));
      final missed = y.items
          .where(
            (i) => i.counted && i.status == ItemStatus.missed && i.log == null,
          )
          .length;
      if (missed > 0) {
        banners.add(
          _Banner(
            icon: Icons.history,
            title: 'أمس فيه $missed ما سجلتها',
            body: 'تنحسب «فاتت»، وتقدر تسجلها الحين.',
            action: 'راجعها',
            onTap: () => ref.read(selectedDayProvider.notifier).set(today.prev),
          ),
        );
      }
    }
    final unplaced = plan.unplaced;
    if (unplaced.isNotEmpty) {
      banners.add(
        _Banner(
          icon: Icons.hourglass_empty,
          title: unplaced.map((u) => u.title).toSet().join('، '),
          body: unplaced.first.reason.label,
        ),
      );
    }
    if (banners.isEmpty) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(children: banners),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: c.warn),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(body, style: TextStyle(fontSize: 13, color: c.ink2)),
              ],
            ),
          ),
          if (action != null)
            PillButton(
              label: action!,
              dense: true,
              soft: true,
              onPressed: onTap,
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.trailing,
    this.icon,
    this.onTap,
  });
  final String title;
  final String trailing;
  final IconData? icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 0, 6),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: fontDisplay,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            if (icon != null) Icon(icon, size: 20, color: c.muted),
            const Spacer(),
            Text(trailing, style: TextStyle(color: c.muted, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class _NowLine extends StatelessWidget {
  const _NowLine({required this.now});
  final int now;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 0, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: c.accent2,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'الآن ${fmtTime(now)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Container(height: 2, color: c.accent2)),
        ],
      ),
    );
  }
}

/// بطاقة النوم: «راجع يومك».
class _SleepCard extends ConsumerWidget {
  const _SleepCard({required this.plan});
  final DayPlan plan;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final sleep = plan.lines.where((l) => l.kind == LineKind.sleep).firstOrNull;
    if (sleep == null) return const SizedBox.shrink();
    final pending = plan.items
        .where((i) => i.counted && i.status == ItemStatus.pending)
        .toList();
    return MCard(
      color: c.kid,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bedtime_outlined, color: c.ink2),
              const SizedBox(width: 10),
              Text(
                'وقت النوم · ${fmtTime(sleep.minute)}',
                style: const TextStyle(
                  fontFamily: fontDisplay,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            pending.isEmpty
                ? 'سجلت كل شي اليوم. تصبح على خير.'
                : 'قبل تنام: ${pending.length} ما سجلتها اليوم. اللي يبقى بدون جواب ينحسب «فاتت» بكرة.',
            style: TextStyle(color: c.ink2, fontSize: 13),
          ),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 10),
            PillButton(
              label: 'راجع يومك',
              dense: true,
              onPressed: () => showReviewSheet(context, ref, plan.date),
            ),
          ],
        ],
      ),
    );
  }
}

/// مراجعة سريعة لما لم يُسجّل.
Future<void> showReviewSheet(BuildContext context, WidgetRef ref, Day date) =>
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final c = ctx.c;
          final plan = ref.watch(dayPlanProvider(date));
          final pending = plan.items
              .where(
                (i) =>
                    i.counted &&
                    (i.status == ItemStatus.pending ||
                        i.status == ItemStatus.missed),
              )
              .toList();
          final ctrl = ref.read(appDataProvider.notifier);
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * .75,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  const Text(
                    'راجع يومك',
                    style: TextStyle(
                      fontFamily: fontDisplay,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (pending.isEmpty)
                    Text('سجلت كل شي ✓', style: TextStyle(color: c.good)),
                  for (final i in pending)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  i.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  fmtRange(i.start, i.end),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: c.ink2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PillButton(
                            label: 'تمت',
                            dense: true,
                            onPressed: () => ctrl.markDone(date, i),
                          ),
                          const SizedBox(width: 6),
                          PillButton(
                            label: 'لا',
                            dense: true,
                            soft: true,
                            onPressed: () =>
                                ctrl.setStatus(date, i, ItemStatus.notDone),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
