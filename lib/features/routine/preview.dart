import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';

/// التعديلات تذهب إلى مسودة، والجدول الحالي لا يتغير.
/// عند «احفظ» نولّد الأيام السبعة القادمة بالقواعد القديمة والجديدة ونعرض الفروق.
/// المستخدم يختار «طبّق على المتبقي اليوم» أو «ابدأ من بكرة»، وهذا يحدد validFrom.
Future<bool> saveWithPreview(
  BuildContext context,
  WidgetRef ref,
  Rule? old,
  RuleConfig cfg, {
  String? key,
}) async {
  final ctrl = ref.read(appDataProvider.notifier);
  final today = ref.read(todayProvider);
  final data = ref.read(appDataProvider);
  final calc = ref.read(prayerCalcProvider);
  final before = ref.read(engineProvider);
  final after = ScheduleEngine(
    buildInput(
      data,
      calc,
      today,
      rules: ctrl.rulesAfterSave(old, cfg, from: today, key: key),
    ),
  );
  final diffs = previewChanges(before, after, today);
  final changed = diffs.where((d) => d.changes.isNotEmpty).toList();
  final manualDays = diffs
      .where((d) => d.hasManualEdits && d.changes.isNotEmpty)
      .length;

  if (changed.isEmpty) {
    await ctrl.saveRule(old, cfg, from: today, key: key);
    if (context.mounted) {
      toast(context, 'انحفظ. ما تغيّر شي في الأيام السبعة القادمة.');
    }
    return true;
  }
  if (!context.mounted) return false;
  final choice = await showModalBottomSheet<String>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final c = ctx.c;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * .85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  children: [
                    const Text(
                      'معاينة التغييرات',
                      style: TextStyle(
                        fontFamily: fontDisplay,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      'الأيام السبعة القادمة بعد التعديل.',
                      style: TextStyle(color: c.ink2),
                    ),
                    if (manualDays > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'فيه $manualDays أيام عدّلتها بيدك. تعديلاتك والمنجز يبقون كما هم.',
                          style: TextStyle(
                            color: c.warn,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    for (final d in changed) ...[
                      FieldLabel(
                        '${fmtDayLong(d.date)}${d.hasManualEdits ? ' · عدّلته بيدك' : ''}',
                      ),
                      for (final ch in d.changes)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                switch (ch.type) {
                                  ChangeType.moved => Icons.swap_vert,
                                  ChangeType.added => Icons.add_circle_outline,
                                  ChangeType.removed =>
                                    Icons.remove_circle_outline,
                                  ChangeType.unplaced => Icons.hourglass_empty,
                                },
                                size: 18,
                                color: ch.type == ChangeType.unplaced
                                    ? c.warn
                                    : c.accent2,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  ch.label,
                                  style: const TextStyle(fontSize: 13.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    PrimaryButton(
                      label: 'طبّق على المتبقي اليوم',
                      onPressed: () => Navigator.pop(ctx, 'today'),
                    ),
                    const SizedBox(height: 8),
                    PillButton(
                      label: 'ابدأ من بكرة',
                      soft: true,
                      expand: true,
                      onPressed: () => Navigator.pop(ctx, 'tomorrow'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إلغاء'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (choice == null) return false;
  await ctrl.saveRule(
    old,
    cfg,
    from: choice == 'today' ? today : today.next,
    key: key,
  );
  if (context.mounted) {
    toast(context, choice == 'today' ? 'تطبّق من اليوم' : 'يبدأ من بكرة');
  }
  return true;
}
