import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';

/// ورقة «كم ادّخرت؟»: مبالغ جاهزة أو مبلغ تكتبه. إدخال يدوي فقط.
Future<int?> showAmountSheet(
  BuildContext context, {
  required int planned,
  String currency = 'ريال',
  String title = 'كم ادّخرت؟',
}) {
  final presets = <int>{planned, 100, 250, 500, 1000}.toList()..sort();
  var amount = planned;
  final custom = TextEditingController();
  return showModalBottomSheet<int>(
    useRootNavigator: true,
    isScrollControlled: true,
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final c = ctx.c;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              16 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetHeader(
                  title,
                  subtitle: 'المخطط ${nums(fmtThousands(planned))} $currency',
                ),
                Center(
                  child: Text(
                    '${nums(fmtThousands(amount))} $currency',
                    style: T.stat.copyWith(fontSize: 28),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final p in presets)
                      SmallButton(
                        label: nums(fmtThousands(p)),
                        selected: p == amount && custom.text.isEmpty,
                        onTap: () => set(() {
                          custom.clear();
                          amount = p;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: custom,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'مبلغ آخر',
                    suffixText: currency,
                  ),
                  onChanged: (v) => set(() {
                    final n = int.tryParse(v);
                    if (n != null) amount = n;
                  }),
                ),
                const SizedBox(height: 6),
                Text(
                  'نحفظ الرقم اللي تكتبه بس، ولا نربط حسابك البنكي.',
                  style: T.meta.copyWith(color: c.muted),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'سجّل',
                  onPressed: amount > 0
                      ? () => Navigator.pop(ctx, amount)
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
