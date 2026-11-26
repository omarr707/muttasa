import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';
import 'item_sheet.dart';

/// ItemCard واحد بمحتوى يتغير حسب النوع. النقر على جسم البطاقة ينفّذ إجراءها الرئيسي،
/// وفي الأيام القادمة يقول متى موعدها فقط.
class ItemCard extends ConsumerWidget {
  const ItemCard({
    super.key,
    required this.item,
    required this.date,
    this.highlight = false,
  });
  final PlanItem item;
  final Day date;
  final bool highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final today = ref.watch(todayProvider);
    final now = ref.watch(nowMinuteProvider);
    final isToday = date == today;
    final isPast = date.isBefore(today);
    final i = item;
    final done = i.isDoneLike;
    final isNow =
        isToday &&
        i.start <= now &&
        now < i.end &&
        i.status == ItemStatus.pending;
    final late =
        isToday &&
        i.end <= now &&
        i.status == ItemStatus.pending &&
        i.track != TrackMode.auto;
    final running = i.log?.timerRunning == true;
    final status = statusLabel(i, isToday: isToday, now: now);

    if (i.kind == ItemKind.work) return _WorkCard(item: i, date: date);

    Color bg = c.card;
    Color border = c.line;
    if (isNow || running) {
      bg = c.nowCard;
      border = c.accent;
    }
    if (highlight) border = c.accent2;
    if (i.status == ItemStatus.preJoin) bg = c.bg;

    final ink =
        done || i.status == ItemStatus.skipped || i.status == ItemStatus.preJoin
        ? c.muted
        : c.ink;
    final subtitleParts = <String>[
      fmtRange(i.start, i.end),
      if (i.subtitle != null && i.subtitle!.isNotEmpty) i.subtitle!,
      if (i.pagesFrom != null && i.kind == ItemKind.quran)
        'وردك: ${i.pagesTo! - i.pagesFrom! + 1} صفحات',
    ];

    Future<void> primary() async {
      final ctrl = ref.read(appDataProvider.notifier);
      if (date.isAfter(today)) {
        toast(context, 'موعدها ${fmtDayLong(date)} ${fmtTime(i.start)}');
        return;
      }
      if (i.status != ItemStatus.pending && i.status != ItemStatus.missed) {
        return showItemSheet(context, ref, i, date);
      }
      if (i.pagesFrom != null) return showPagesSheet(context, ref, i, date);
      switch (i.track) {
        case TrackMode.start:
          if (isPast) return showItemSheet(context, ref, i, date);
          if (running) {
            await ctrl.pauseTimer(date, i);
          } else {
            await ctrl.startTimer(date, i);
          }
        case TrackMode.confirm:
        case TrackMode.autocount:
          await ctrl.markDone(date, i);
          if (context.mounted) {
            toast(
              context,
              'تمت ✓ ${i.title}',
              actionLabel: 'تراجع',
              onAction: () => ctrl.undo(date, i.key),
            );
          }
        case TrackMode.auto:
        case TrackMode.quick:
          return showItemSheet(context, ref, i, date);
      }
    }

    return Semantics(
      label:
          '${i.title}، ${subtitleParts.first}${status.isEmpty ? '' : '، $status'}',
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: border,
            width: (isNow || highlight) ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: primary,
          onLongPress: () => showItemSheet(context, ref, i, date),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 6, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: done
                          ? Icon(Icons.check_circle, color: c.good, size: 24)
                          : Icon(iconFor(i.icon), color: ink, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  i.title,
                                  style: TextStyle(
                                    fontFamily: fontDisplay,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: ink,
                                    decoration: i.status == ItemStatus.skipped
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                              if (i.fixed && i.kind != ItemKind.task) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.lock_outline,
                                  size: 14,
                                  color: c.muted,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitleParts.join(' · '),
                            style: TextStyle(fontSize: 13, color: c.ink2),
                          ),
                          if (status.isNotEmpty ||
                              i.manual ||
                              i.outsideWindow ||
                              i.carriedFrom != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  if (status.isNotEmpty)
                                    _Badge(
                                      status,
                                      color: _statusColor(c, i, late),
                                    ),
                                  if (i.manual) const _Badge('عدّلتها بيدك'),
                                  if (i.outsideWindow)
                                    const _Badge('خارج فترتك المفضلة'),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'خيارات ${i.title}',
                      icon: Icon(Icons.more_horiz, color: c.muted),
                      onPressed: () => showItemSheet(context, ref, i, date),
                    ),
                  ],
                ),
                if (running || (i.log?.timerAccumSeconds ?? 0) > 0 && !done)
                  _TimerRow(item: i, date: date),
                if (i.pagesFrom != null && !done && !date.isAfter(today))
                  _PagesRow(item: i, date: date),
                if (late && !running && i.pagesFrom == null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 36,
                      top: 8,
                      end: 8,
                    ),
                    child: Row(
                      children: [
                        PillButton(
                          label: 'تمت',
                          dense: true,
                          onPressed: () => ref
                              .read(appDataProvider.notifier)
                              .markDone(date, i),
                        ),
                        const SizedBox(width: 8),
                        PillButton(
                          label: 'أجّل',
                          soft: true,
                          dense: true,
                          onPressed: () =>
                              showPostponeSheet(context, ref, i, date),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(MColors c, PlanItem i, bool late) {
    if (i.isDoneLike) return c.good;
    if (late || i.status == ItemStatus.missed) return c.warn;
    if (i.status == ItemStatus.pending) return c.accent2;
    return c.muted;
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, {this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final col = color ?? c.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: col.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          color: col,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// ابدأ / أوقف مؤقتًا / أنهِ.
class _TimerRow extends ConsumerStatefulWidget {
  const _TimerRow({required this.item, required this.date});
  final PlanItem item;
  final Day date;
  @override
  ConsumerState<_TimerRow> createState() => _TimerRowState();
}

class _TimerRowState extends ConsumerState<_TimerRow> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.item.log?.timerRunning == true) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final l = widget.item.log!;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final secs =
        l.timerAccumSeconds +
        (l.timerRunning ? (nowMs - l.timerStartedAt!) ~/ 1000 : 0);
    final target = widget.item.duration * 60;
    final mm = (secs ~/ 60).toString().padLeft(2, '0');
    final ss = (secs % 60).toString().padLeft(2, '0');
    final ctrl = ref.read(appDataProvider.notifier);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 36, top: 10, end: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (secs / target).clamp(0, 1),
              minHeight: 6,
              backgroundColor: c.line,
              color: c.accent2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$mm:$ss',
                style: const TextStyle(
                  fontFamily: fontDisplay,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                ' من ${fmtDuration(widget.item.duration)}',
                style: TextStyle(color: c.muted, fontSize: 12.5),
              ),
              const Spacer(),
              PillButton(
                label: l.timerRunning ? 'أوقف مؤقتًا' : 'كمّل',
                soft: true,
                dense: true,
                onPressed: () => l.timerRunning
                    ? ctrl.pauseTimer(widget.date, widget.item)
                    : ctrl.startTimer(widget.date, widget.item),
              ),
              const SizedBox(width: 6),
              PillButton(
                label: 'أنهِ',
                dense: true,
                onPressed: () => ctrl.finishTimer(widget.date, widget.item),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PagesRow extends ConsumerWidget {
  const _PagesRow({required this.item, required this.date});
  final PlanItem item;
  final Day date;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 36, top: 10, end: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.kid,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'من صفحة ${item.pagesFrom} إلى ${item.pagesTo}${item.book == null ? '' : ' · ${item.book}'}',
              style: TextStyle(fontSize: 13, color: c.ink2),
            ),
          ),
          PillButton(
            label: 'سجّل تقدمي',
            dense: true,
            onPressed: () => showPagesSheet(context, ref, item, date),
          ),
        ],
      ),
    );
  }
}

/// فترة ثابتة (الدوام): حاوية بقفل، والاستراحة داخلها وقت متاح.
class _WorkCard extends ConsumerWidget {
  const _WorkCard({required this.item, required this.date});
  final PlanItem item;
  final Day date;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final b = item.workBreak;
    return MCard(
      color: c.kid,
      onTap: () => showItemSheet(context, ref, item, date),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(iconFor('work'), color: c.ink2),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontFamily: fontDisplay,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.lock_outline, size: 14, color: c.muted),
                      ],
                    ),
                    Text(
                      [
                        fmtRange(item.start, item.end % minutesPerDay),
                        if (item.subtitle == 'ذيل وردية أمس') item.subtitle!,
                      ].join(' · '),
                      style: TextStyle(fontSize: 13, color: c.ink2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (b != null)
            Container(
              margin: const EdgeInsetsDirectional.only(start: 36, top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: c.breakBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.line),
              ),
              child: Row(
                children: [
                  Icon(Icons.coffee_outlined, size: 16, color: c.muted),
                  const SizedBox(width: 8),
                  Text(
                    'الاستراحة ${fmtRange(b.start, b.end)} · وقت متاح',
                    style: TextStyle(fontSize: 12.5, color: c.ink2),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// الخطوط الخفيفة بين البطاقات: الماء «4 من 8»، الوقوف، التنفس.
class ReminderLineTile extends ConsumerWidget {
  const ReminderLineTile({
    super.key,
    required this.line,
    required this.date,
    required this.water,
  });
  final ReminderLine line;
  final Day date;
  final (int, int) water;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final ctrl = ref.read(appDataProvider.notifier);
    final today = ref.watch(todayProvider);
    final canLog = !date.isAfter(today);
    final icon = switch (line.kind) {
      LineKind.water => 'water',
      LineKind.stand => 'stand',
      LineKind.breathe => 'breathe',
      LineKind.sleep => 'sleep',
      LineKind.custom => 'bell',
    };
    Widget? action;
    if (canLog) {
      switch (line.kind) {
        case LineKind.water:
          action = line.done
              ? Text('✓', style: TextStyle(color: c.good))
              : PillButton(
                  label: 'سجّل',
                  soft: true,
                  dense: true,
                  onPressed: () {
                    ctrl.addWater(date, 1);
                    toast(
                      context,
                      'الماء: ${water.$1 + 1} من ${water.$2}',
                      actionLabel: 'تراجع',
                      onAction: () => ctrl.addWater(date, -1),
                    );
                  },
                );
        case LineKind.breathe:
        case LineKind.custom:
          action = line.done
              ? Text('✓', style: TextStyle(color: c.good))
              : PillButton(
                  label: line.kind == LineKind.breathe ? 'ابدأ' : 'تم',
                  soft: true,
                  dense: true,
                  onPressed: () => ctrl.toggleLine(date, line.key, true),
                );
        case LineKind.stand:
        case LineKind.sleep:
          action = null;
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(iconFor(icon), size: 18, color: line.done ? c.good : c.accent2),
          const SizedBox(width: 8),
          Text(
            fmtTime(line.minute),
            style: TextStyle(
              fontSize: 12.5,
              color: c.muted,
              fontFamily: fontDisplay,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              line.kind == LineKind.water
                  ? '${line.title} · ${water.$1} من ${water.$2}'
                  : line.title,
              style: TextStyle(
                fontSize: 13,
                color: line.done ? c.muted : c.ink2,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
