import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';

class _Action {
  const _Action(this.icon, this.label, this.run, {this.danger = false});
  final IconData icon;
  final String label;
  final Future<void> Function() run;
  final bool danger;
}

/// خيارات البطاقة: تمت، تمت لاحقًا، لم أنفّذها، تخطَّ، أجّل، انقل، تراجع.
/// كل إجراء سريع يغلق النافذة فورًا.
Future<void> showItemSheet(
  BuildContext context,
  WidgetRef ref,
  PlanItem item,
  Day date,
) {
  final ctrl = ref.read(appDataProvider.notifier);
  final today = ref.read(todayProvider);
  final isFuture = date.isAfter(today);
  final actions = <_Action>[];
  final i = item;

  if (i.kind == ItemKind.work) {
    final off = ref.read(dayPlanProvider(date)).workOff;
    actions.add(
      _Action(
        Icons.beach_access_outlined,
        off ? 'ألغِ إجازة اليوم' : 'إجازة من الدوام هذا اليوم',
        () => ctrl.setWorkOff(date, !off),
      ),
    );
  } else if (i.status == ItemStatus.pending || i.status == ItemStatus.missed) {
    final share = ref.read(appDataProvider).partner;
    if (i.kind == ItemKind.kid && share.active) {
      actions.add(
        _Action(
          Icons.swap_horiz,
          i.partner ? 'أنا أسويه هذا اليوم' : 'على ${share.name} هذا اليوم',
          () => ctrl.swapRun(date, i),
        ),
      );
    }
    if (!isFuture && i.track != TrackMode.auto) {
      actions.add(
        _Action(
          Icons.check_circle_outline,
          'تمت',
          () => ctrl.markDone(date, i),
        ),
      );
      actions.add(
        _Action(Icons.history, 'تمت في وقت آخر', () async {
          final at = await pickTime(
            context,
            initial: i.start,
            title: 'متى نفّذتها؟',
          );
          if (at != null) await ctrl.markDone(date, i, at: at);
        }),
      );
      if (i.track == TrackMode.start && date == today) {
        actions.add(
          _Action(
            Icons.play_arrow_rounded,
            'ابدأ المؤقت',
            () => ctrl.startTimer(date, i),
          ),
        );
      }
      actions.add(
        _Action(
          Icons.do_not_disturb_on_outlined,
          'لم أنفّذها',
          () => ctrl.setStatus(date, i, ItemStatus.notDone),
        ),
      );
    }
    if (!i.fixed || i.oneOffId != null) {
      actions.add(
        _Action(
          Icons.schedule_send_outlined,
          'أجّل',
          () => showPostponeSheet(context, ref, i, date),
        ),
      );
      actions.add(
        _Action(
          Icons.open_with,
          'انقل إلى وقت آخر',
          () => moveItemFlow(context, ref, i, date),
        ),
      );
    }
    if (i.fixed && i.oneOffId == null) {
      actions.add(
        _Action(
          Icons.event_busy_outlined,
          'ليس هذا اليوم',
          () => ctrl.skipFixedToday(date, i),
        ),
      );
    } else if (i.track != TrackMode.auto) {
      actions.add(
        _Action(
          Icons.remove_circle_outline,
          'تخطَّ هذه المرة',
          () => ctrl.setStatus(date, i, ItemStatus.skipped),
        ),
      );
    }
    if (i.manual) {
      actions.add(
        _Action(
          Icons.restore,
          'رجّعها لوقتها الأصلي',
          () => ctrl.clearOverride(date, i.key),
        ),
      );
    }
    if (i.oneOffId != null) {
      actions.add(
        _Action(
          Icons.delete_outline,
          'احذفها',
          () => ctrl.deleteOneOff(i.oneOffId!),
          danger: true,
        ),
      );
    }
  } else {
    actions.add(
      _Action(
        Icons.undo,
        'تراجع عن «${statusLabel(i, isToday: false, now: 0)}»',
        () => ctrl.undo(date, i.key),
      ),
    );
  }

  return showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final c = ctx.c;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(iconFor(i.icon), color: c.ink),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      i.title,
                      style: const TextStyle(
                        fontFamily: fontDisplay,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: 34,
                  top: 2,
                  bottom: 8,
                ),
                child: Text(
                  '${fmtDayLong(date)} · ${fmtRangeLong(i.start, i.end % minutesPerDay)}'
                  '${i.doneAt != null ? ' · نفّذتها ${fmtTime(i.doneAt!)}' : ''}',
                  style: TextStyle(color: c.ink2, fontSize: 12.5),
                ),
              ),
              if (!i.counted && i.kind != ItemKind.work)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 34,
                    bottom: 8,
                  ),
                  child: Text(
                    'خارج نسبة الإنجاز',
                    style: TextStyle(color: c.muted, fontSize: 12),
                  ),
                ),
              for (final a in actions)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Icon(
                    a.icon,
                    color: a.danger ? Colors.red.shade400 : c.ink,
                  ),
                  title: Text(
                    a.label,
                    style: TextStyle(
                      color: a.danger ? Colors.red.shade400 : c.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    a.run();
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// التأجيل: بعد ساعة، أو بكرة، أو موعده القادم حسب التكرار، أو «اختر موعدًا».
Future<void> showPostponeSheet(
  BuildContext context,
  WidgetRef ref,
  PlanItem i,
  Day date,
) {
  final ctrl = ref.read(appDataProvider.notifier);
  final today = ref.read(todayProvider);
  final now = ref.read(nowMinuteProvider);
  final plan = ref.read(dayPlanProvider(date));
  final hourSlot = date == today ? postponeHourSlot(plan, i, now) : null;
  final recurring =
      i.ruleKey != null && i.oneOffId == null && i.carriedFrom == null;
  return showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'أجّل «${i.title}»',
              style: const TextStyle(
                fontFamily: fontDisplay,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            if (date == today)
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('بعد ساعة'),
                subtitle: Text(
                  hourSlot == null
                      ? 'ما فيه فراغ بعد ساعة اليوم'
                      : 'أول فراغ: ${fmtTime(hourSlot)}',
                ),
                enabled: hourSlot != null,
                onTap: () {
                  Navigator.pop(ctx);
                  ctrl.postponeHour(date, i, hourSlot!);
                  toast(
                    context,
                    'انتقلت إلى ${fmtTime(hourSlot)}',
                    actionLabel: 'تراجع',
                    onAction: () => ctrl.clearOverride(date, i.key),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.wb_twilight),
              title: const Text('بكرة'),
              subtitle: Text(
                ref.read(dayPlanProvider(date.next)).hasKey(i.key)
                    ? 'موجودة بكرة أصلًا، فلن تتكرر'
                    : 'تنضاف لجدول بكرة',
              ),
              onTap: () {
                Navigator.pop(ctx);
                ctrl.postponeTo(date, i, date.next);
                toast(
                  context,
                  'تأجلت لبكرة',
                  actionLabel: 'تراجع',
                  onAction: () => ctrl.undo(date, i.key),
                );
              },
            ),
            if (recurring)
              ListTile(
                leading: const Icon(Icons.repeat),
                title: const Text('موعدها القادم'),
                subtitle: const Text('حسب التكرار، بدون إضافة'),
                onTap: () {
                  Navigator.pop(ctx);
                  ctrl.postponeNext(date, i);
                },
              ),
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('اختر موعدًا'),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await pickDay(context, from: date);
                if (picked == null || !context.mounted) return;
                final t = await pickTime(
                  context,
                  initial: i.start,
                  title: 'الوقت',
                );
                if (t == null) return;
                await ctrl.postponeTo(date, i, picked, start: t);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// اختيار يوم من الأسبوعين القادمين.
Future<Day?> pickDay(
  BuildContext context, {
  required Day from,
  int days = 14,
}) => showModalBottomSheet<Day>(
  useRootNavigator: true,
  context: context,
  builder: (ctx) {
    final c = ctx.c;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختر اليوم',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var k = 0; k < days; k++)
                  ActionChip(
                    backgroundColor: c.card,
                    label: Text(
                      k == 0
                          ? 'اليوم'
                          : (k == 1
                                ? 'بكرة'
                                : nums(
                                    '${arabicWeekdays[from.add(k).weekday]} ${from.add(k).day}/${from.add(k).month}',
                                  )),
                    ),
                    onPressed: () => Navigator.pop(ctx, from.add(k)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  },
);

/// النقل: المدة ثابتة. ConflictChecker يرد بالسبب مع أقرب وقت فاضٍ.
/// المتكرر: بعد النقل نسأل «هذه المرة فقط» أو «من اليوم فصاعدًا».
Future<void> moveItemFlow(
  BuildContext context,
  WidgetRef ref,
  PlanItem i,
  Day date,
) async {
  final t = await pickTime(
    context,
    initial: i.start,
    title: 'انقل «${i.title}» إلى',
  );
  if (t == null || !context.mounted) return;
  await moveItemTo(context, ref, i, date, t);
}

/// ينقل العنصر إلى [target]: يفحص الثابت، ويسأل «نزحزح اللي بعده؟»،
/// ثم «هذه المرة فقط» أو «من اليوم فصاعدًا» للمتكرر.
Future<void> moveItemTo(
  BuildContext context,
  WidgetRef ref,
  PlanItem i,
  Day date,
  int target,
) async {
  final ctrl = ref.read(appDataProvider.notifier);
  int? t = target;
  final plan = ref.read(dayPlanProvider(date));
  final soft = {
    for (final x in plan.items)
      if (isMovable(x)) x.key,
  };
  final check = checkMove(plan, i, t, soft: soft);
  if (!check.ok) {
    final accept = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('هذا الوقت ما يناسب'),
        content: Text(
          '${check.reason}.${check.suggestion == null ? '' : '\nأقرب وقت فاضٍ: ${fmtTime(check.suggestion!)}'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          if (check.suggestion != null)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('انقلها إلى ${fmtTime(check.suggestion!)}'),
            ),
        ],
      ),
    );
    if (accept != true) return;
    t = check.suggestion!;
  }
  if (!context.mounted) return;
  final reflow = await askReflow(context, plan, i, t);
  if (reflow == null || !context.mounted) return;
  if (reflow.isNotEmpty) await ctrl.applyRearrange(date, reflow);
  if (!context.mounted) return;
  final recurring =
      i.ruleKey != null &&
      i.oneOffId == null &&
      i.carriedFrom == null &&
      !i.fixed;
  if (!recurring) {
    await ctrl.moveOnce(date, i, t);
    return;
  }
  final scope = await showModalBottomSheet<String>(
    useRootNavigator: true,
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'نقل «${i.title}» إلى ${fmtTime(t!)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.today_outlined),
              title: const Text('هذه المرة فقط'),
              onTap: () => Navigator.pop(ctx, 'once'),
            ),
            ListTile(
              leading: const Icon(Icons.update),
              title: const Text('من اليوم فصاعدًا'),
              subtitle: const Text('يتغير وقتها المفضل في روتيني'),
              onTap: () => Navigator.pop(ctx, 'forward'),
            ),
          ],
        ),
      ),
    ),
  );
  if (scope == 'once') await ctrl.moveOnce(date, i, t);
  if (scope == 'forward') await ctrl.moveFromToday(date, i, t);
}

/// «نزحزح اللي بعده؟»: إذا الوقت الجديد يتداخل مع عناصر قابلة للتحريك.
/// يرجع null للإلغاء، أو خريطة النقلات (فارغة = خلّها متداخلة أو ما فيه تداخل).
Future<Map<String, int>?> askReflow(
  BuildContext context,
  DayPlan plan,
  PlanItem item,
  int start,
) async {
  final r = reflowAfter(plan, item, start);
  if (!r.needed) return const {};
  final names = r.overlapped.map((x) => '«${x.title}»').take(3).join('، ');
  final choice = await showModalBottomSheet<String>(
    useRootNavigator: true,
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHeader('نزحزح اللي بعده؟'),
            Text(
              '«${item.title}» ${fmtTime(start)} تتداخل مع $names.',
              style: T.body.copyWith(color: ctx.c.ink2),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.low_priority),
              title: const Text('زحزح اللي بعدها'),
              subtitle: Text(
                r.moves.isEmpty
                    ? 'ما فيه مكان قبل النوم، تبقى كما هي'
                    : r.moves.entries
                          .take(3)
                          .map(
                            (e) =>
                                '${plan.byKey(e.key)?.title ?? ''} ← ${fmtTime(e.value)}',
                          )
                          .join('\n'),
              ),
              onTap: () => Navigator.pop(ctx, 'reflow'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.layers_outlined),
              title: const Text('خلّها متداخلة'),
              onTap: () => Navigator.pop(ctx, 'keep'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.close),
              title: const Text('إلغاء'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    ),
  );
  return switch (choice) {
    'reflow' => r.moves,
    'keep' => const {},
    _ => null,
  };
}

/// «سجّل تقدمي»: نطاق الصفحات. الصفحات تُحسب للهدف حتى لو الجلسة جزئية.
Future<void> showPagesSheet(
  BuildContext context,
  WidgetRef ref,
  PlanItem i,
  Day date,
) {
  var from = i.log?.value ?? i.pagesFrom ?? 1;
  var to = i.log?.value2 ?? i.pagesTo ?? from;
  return showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final c = ctx.c;
        Widget stepper(String label, int v, ValueChanged<int> on) => Expanded(
          child: Column(
            children: [
              Text(label, style: TextStyle(color: c.ink2)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => on(v + 1),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  Text(
                    nums(v),
                    style: const TextStyle(
                      fontFamily: fontDisplay,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: v > 1 ? () => on(v - 1) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
            ],
          ),
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'سجّل تقدمك في ${i.book ?? i.title}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    stepper(
                      'من صفحة',
                      from,
                      (v) => set(() {
                        from = v;
                        if (to < from) to = from;
                      }),
                    ),
                    stepper(
                      'إلى صفحة',
                      to,
                      (v) => set(() => to = v < from ? from : v),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${nums(to - from + 1)} صفحات',
                  style: TextStyle(color: c.muted),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'سجّل',
                  onPressed: () {
                    Navigator.pop(ctx);
                    ref
                        .read(appDataProvider.notifier)
                        .markDone(date, i, value: from, value2: to);
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
