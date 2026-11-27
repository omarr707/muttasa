import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';
import 'item_sheet.dart';

/// ما فات وقته اليوم ولم يُسجّل.
List<PlanItem> missedToday(DayPlan plan, int now) => plan.items
    .where(
      (i) =>
          i.counted &&
          i.track != TrackMode.auto &&
          i.status == ItemStatus.pending &&
          i.end <= now,
    )
    .toList();

/// اسم الفترة لعنوان الشريط: «هذا الصباح» أو «اليوم».
String missedWhen(List<PlanItem> items, DayPlan plan) =>
    items.every((i) => i.end <= plan.prayers.dhuhr) ? 'هذا الصباح' : 'اليوم';

String _count(int n) => switch (n) {
  1 => 'مهمة',
  2 => 'مهمتان',
  _ => '${nums(n)} ${n <= 10 ? 'مهام' : 'مهمة'}',
};

/// شريط «فاتتك ٥ مهام هذا الصباح» في يومي.
class MissedBar extends StatelessWidget {
  const MissedBar({
    super.key,
    required this.count,
    required this.when,
    required this.onOpen,
  });
  final int count;
  final String when;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.amberSoft,
      borderRadius: BorderRadius.circular(R.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(R.md),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 10, 10),
          child: Row(
            children: [
              Icon(Icons.history, size: 20, color: c.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 1
                          ? 'فاتتك مهمة $when'
                          : 'فاتتك ${_count(count)} $when',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.cardTitle.copyWith(color: c.amber, fontSize: 14),
                    ),
                    Text(
                      'قرّر فيها مرة وحدة',
                      style: T.meta.copyWith(color: c.amber),
                    ),
                  ],
                ),
              ),
              SmallButton(label: 'راجعها', onTap: onOpen),
            ],
          ),
        ),
      ),
    );
  }
}

/// ورقة «فاتت وتحتاج قرارك».
Future<void> showMissedSheet(
  BuildContext context,
  WidgetRef ref,
  Day date,
) => showModalBottomSheet<void>(
  useRootNavigator: true,
  context: context,
  isScrollControlled: true,
  builder: (ctx) => Consumer(
    builder: (ctx, ref, _) {
      final c = ctx.c;
      final plan = ref.watch(dayPlanProvider(date));
      final now = ref.watch(nowMinuteProvider);
      final items = missedToday(plan, now);
      final ctrl = ref.read(appDataProvider.notifier);
      if (items.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
        });
      }
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * .85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SheetHeader(
                  'فاتت وتحتاج قرارك',
                  subtitle:
                      '${_count(items.length)} من ${missedWhen(items, plan) == 'هذا الصباح' ? 'الصباح' : 'اليوم'}. قرارك هنا لا يغيّر الأيام الجاية',
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, k) {
                    final i = items[k];
                    final prayer = i.kind == ItemKind.prayer;
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(R.md),
                        border: Border.all(color: c.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconSquare(iconFor(i.icon)),
                              const SizedBox(width: 10),
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
                                    Row(
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: c.amber,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          fmtRange(i.start, i.end),
                                          style: T.meta.copyWith(
                                            color: c.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 44,
                            ),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: prayer
                                  ? [
                                      SmallButton(
                                        label: 'صلّيتها',
                                        icon: Icons.check,
                                        onTap: () => ctrl.markDone(date, i),
                                      ),
                                      SmallButton(
                                        label: 'قضاء',
                                        onTap: () =>
                                            ctrl.markDone(date, i, value: 1),
                                      ),
                                      _TextAction(
                                        'لم أصلّها',
                                        () => ctrl.setStatus(
                                          date,
                                          i,
                                          ItemStatus.notDone,
                                        ),
                                      ),
                                    ]
                                  : [
                                      SmallButton(
                                        label: 'تمّت',
                                        icon: Icons.check,
                                        onTap: () => ctrl.markDone(date, i),
                                      ),
                                      SmallButton(
                                        label: 'أجّل',
                                        onTap: () => showPostponeSheet(
                                          ctx,
                                          ref,
                                          i,
                                          date,
                                        ),
                                      ),
                                      _TextAction(
                                        'تخطَّ',
                                        () => ctrl.setStatus(
                                          date,
                                          i,
                                          ItemStatus.skipped,
                                        ),
                                      ),
                                    ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await rearrangeFlow(context, ref, date, plan);
                        },
                        icon: const Icon(Icons.auto_fix_high, size: 18),
                        label: const Text('أعد ترتيب يومي'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          shape: const StadiumBorder(),
                          side: BorderSide(color: c.line),
                          foregroundColor: c.ink,
                        ),
                        onPressed: () async {
                          for (final i in items) {
                            await ctrl.setStatus(
                              date,
                              i,
                              i.kind == ItemKind.prayer
                                  ? ItemStatus.notDone
                                  : ItemStatus.skipped,
                            );
                          }
                        },
                        child: const Text('تخطَّ الباقي'),
                      ),
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

class _TextAction extends StatelessWidget {
  const _TextAction(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(
      foregroundColor: context.c.muted,
      minimumSize: const Size(44, 34),
      textStyle: T.label.copyWith(fontSize: 12.5),
    ),
    onPressed: onTap,
    child: Text(label),
  );
}

/// «رتّب يومي»: ينقل المتأخر إلى أقرب وقت فاضي بعد الآن.
Future<void> rearrangeFlow(
  BuildContext context,
  WidgetRef ref,
  Day date,
  DayPlan plan,
) async {
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
      r.moves.length == 1
          ? 'رتّبنا مهمة بعد الآن'
          : 'رتّبنا ${_count(r.moves.length)} بعد الآن',
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
              SheetHeader(
                'رتّبنا ${nums(r.moves.length)}، وهذي ما لقت وقت اليوم',
              ),
              for (final i in r.failed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(i.title),
                  trailing: SmallButton(
                    label: 'أجّل',
                    onTap: () {
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
