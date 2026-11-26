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
    final isFuture = date.isAfter(today);
    final i = item;
    final done = i.isDoneLike;
    final pending = i.status == ItemStatus.pending;
    final isNow = isToday && i.start <= now && now < i.end && pending;
    final late =
        (isToday && i.end <= now && pending && i.track != TrackMode.auto) ||
        i.status == ItemStatus.missed;
    final upcoming = isFuture || (isToday && i.start > now && pending);
    final running = i.log?.timerRunning == true;
    final off =
        i.status == ItemStatus.skipped ||
        i.status == ItemStatus.postponed ||
        i.status == ItemStatus.notDone ||
        i.status == ItemStatus.preJoin;

    if (i.kind == ItemKind.work) return _WorkCard(item: i, date: date);

    // ألوان الحالة كما في النموذج.
    var bg = c.bg;
    var border = c.line;
    var borderW = 1.0;
    if (done) {
      bg = c.doneBg;
      border = Colors.transparent;
    } else if (isNow || running) {
      bg = c.nowCard;
      border = c.accent2;
      borderW = 2;
    } else if (late) {
      bg = c.amberBg;
      border = c.amberLine;
    }
    if (highlight) {
      border = c.accent2;
      borderW = 2;
    }
    final ink = done ? c.doneInk : (off ? c.ink2 : c.ink);

    final sub = <String>[
      fmtRange(i.start, i.end),
      if (i.subtitle != null && i.subtitle!.isNotEmpty) i.subtitle!,
      if (i.pagesFrom != null && i.kind == ItemKind.quran)
        'وردك: ${i.pagesTo! - i.pagesFrom! + 1} صفحات',
    ].join(' · ');

    Future<void> confirm() async {
      final ctrl = ref.read(appDataProvider.notifier);
      if (done) {
        await ctrl.undo(date, i.key);
        return;
      }
      if (i.pagesFrom != null) return showPagesSheet(context, ref, i, date);
      if (i.track == TrackMode.start && !late && isToday) {
        return running ? ctrl.pauseTimer(date, i) : ctrl.startTimer(date, i);
      }
      await ctrl.markDone(date, i);
      if (context.mounted) {
        toast(
          context,
          'تمت ✓ ${i.title}',
          actionLabel: 'تراجع',
          onAction: () => ctrl.undo(date, i.key),
        );
      }
    }

    final canCheck =
        !isFuture &&
        !off &&
        i.track != TrackMode.auto &&
        (done || !upcoming || !i.fixed);

    // الجانب: حالة مختصرة ثم الأزرار.
    final side = <Widget>[];
    if (done) {
      side.add(
        Text(
          i.status == ItemStatus.auto ? 'محسوبة' : 'تمت',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: c.doneInk,
          ),
        ),
      );
    } else if (late) {
      side.add(const _Chip('فات وقتها', icon: Icons.schedule, amber: true));
    } else if (off || i.status == ItemStatus.auto) {
      side.add(_Chip(statusLabel(i, isToday: isToday, now: now)));
    } else if (i.track == TrackMode.auto && !isFuture) {
      side.add(const _Chip('تُحسب تلقائيًا'));
    }
    if (!done && !off && !(i.fixed && upcoming)) {
      side.add(
        _IconBtn(
          icon: Icons.more_horiz,
          tooltip: 'خيارات ${i.title}',
          onTap: () => showItemSheet(context, ref, i, date),
        ),
      );
    }
    if (i.fixed && upcoming && !done) {
      side.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Icon(Icons.lock_outline, size: 16, color: c.muted),
        ),
      );
    }
    if (canCheck) {
      side.add(
        CheckBox(
          checked: done,
          icon: i.track == TrackMode.start && !done && !late
              ? (running ? Icons.pause : Icons.play_arrow)
              : null,
          label: done ? 'ألغِ إنجاز ${i.title}' : 'تمت ${i.title}',
          onTap: confirm,
        ),
      );
    }

    final tags = <Widget>[
      if (isNow) const _Tag('الآن', now: true),
      if (i.carriedFrom != null) const _Tag('منقولة', hl: true),
      if (i.manual && !done) const _Tag('عدّلتها', hl: true),
      if (i.outsideWindow && !done) const _Tag('خارج فترتك'),
      if (i.isExtra) const _Tag('إضافية'),
    ];

    final showSubs = i.subs.isNotEmpty;

    return Semantics(
      label: '${i.title}، ${fmtRange(i.start, i.end)}',
      child: Opacity(
        opacity: off ? .78 : 1,
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: border, width: borderW),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showItemSheet(context, ref, i, date),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 8, 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Icon(iconFor(i.icon), size: 22, color: ink),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 5,
                              runSpacing: 2,
                              children: [
                                Text(
                                  i.title,
                                  style: TextStyle(
                                    fontFamily: fontDisplay,
                                    fontWeight: done
                                        ? FontWeight.w600
                                        : FontWeight.w700,
                                    fontSize: 16,
                                    height: 1.3,
                                    color: ink,
                                    decoration: i.status == ItemStatus.skipped
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                ...tags,
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              sub,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: c.ink2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      ...side,
                    ],
                  ),
                ),
                if (running || (i.log?.timerAccumSeconds ?? 0) > 0 && !done)
                  _TimerRow(item: i, date: date),
                if (i.pagesFrom != null && !done && !isFuture && !off)
                  _PagesRow(item: i, date: date),
                if (showSubs) _Subs(item: i, date: date, enabled: !isFuture),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// مربع التأكيد كما في النموذج: إطار، ويمتلئ عند الإنجاز.
class CheckBox extends StatelessWidget {
  const CheckBox({
    super.key,
    required this.checked,
    required this.onTap,
    required this.label,
    this.icon,
    this.small = false,
  });
  final bool checked;
  final VoidCallback? onTap;
  final String label;
  final IconData? icon;
  final bool small;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      checked: checked,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: small ? 34 : 38,
            height: small ? 26 : 30,
            decoration: BoxDecoration(
              color: checked ? c.doneInk : Colors.transparent,
              borderRadius: BorderRadius.circular(small ? 10 : 12),
              border: Border.all(
                color: checked ? c.doneInk : c.muted,
                width: 2,
              ),
            ),
            child: checked
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : (icon == null ? null : Icon(icon, size: 18, color: c.ink2)),
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.tooltip, this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: SizedBox(
        width: 30,
        height: 36,
        child: Icon(icon, size: 20, color: context.c.muted),
      ),
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.now = false, this.hl = false});
  final String text;
  final bool now;
  final bool hl;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: now ? c.accent2 : c.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: now ? c.accent2 : (hl ? c.accent : c.line)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          height: 1.7,
          fontWeight: FontWeight.w600,
          color: now ? Colors.white : (hl ? c.accent2 : c.muted),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.icon, this.amber = false});
  final String text;
  final IconData? icon;
  final bool amber;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = amber ? c.amber : c.ink2;
    return Container(
      margin: const EdgeInsetsDirectional.only(end: 2),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: amber ? c.bg : c.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: amber ? c.amberLine : c.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// البنود الفرعية داخل البطاقة (السنن الرواتب).
class _Subs extends ConsumerWidget {
  const _Subs({required this.item, required this.date, required this.enabled});
  final PlanItem item;
  final Day date;
  final bool enabled;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final ctrl = ref.read(appDataProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Column(
        children: [
          for (final s in item.subs)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 6, 6),
              decoration: BoxDecoration(
                color: s.done ? c.doneBg : c.kid,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.subdirectory_arrow_left, size: 16, color: c.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: TextStyle(
                            fontFamily: fontDisplay,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: s.done ? c.doneInk : c.ink,
                          ),
                        ),
                        Text(
                          s.detail,
                          style: TextStyle(fontSize: 11.5, color: c.ink2),
                        ),
                      ],
                    ),
                  ),
                  if (enabled)
                    CheckBox(
                      small: true,
                      checked: s.done,
                      label: s.done ? 'ألغِ ${s.title}' : 'تمت ${s.title}',
                      onTap: () => ctrl.toggleLine(date, s.key, !s.done),
                    ),
                ],
              ),
            ),
        ],
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
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

/// فترة ثابتة (الدوام): شريط الفترات مع الاستراحة وموضع الآن، كما في النموذج.
class _WorkCard extends ConsumerWidget {
  const _WorkCard({required this.item, required this.date});
  final PlanItem item;
  final Day date;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final b = item.workBreak;
    final today = ref.watch(todayProvider);
    final now = ref.watch(nowMinuteProvider);
    final s = item.start, e = item.end;
    final total = (e - s).clamp(1, 24 * 60);
    final inside = date == today && now >= s && now < e;
    Widget seg(int from, int to, {bool gap = false}) => Expanded(
      flex: (to - from).clamp(1, 24 * 60),
      child: Container(color: gap ? c.breakBg : c.accent),
    );
    return Material(
      color: inside ? c.nowCard : c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: inside ? c.accent2 : c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showItemSheet(context, ref, item, date),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(10, 11, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Icon(iconFor('work'), size: 22, color: c.ink),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontFamily: fontDisplay,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            height: 1.3,
                          ),
                        ),
                        Text(
                          [
                            fmtRange(s, e % minutesPerDay),
                            if (item.subtitle == 'ذيل وردية أمس')
                              item.subtitle!,
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: c.ink2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.lock_outline, size: 16, color: c.muted),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, cons) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          border: Border.all(color: c.line, width: .5),
                        ),
                        child: Row(
                          children: b == null
                              ? [seg(s, e)]
                              : [
                                  seg(s, b.start),
                                  seg(b.start, b.end, gap: true),
                                  seg(b.end, e),
                                ],
                        ),
                      ),
                    ),
                    if (inside)
                      PositionedDirectional(
                        start: cons.maxWidth * (now - s) / total - 1.5,
                        top: -3,
                        child: Container(
                          width: 3,
                          height: 14,
                          decoration: BoxDecoration(
                            color: c.accent2,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (b != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.coffee_outlined, size: 15, color: c.accent2),
                    const SizedBox(width: 6),
                    Text(
                      'الاستراحة ${fmtRange(b.start, b.end)} · وقت متاح',
                      style: TextStyle(
                        fontSize: 12,
                        color: c.accent2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
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
              : _MiniPill(
                  label: 'سجّل',
                  onTap: () {
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
              : _MiniPill(
                  label: line.kind == LineKind.breathe ? 'ابدأ' : 'تم',
                  onTap: () => ctrl.toggleLine(date, line.key, true),
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

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: c.line),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: fontDisplay,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
