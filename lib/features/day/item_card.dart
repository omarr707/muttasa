import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../services/contact_actions.dart';
import '../../state/providers.dart';
import '../goals/amount_sheet.dart';
import 'item_sheet.dart';
import 'water_sheet.dart';

/// بطاقة المهمة من دليل التصميم: مربع أيقونة، عنوان بسطر، وصف بسطر، وإجراء واحد.
/// النقر أو الضغط المطوّل يفتح الخيارات.
class ItemCard extends ConsumerWidget {
  const ItemCard({
    super.key,
    required this.item,
    required this.date,
    this.highlight = false,
    this.missedDot = false,
  });
  final PlanItem item;
  final Day date;
  final bool highlight;

  /// نقطة كهرمانية في سطر الوصف (داخل ورقة «فاتت» فقط).
  final bool missedDot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final today = ref.watch(todayProvider);
    final now = ref.watch(nowMinuteProvider);
    final compact = ref.watch(
      appDataProvider.select((d) => d.settings.compact),
    );
    final isToday = date == today;
    final isFuture = date.isAfter(today);
    final i = item;
    final done = i.isDoneLike;
    final pending = i.status == ItemStatus.pending;
    final isNow = isToday && i.start <= now && now < i.end && pending;
    final upcoming = isFuture || (isToday && i.start > now && pending);
    final running = i.log?.timerRunning == true;
    final off =
        i.status == ItemStatus.skipped ||
        i.status == ItemStatus.postponed ||
        i.status == ItemStatus.notDone ||
        i.status == ItemStatus.preJoin;

    if (i.kind == ItemKind.work) return _WorkCard(item: i, date: date);

    final ctrl = ref.read(appDataProvider.notifier);
    Future<void> confirm() async {
      if (done) {
        await ctrl.undo(date, i.key);
        return;
      }
      if (i.pagesFrom != null) return showPagesSheet(context, ref, i, date);
      if (i.track == TrackMode.start && isToday && !(i.end <= now)) {
        return running ? ctrl.pauseTimer(date, i) : ctrl.startTimer(date, i);
      }
      await ctrl.markDone(date, i);
      if (context.mounted) {
        toast(
          context,
          'تمّت ✓ ${i.title}',
          actionLabel: 'تراجع',
          onAction: () => ctrl.undo(date, i.key),
        );
      }
    }

    final meta = <String>[
      fmtRange(i.start, i.end % minutesPerDay),
      if (off) statusLabel(i, isToday: isToday, now: now),
      if (!off && i.subtitle != null && i.subtitle!.isNotEmpty && !_isDraft(i))
        nums(i.subtitle),
      if (i.pagesFrom != null && i.kind == ItemKind.quran)
        'وردك ${nums(i.pagesTo! - i.pagesFrom! + 1)} صفحات',
      if (i.track == TrackMode.auto && i.counted && !done && !off && !isFuture)
        'تُحسب تلقائيًا',
      if (i.partner) 'للعلم',
    ].join(' · ');

    // الإجراء الواحد.
    Widget? action;
    final canCheck =
        !isFuture &&
        !off &&
        i.track != TrackMode.auto &&
        (done || !upcoming || !i.fixed);
    final contact =
        i.kind == ItemKind.contact && i.icon != 'gift' && i.icon != 'visit';
    if (contact && !done && !isFuture && !off) {
      final person = ref
          .watch(appDataProvider.select((d) => d.people))
          .where((p) => p.id == i.personId)
          .firstOrNull;
      final call = i.icon == 'call';
      action = SmallButton(
        label: call ? 'اتصل' : 'أرسل',
        primary: true,
        onTap: () async {
          final ok =
              person != null &&
              await openContact(
                person,
                call: call,
                draft: call ? null : i.subtitle,
              );
          if (!context.mounted) return;
          if (!ok) {
            toast(context, 'أضف رقم ${person?.name ?? 'الشخص'} من الإعدادات');
            return;
          }
          toast(
            context,
            call ? 'إذا خلّصت المكالمة سجّلها' : 'المسودة جاهزة، أرسلها بنفسك',
            actionLabel: 'تمّ',
            onAction: () => ctrl.markDone(date, i),
          );
        },
      );
    } else if (i.kind == ItemKind.savings && !done && !isFuture && !off) {
      action = SmallButton(
        label: 'تم الادخار',
        primary: true,
        onTap: () => logSavingFromCard(context, ref, i, date),
      );
    } else if (canCheck) {
      action = CheckCircle(
        checked: done,
        icon: i.track == TrackMode.start && !done && isToday && i.end > now
            ? (running ? Icons.pause : Icons.play_arrow)
            : null,
        label: done ? 'ألغِ إنجاز ${i.title}' : 'تمّت ${i.title}',
        onTap: confirm,
      );
    } else if (i.fixed && upcoming && !done) {
      action = Padding(
        padding: const EdgeInsets.all(7),
        child: Icon(Icons.lock_outline, size: 16, color: c.muted),
      );
    }

    final iconBg = switch (i.icon) {
      'gift' => c.amberSoft,
      _ => done ? c.card : c.sunk,
    };
    final iconFg = switch (i.icon) {
      'gift' => c.amber,
      _ => done ? c.muted : c.ink2,
    };

    var border = c.line;
    var borderW = 1.0;
    if ((isNow || running) && !done) {
      border = c.accent;
      borderW = 2;
    }
    if (highlight) {
      border = c.accent;
      borderW = 2;
    }

    final draftLine = _isDraft(i) && !done && !isFuture;

    return Semantics(
      label: '${i.title}، ${fmtRange(i.start, i.end % minutesPerDay)}',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: off || i.partner ? .7 : 1,
        child: Material(
          color: done ? c.sunk : c.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(R.md),
            side: BorderSide(
              color: done ? Colors.transparent : border,
              width: borderW,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showItemSheet(context, ref, i, date),
            onLongPress: () => showItemSheet(context, ref, i, date),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: compact ? 48 : 58),
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      compact ? 8 : 10,
                      compact ? 6 : 10,
                      8,
                      compact ? 6 : 10,
                    ),
                    child: Row(
                      children: [
                        IconSquare(
                          iconFor(i.icon),
                          bg: iconBg,
                          fg: iconFg,
                          size: compact ? 30 : 34,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                i.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: T.cardTitle.copyWith(
                                  color: done || off ? c.muted : c.ink,
                                  decoration: i.status == ItemStatus.skipped
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              Row(
                                children: [
                                  if (missedDot) ...[
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: c.amber,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(
                                    child: Text(
                                      meta,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: T.meta.copyWith(color: c.muted),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (action != null) ...[
                          const SizedBox(width: 6),
                          action,
                        ],
                      ],
                    ),
                  ),
                ),
                if (draftLine) _DraftLine(text: i.subtitle!),
                if (running || (i.log?.timerAccumSeconds ?? 0) > 0 && !done)
                  _TimerRow(item: i, date: date),
                if (i.pagesFrom != null && !done && !isFuture && !off)
                  _PagesRow(item: i, date: date),
                if (i.subs.isNotEmpty)
                  _Subs(item: i, date: date, enabled: !isFuture),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static bool _isDraft(PlanItem i) =>
      i.kind == ItemKind.contact && i.icon == 'message';
}

/// دائرة التأكيد ٣٠: إطار، وتمتلئ بالأخضر عند الإنجاز.
class CheckCircle extends StatelessWidget {
  const CheckCircle({
    super.key,
    required this.checked,
    required this.onTap,
    required this.label,
    this.icon,
    this.size = 30,
  });
  final bool checked;
  final VoidCallback? onTap;
  final String label;
  final IconData? icon;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      checked: checked,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: checked ? c.good : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: checked ? c.good : c.lineStrong,
                width: 1.5,
              ),
            ),
            child: checked
                ? Icon(Icons.check, size: size * .55, color: c.card)
                : (icon == null
                      ? null
                      : Icon(icon, size: size * .55, color: c.accent)),
          ),
        ),
      ),
    );
  }
}

/// سطر المسودة داخل بطاقة الرسالة.
class _DraftLine extends StatelessWidget {
  const _DraftLine({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.sunk,
        borderRadius: BorderRadius.circular(R.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '«$text»',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: T.meta.copyWith(color: c.ink2, fontSize: 13),
          ),
          Text(
            'مسودة لا تُرسل إلا منك',
            style: T.micro.copyWith(color: c.muted),
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
      padding: const EdgeInsetsDirectional.fromSTEB(54, 0, 8, 8),
      child: Column(
        children: [
          for (final s in item.subs)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 0, 0),
              decoration: BoxDecoration(
                color: c.sunk,
                borderRadius: BorderRadius.circular(R.sm),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: s.title,
                            style: T.label.copyWith(
                              fontSize: 13,
                              color: s.done ? c.muted : c.ink,
                            ),
                          ),
                          TextSpan(
                            text: '  ${nums(s.detail)}',
                            style: T.micro.copyWith(color: c.muted),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (enabled)
                    CheckCircle(
                      size: 22,
                      checked: s.done,
                      label: s.done ? 'ألغِ ${s.title}' : 'تمّت ${s.title}',
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
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (secs / target).clamp(0, 1),
              minHeight: 4,
              backgroundColor: c.sunk,
              color: c.accent,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                nums('$mm:$ss'),
                style: T.section.copyWith(fontWeight: FontWeight.w500),
              ),
              Text(
                ' من ${fmtDuration(widget.item.duration)}',
                style: T.meta.copyWith(color: c.muted),
              ),
              const Spacer(),
              SmallButton(
                label: l.timerRunning ? 'أوقف مؤقتًا' : 'كمّل',
                onTap: () => l.timerRunning
                    ? ctrl.pauseTimer(widget.date, widget.item)
                    : ctrl.startTimer(widget.date, widget.item),
              ),
              const SizedBox(width: 6),
              SmallButton(
                label: 'أنهِ',
                primary: true,
                onTap: () => ctrl.finishTimer(widget.date, widget.item),
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
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(54, 0, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              nums(
                'من صفحة ${item.pagesFrom} إلى ${item.pagesTo}${item.book == null ? '' : ' · ${item.book}'}',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: T.meta.copyWith(color: c.ink2),
            ),
          ),
          SmallButton(
            label: 'سجّل تقدمي',
            onTap: () => showPagesSheet(context, ref, item, date),
          ),
        ],
      ),
    );
  }
}

/// فترة ثابتة (الدوام): شريط الفترات مع الاستراحة وموضع الآن.
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
      child: Container(color: gap ? c.sunk : c.accent.withValues(alpha: .55)),
    );
    return Material(
      color: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(R.md),
        side: BorderSide(
          color: inside ? c.accent : c.line,
          width: inside ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showItemSheet(context, ref, item, date),
        onLongPress: () => showItemSheet(context, ref, item, date),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconSquare(iconFor('work')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: T.cardTitle,
                        ),
                        Text(
                          [
                            fmtRange(s, e % minutesPerDay),
                            if (item.subtitle == 'ذيل وردية أمس')
                              item.subtitle!,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: T.meta.copyWith(color: c.muted),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(7),
                    child: Icon(Icons.lock_outline, size: 16, color: c.muted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, cons) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 6,
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
                        top: -4,
                        child: Container(
                          width: 3,
                          height: 14,
                          decoration: BoxDecoration(
                            color: c.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (b != null) ...[
                const SizedBox(height: 6),
                Text(
                  'الاستراحة ${fmtRange(b.start, b.end)} · وقت متاح',
                  style: T.micro.copyWith(color: c.accent),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// الخطوط الخفيفة بين البطاقات: بلا أزرار. خط الماء يفتح ورقة الماء.
class ReminderLineTile extends ConsumerWidget {
  const ReminderLineTile({super.key, required this.line, required this.date});
  final ReminderLine line;
  final Day date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final today = ref.watch(todayProvider);
    final icon = switch (line.kind) {
      LineKind.water => 'water',
      LineKind.stand => 'stand',
      LineKind.breathe => 'breathe',
      LineKind.sleep => 'sleep',
      LineKind.custom => 'bell',
    };
    final color = line.kind == LineKind.water ? c.water : c.muted;
    VoidCallback? onTap;
    if (!date.isAfter(today)) {
      if (line.kind == LineKind.water) {
        onTap = () => showWaterSheet(context, ref, date);
      } else if (line.kind == LineKind.breathe ||
          line.kind == LineKind.custom) {
        onTap = () => ref
            .read(appDataProvider.notifier)
            .toggleLine(date, line.key, !line.done);
      }
    }
    return Semantics(
      button: onTap != null,
      label: '${line.title} ${fmtTime(line.minute)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(R.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                line.done ? Icons.check : iconFor(icon),
                size: 14,
                color: line.done ? c.good : color,
              ),
              const SizedBox(width: 6),
              Text(
                '${fmtTime(line.minute)} · ${line.title}',
                style: T.micro.copyWith(
                  color: line.done ? c.muted : c.ink2,
                  fontWeight: FontWeight.w400,
                  decoration: line.done ? TextDecoration.lineThrough : null,
                  decorationColor: c.muted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _Dashes(color: c.line)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dashes extends StatelessWidget {
  const _Dashes({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, cons) {
      final n = (cons.maxWidth / 6).floor();
      return Row(
        children: [
          for (var i = 0; i < n; i++)
            Container(
              width: 3,
              height: 1,
              margin: const EdgeInsetsDirectional.only(end: 3),
              color: color,
            ),
        ],
      );
    },
  );
}

/// «تم الادخار»: يسأل المبلغ ثم يسجّله على بطاقة يوم الراتب.
Future<void> logSavingFromCard(
  BuildContext context,
  WidgetRef ref,
  PlanItem i,
  Day date,
) async {
  final engine = ref.read(engineProvider);
  final cfg = engine
      .rulesOn(date)
      .map((r) => r.config)
      .whereType<SavingsConfig>()
      .firstOrNull;
  final currency = ref.read(appDataProvider).profile?.currency ?? 'ريال';
  final amount = await showAmountSheet(
    context,
    planned: cfg?.monthly ?? 500,
    currency: currency,
  );
  if (amount == null) return;
  final ctrl = ref.read(appDataProvider.notifier);
  await ctrl.markDone(date, i, value: amount);
  if (context.mounted) {
    toast(
      context,
      nums('سجّلنا ${fmtThousands(amount)} $currency ✓'),
      actionLabel: 'تراجع',
      onAction: () => ctrl.undo(date, i.key),
    );
  }
}
