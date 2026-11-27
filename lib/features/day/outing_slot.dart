import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';

/// أقرب يوم بعد [from] (خلال أسبوع) فيه وقت فاضٍ للطلعة داخل فترتها.
(Day, int)? nextOutingSlot(WidgetRef ref, OutingConfig o, Day from) {
  final today = ref.read(todayProvider);
  final now = ref.read(nowMinuteProvider);
  for (var k = 1; k <= 7; k++) {
    final d = from.add(k);
    if (d.isBefore(today)) continue;
    final plan = ref.read(dayPlanProvider(d));
    final end = o.windowEnd.clamp(0, plan.bedtime.clamp(0, minutesPerDay));
    for (var t = o.windowStart; t + o.duration <= end; t += 15) {
      if (d == today && t <= now) continue;
      if (ScheduleEngine.isFree(plan.busy, t, t + o.duration)) return (d, t);
    }
  }
  return null;
}

/// نص قصير للبانر: «ما لقينا ساعتين متاحة الخميس. السبت 5:00 م متاح».
String outingSlotText(WidgetRef ref, OutingConfig o, Day date) {
  final alt = nextOutingSlot(ref, o, date);
  final base =
      'ما لقينا ${fmtDuration(o.duration)} متاحة ${arabicWeekdays[date.weekday]}.';
  if (alt == null) return '$base اختر وقتًا بنفسك.';
  return '$base ${arabicWeekdays[alt.$1.weekday]} ${fmtTime(alt.$2)} متاح.';
}

/// «اختر موعدًا»: يوم بديل، أو وقت في نفس اليوم (ولو متداخل)، أو تخطّيها.
Future<void> showOutingSlotSheet(
  BuildContext context,
  WidgetRef ref,
  OutingKind kind,
  Day date,
) {
  final o = ref.read(appDataProvider).contacts.outing(kind);
  final alt = nextOutingSlot(ref, o, date);
  final ctrl = ref.read(appDataProvider.notifier);
  final key = 'outing:${kind.name}';
  return showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    builder: (ctx) {
      final c = ctx.c;
      Widget option(IconData icon, String title, String sub, VoidCallback f) =>
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon, color: c.accent),
            title: Text(title, style: T.body),
            subtitle: Text(sub, style: T.meta.copyWith(color: c.muted)),
            onTap: () {
              Navigator.pop(ctx);
              f();
            },
          );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader('موعد ${kind.label}'),
              Text(
                outingSlotText(ref, o, date),
                style: T.meta.copyWith(color: c.muted),
              ),
              const SizedBox(height: 6),
              if (alt != null)
                option(
                  Icons.event_available,
                  'انقلها إلى ${arabicWeekdays[alt.$1.weekday]} ${fmtTime(alt.$2)}',
                  'أقرب وقت فاضٍ داخل فترتها',
                  () async {
                    await ctrl.addOneOff(
                      OneOff(
                        id: 'outing-${kind.name}-${alt.$1.key}',
                        kind: OneOffKind.event,
                        title: kind.label,
                        date: alt.$1,
                        start: alt.$2,
                        duration: o.duration,
                        icon: kind.icon,
                      ),
                    );
                    await ctrl.setOverride(
                      DayOverride(date: date, itemKey: key, off: true),
                    );
                    if (context.mounted) {
                      toast(
                        context,
                        'نقلناها إلى ${arabicWeekdays[alt.$1.weekday]} ${fmtTime(alt.$2)}',
                      );
                    }
                  },
                ),
              option(
                Icons.schedule,
                'اختر وقتًا في نفس اليوم',
                'تنحجز ولو تداخلت مع شي مرن',
                () async {
                  final t = await pickTime(
                    context,
                    initial: o.windowStart,
                    title: 'وقت ${kind.label}',
                  );
                  if (t == null) return;
                  await ctrl.setOverride(
                    DayOverride(date: date, itemKey: key, start: t),
                  );
                },
              ),
              option(
                Icons.event_busy,
                'تخطّها هالمرة',
                'ترجع في موعدها الجاي',
                () => ctrl.setOverride(
                  DayOverride(date: date, itemKey: key, off: true),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
