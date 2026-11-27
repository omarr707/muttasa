import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';

const _amounts = [
  ('فنجان', 150, Icons.coffee_outlined),
  ('كوب', 250, Icons.local_drink_outlined),
  ('قارورة', 330, Icons.water_drop_outlined),
  ('قارورة', 500, Icons.water_outlined),
];

/// «لتر» بفاصلة عشرية واحدة: ٠٫٥ لتر.
String fmtLiters(int ml) {
  final l = ml / 1000;
  final s = l == l.roundToDouble()
      ? l.toStringAsFixed(0)
      : l.toStringAsFixed(ml % 100 == 0 ? 1 : 2);
  return nums(s);
}

/// ورقة الماء: تختار الكمية بضغطة ثم «أضف».
Future<void> showWaterSheet(BuildContext context, WidgetRef ref, Day date) =>
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      builder: (_) => _WaterSheet(date: date),
    );

class _WaterSheet extends ConsumerStatefulWidget {
  const _WaterSheet({required this.date});
  final Day date;
  @override
  ConsumerState<_WaterSheet> createState() => _WaterSheetState();
}

class _WaterSheetState extends ConsumerState<_WaterSheet> {
  late int _ml = ref.read(appDataProvider).settings.lastWaterMl;

  Future<void> _other() async {
    final ctl = TextEditingController(text: '$_ml');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('كمية أخرى'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(suffixText: 'مل'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctl.text)),
            child: const Text('تم'),
          ),
        ],
      ),
    );
    if (v != null && v > 0 && v <= 3000) setState(() => _ml = v);
  }

  Future<void> _goal() async {
    final s = ref.read(appDataProvider).settings;
    var goal = s.waterGoalMl;
    final v = await showModalBottomSheet<int>(
      useRootNavigator: true,
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHeader(
                  'هدف الماء اليومي',
                  subtitle: 'التذكيرات تتوزع على يومك حسب الهدف',
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'أقل',
                      onPressed: goal > 500
                          ? () => set(() => goal -= 250)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(
                        '${fmtLiters(goal)} لتر',
                        textAlign: TextAlign.center,
                        style: T.stat.copyWith(color: ctx.c.water),
                      ),
                    ),
                    IconButton(
                      tooltip: 'أكثر',
                      onPressed: goal < 5000
                          ? () => set(() => goal += 250)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'احفظ',
                  onPressed: () => Navigator.pop(ctx, goal),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (v != null) {
      await ref
          .read(appDataProvider.notifier)
          .updateSettings(s.copyWith(waterGoalMl: v));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = widget.date;
    final data = ref.watch(appDataProvider);
    final ctrl = ref.read(appDataProvider.notifier);
    final goal = data.settings.waterGoalMl;
    final drank = waterMl(data.logs[recordKey(d, 'water')]?.value);
    final sips = ctrl.waterSips(d);
    final plan = ref.watch(dayPlanProvider(d));
    final now = ref.watch(nowMinuteProvider);
    final next = plan.lines
        .where((l) => l.kind == LineKind.water && !l.done && l.minute > now)
        .firstOrNull;
    final filled = (drank / goal * 8).floor().clamp(0, 8);
    final known = _amounts.any((a) => a.$2 == _ml);

    Widget amount(String label, int ml, IconData icon) => ChoiceChip(
      avatar: Icon(icon, size: 16),
      label: Text('$label ${nums(ml)}'),
      selected: _ml == ml,
      showCheckmark: false,
      onSelected: (_) => setState(() => _ml = ml),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetHeader(
              'سجّل الماء',
              trailing: TextButton.icon(
                onPressed: _goal,
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('الهدف'),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${fmtLiters(drank)} لتر',
                  style: T.stat.copyWith(color: c.water),
                ),
                const SizedBox(width: 8),
                Text(
                  'من ${fmtLiters(goal)} لتر اليوم',
                  style: T.meta.copyWith(color: c.muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Semantics(
              label: 'شربت ${fmtLiters(drank)} لتر من ${fmtLiters(goal)}',
              excludeSemantics: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var k = 0; k < 8; k++)
                    Icon(
                      k < filled ? Icons.water_drop : Icons.water_drop_outlined,
                      size: 20,
                      color: k < filled ? c.water : c.lineStrong,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('كم شربت؟', style: T.label.copyWith(color: c.muted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in _amounts) amount(a.$1, a.$2, a.$3),
                ChoiceChip(
                  avatar: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(known ? 'كمية أخرى' : '${nums(_ml)} مل'),
                  selected: !known,
                  showCheckmark: false,
                  onSelected: (_) => _other(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'أضف ${nums(_ml)} مل',
              onPressed: () async {
                await ctrl.addWater(d, _ml);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (sips.isNotEmpty) ...[
                  Text(
                    'آخر شربة ${fmtTime(sips.last.$1)} · ',
                    style: T.meta.copyWith(color: c.muted),
                  ),
                  InkWell(
                    onTap: () => ctrl.undoWater(d),
                    child: Text(
                      'تراجع',
                      style: T.meta.copyWith(
                        color: c.accent,
                        decoration: TextDecoration.underline,
                        decorationColor: c.accent,
                      ),
                    ),
                  ),
                ] else
                  Text(
                    'ما سجلت ماء اليوم',
                    style: T.meta.copyWith(color: c.muted),
                  ),
                const Spacer(),
                if (next != null)
                  Text(
                    'التذكير القادم ${fmtTime(next.minute)}',
                    style: T.meta.copyWith(color: c.muted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
