import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/hijri.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';
import 'add_sheet.dart';
import 'friday_sheet.dart';
import 'item_card.dart';
import 'item_sheet.dart';
import 'missed_sheet.dart';
import 'stats_view.dart';
import 'water_sheet.dart';

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final d = ref.read(selectedDayProvider);
      if (shouldShowFriday(ref, d)) showFridaySheet(context, ref, d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final date = ref.watch(selectedDayProvider);
    final today = ref.watch(todayProvider);
    final plan = ref.watch(dayPlanProvider(date));
    final todayPlan = ref.watch(dayPlanProvider(today));
    final engine = ref.watch(engineProvider);
    final profile = ref.watch(appDataProvider.select((d) => d.profile))!;
    final settings = ref.watch(appDataProvider.select((d) => d.settings));
    final now = ref.watch(nowMinuteProvider);
    final todayProgress = dayProgress(todayPlan);
    final isToday = date == today;
    final missed = isToday ? missedToday(plan, now) : const <PlanItem>[];

    final greg = fmtDayLong(date);
    final hijri = hijriLabel(date, offset: profile.hijriOffset, short: true);
    final dateLine = switch (settings.headerDate) {
      HeaderDate.gregorian => greg,
      HeaderDate.hijri => '${arabicWeekdays[date.weekday]} · ${nums(hijri)}',
      HeaderDate.both => '$greg · ${nums(hijri)}',
    };

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _tab == _Tab.stats
          ? null
          : _Fabs(
              onAdd: () => showAddSheet(context, ref, date),
              onRearrange: isToday
                  ? () => rearrangeFlow(context, ref, date, plan)
                  : null,
            ),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('مُتَّسَع', style: T.brand),
                          Text(
                            dateLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: T.meta.copyWith(color: c.muted),
                          ),
                        ],
                      ),
                    ),
                    _MiniRing(
                      progress: todayProgress,
                      onTap: () => setState(() => _tab = _Tab.stats),
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
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.line)),
                  ),
                  child: Row(
                    children: [
                      UnderlineTabs<_Tab>(
                        values: _Tab.values,
                        labels: const ['الجدول', 'الإحصائيات'],
                        selected: _tab,
                        onChanged: (t) => setState(() => _tab = t),
                      ),
                      const Spacer(),
                      if (_tab == _Tab.timeline)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: c.ink2,
                            textStyle: T.label.copyWith(fontSize: 12.5),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => setState(
                            () => _filter = _filter == _Filter.all
                                ? _Filter.done
                                : _Filter.all,
                          ),
                          icon: const Icon(Icons.filter_list, size: 18),
                          label: Text(
                            _filter == _Filter.all ? 'الكل' : 'المنجزة',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_tab == _Tab.stats)
              SliverToBoxAdapter(child: StatsView(date: date))
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!date.isAfter(today))
                        _HabitChips(date: date, plan: plan),
                      FridayCard(date: date, plan: plan),
                      if (missed.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        MissedBar(
                          count: missed.length,
                          when: missedWhen(missed, plan),
                          onOpen: () => showMissedSheet(context, ref, date),
                        ),
                      ],
                      _Banners(date: date, plan: plan, today: today),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 4, 16, 8),
                sliver: SliverList.list(
                  children: _timeline(context, plan, date, today, settings),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  child: Column(
                    children: [
                      if (isToday) _SleepCard(plan: plan),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => ref
                            .read(selectedDayProvider.notifier)
                            .set(date.next),
                        child: Text(
                          'عرض اليوم التالي · ${fmtDayLong(date.next)}',
                        ),
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
    AppSettings settings,
  ) {
    final c = context.c;
    final now = ref.watch(nowMinuteProvider);
    final isToday = date == today;
    final missedKeys = isToday
        ? missedToday(plan, now).map((i) => i.key).toSet()
        : const <String>{};
    final items = plan.items
        .where((i) => _filter == _Filter.all || i.isDoneLike)
        .where((i) => !missedKeys.contains(i.key))
        .toList();
    final lines = _filter == _Filter.all && settings.showLines
        ? plan.lines.where((l) => l.kind != LineKind.sleep).toList()
        : <ReminderLine>[];

    if (items.isEmpty && lines.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _filter == _Filter.done
                ? 'ما فيه شي منجز بعد.'
                : (missedKeys.isNotEmpty
                      ? 'الباقي في «راجعها» فوق.'
                      : 'يومك فاضي. أضف من «روتيني» أو من زر +.'),
            textAlign: TextAlign.center,
            style: T.body.copyWith(color: c.muted),
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
          : ReminderLineTile(line: e as ReminderLine, date: date);
      return Padding(
        padding: EdgeInsets.symmetric(vertical: e is PlanItem ? 4 : 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 38,
              child: Padding(
                padding: EdgeInsets.only(top: e is PlanItem ? 12 : 6),
                child: Text(
                  hourLabel,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: T.micro.copyWith(
                    color: c.muted,
                    fontWeight: FontWeight.w400,
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

    if (!isToday || _filter == _Filter.done) return build(entries);

    // اليوم: مضى (مطوي) / خط الآن / الحين أو التالي.
    bool isPast((int, Object) e) {
      final o = e.$2;
      if (o is PlanItem) return o.end <= now;
      return (o as ReminderLine).minute < now;
    }

    final past = entries.where(isPast).toList();
    final rest = entries.where((e) => !isPast(e)).toList();
    final pastItems = past
        .where((e) => e.$2 is PlanItem)
        .map((e) => e.$2 as PlanItem);
    final out = <Widget>[];
    if (past.isNotEmpty) {
      out.add(
        _SectionHeader(
          title: 'مضى',
          trailing: pastItems.isEmpty
              ? null
              : '${fmtCount(pastItems.where((i) => i.isDoneLike).length, pastItems.length)} تمّت',
          icon: _showPast ? Icons.expand_less : Icons.expand_more,
          onTap: () => setState(() => _showPast = !_showPast),
        ),
      );
      if (_showPast) out.addAll(build(past));
    }
    out.add(_NowLine(now: now));
    final current = rest
        .map((e) => e.$2)
        .whereType<PlanItem>()
        .where((i) => i.start <= now && i.end > now)
        .firstOrNull;
    final upcoming = rest
        .map((e) => e.$2)
        .whereType<PlanItem>()
        .where((i) => i.start > now)
        .firstOrNull;
    if (current != null) {
      out.add(
        _SectionHeader(
          title: 'الحين',
          trailing: 'باقي ${fmtDuration(current.end - now)}',
        ),
      );
    } else if (upcoming != null) {
      out.add(
        _SectionHeader(
          title: 'التالي',
          trailing: 'بعد ${fmtDuration(upcoming.start - now)}',
        ),
      );
    }
    out.addAll(build(rest));
    return out;
  }
}

/// صف العادات الخفيفة: الماء بعدّاده، والتنفس والوقفة.
class _HabitChips extends ConsumerWidget {
  const _HabitChips({required this.date, required this.plan});
  final Day date;
  final DayPlan plan;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final water = plan.lines.where((l) => l.kind == LineKind.water).toList();
    final breathe = plan.lines
        .where((l) => l.kind == LineKind.breathe)
        .firstOrNull;
    final stands = plan.lines.where((l) => l.kind == LineKind.stand).toList();
    if (water.isEmpty && breathe == null && stands.isEmpty) {
      return const SizedBox.shrink();
    }
    final ctrl = ref.read(appDataProvider.notifier);
    final standDone = ref.watch(
      appDataProvider.select(
        (d) => d.logs[recordKey(date, 'stand')]?.value ?? 0,
      ),
    );
    Widget chip({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      Color? bg,
      Color? fg,
      bool done = false,
      Widget? trailing,
    }) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: bg ?? c.card,
        shape: StadiumBorder(
          side: BorderSide(color: bg == null ? c.line : Colors.transparent),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              10,
              4,
              trailing == null ? 12 : 4,
              4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  done ? Icons.check : icon,
                  size: 16,
                  color: done ? c.good : (fg ?? c.ink2),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: T.label.copyWith(color: fg ?? c.ink, fontSize: 12.5),
                ),
                if (trailing != null) ...[const SizedBox(width: 6), trailing],
              ],
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (water.isNotEmpty)
              chip(
                icon: Icons.water_drop,
                label: fmtCount(
                  water.where((l) => l.done).length,
                  water.length,
                ),
                bg: c.waterSoft,
                fg: c.water,
                onTap: () => showWaterSheet(context, ref, date),
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: c.water,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add, size: 16, color: c.card),
                ),
              ),
            if (breathe != null) ...[
              const SizedBox(width: 8),
              chip(
                icon: Icons.air,
                label: 'تنفّس',
                done: breathe.done,
                onTap: () => ctrl.toggleLine(date, breathe.key, !breathe.done),
              ),
            ],
            if (stands.isNotEmpty) ...[
              const SizedBox(width: 8),
              chip(
                icon: Icons.accessibility_new,
                label: standDone > 0 ? 'وقفة ${nums(standDone)}' : 'وقفة',
                onTap: () async {
                  await ctrl.countLight(date, 'stand', 1);
                  if (context.mounted) {
                    toast(
                      context,
                      'سجّلنا وقفة',
                      actionLabel: 'تراجع',
                      onAction: () => ctrl.countLight(date, 'stand', -1),
                    );
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniRing extends StatelessWidget {
  const _MiniRing({required this.progress, this.onTap});
  final Progress progress;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pct = (progress.ratio * 100).round();
    return Semantics(
      button: true,
      label: 'إنجاز اليوم ${progress.done} من ${progress.total}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ProgressRing(
          progress: progress.ratio,
          size: 40,
          stroke: 3.5,
          color: c.accent,
          child: Text(
            '${nums(pct)}٪',
            style: T.micro.copyWith(fontSize: 10.5, color: c.ink),
          ),
        ),
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
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < 200) return;
        // اتجاه عربي: السحب لليمين يرجع للأسبوع السابق.
        set(selected.add(v > 0 ? 7 : -7));
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Row(
          children: [
            for (var k = 0; k < 7; k++)
              Expanded(
                child: Builder(
                  builder: (_) {
                    final d = ws.add(k);
                    final on = d == selected;
                    final p = dayProgress(engine.day(d));
                    final fg = on ? c.onAccent : c.ink;
                    return Semantics(
                      button: true,
                      selected: on,
                      label: fmtDayLong(d),
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () => set(d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 50,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: on ? c.accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(R.md),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                arabicWeekdayLetters[d.weekday]!,
                                style: T.micro.copyWith(
                                  color: on ? c.onAccent : c.muted,
                                ),
                              ),
                              Text(
                                nums(d.day),
                                style: T.section.copyWith(
                                  color: fg,
                                  height: 1.3,
                                  fontWeight: d == today
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: p.total == 0
                                      ? Colors.transparent
                                      : (on
                                            ? c.onAccent
                                            : (p.ratio >= .999
                                                  ? c.good
                                                  : c.lineStrong)),
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
    );
  }
}

class _Fabs extends StatelessWidget {
  const _Fabs({required this.onAdd, required this.onRearrange});
  final VoidCallback onAdd;
  final VoidCallback? onRearrange;

  Widget _circle(
    BuildContext context, {
    required String label,
    required IconData icon,
    required double size,
    required bool primary,
    required VoidCallback onTap,
  }) {
    final c = context.c;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: shadowFloat,
          ),
          child: Material(
            color: primary ? c.accent : c.card,
            shape: CircleBorder(
              side: primary ? BorderSide.none : BorderSide(color: c.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Icon(
                icon,
                color: primary ? c.onAccent : c.accent,
                size: size * .46,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (onRearrange != null) ...[
        _circle(
          context,
          label: 'رتّب يومي',
          icon: Icons.auto_fix_high,
          size: 42,
          primary: false,
          onTap: onRearrange!,
        ),
        const SizedBox(height: 12),
      ],
      _circle(
        context,
        label: 'إضافة',
        icon: Icons.add,
        size: 52,
        primary: true,
        onTap: onAdd,
      ),
    ],
  );
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
            title: 'أمس فيه ${nums(missed)} ما سجلتها',
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
    if (banners.isEmpty) return const SizedBox.shrink();
    return Column(children: banners);
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
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: c.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.cardTitle.copyWith(fontSize: 14),
                ),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: T.meta.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
          if (action != null) SmallButton(label: action!, onTap: onTap),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailing,
    this.icon,
    this.onTap,
  });
  final String title;
  final String? trailing;
  final IconData? icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(R.sm),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 12, 0, 4),
        child: Row(
          children: [
            Text(title, style: T.section),
            if (icon != null) Icon(icon, size: 18, color: c.muted),
            const Spacer(),
            if (trailing != null)
              Text(trailing!, style: T.meta.copyWith(color: c.muted)),
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
      padding: const EdgeInsetsDirectional.fromSTEB(4, 10, 0, 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'الآن ${fmtTime(now)}',
              style: T.micro.copyWith(color: c.onAccent),
            ),
          ),
          Expanded(child: Container(height: 1.5, color: c.accent)),
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
      color: c.sunk,
      border: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bedtime_outlined, size: 20, color: c.ink2),
              const SizedBox(width: 10),
              Text('وقت النوم · ${fmtTime(sleep.minute)}', style: T.cardTitle),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            pending.isEmpty
                ? 'سجلت كل شي اليوم. تصبح على خير.'
                : 'قبل تنام: ${nums(pending.length)} ما سجلتها اليوم. اللي يبقى بدون جواب ينحسب «فاتت» بكرة.',
            style: T.meta.copyWith(color: c.ink2, fontSize: 13),
          ),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 10),
            SmallButton(
              label: 'راجع يومك',
              primary: true,
              onTap: () => showReviewSheet(context, ref, plan.date),
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
                  const SheetHeader('راجع يومك'),
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: T.cardTitle,
                                ),
                                Text(
                                  fmtRange(i.start, i.end),
                                  style: T.meta.copyWith(color: c.muted),
                                ),
                              ],
                            ),
                          ),
                          SmallButton(
                            label: 'تمّت',
                            icon: Icons.check,
                            onTap: () => ctrl.markDone(date, i),
                          ),
                          const SizedBox(width: 6),
                          SmallButton(
                            label: 'لا',
                            onTap: () =>
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
