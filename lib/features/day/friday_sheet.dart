import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';
import 'item_card.dart';

/// عمل من أعمال الجمعة: يُضاف كمهمة لمرة واحدة بمعرّف ثابت لليوم.
class _Deed {
  const _Deed(this.id, this.title, this.icon, this.hint);
  final String id;
  final String title;
  final String icon;
  final String Function(DayPrayers pr, int jumuah) hint;
}

final _deeds = [
  _Deed('kahf', 'قراءة سورة الكهف', 'kahf', (_, _) => 'بعد الفجر · ٢٠ دقيقة'),
  _Deed(
    'ghusl',
    'الغُسل والطيب',
    'ghusl',
    (_, j) => 'قبل الصلاة · ${fmtTime(j - 75)}',
  ),
  _Deed(
    'early',
    'التبكير إلى الصلاة',
    'early',
    (_, j) => 'اخرج قبل ${fmtTime(j - 30)}',
  ),
  _Deed(
    'salawat',
    'الإكثار من الصلاة على النبي ﷺ',
    'salawat',
    (_, _) => 'تذكير خفيف كل ساعتين',
  ),
  _Deed(
    'dua',
    'الدعاء في آخر ساعة',
    'dua',
    (pr, _) => '${fmtRange(pr.maghrib - 60, pr.maghrib)} · قبل المغرب',
  ),
];

String _fridayPrefix(Day d) => 'friday-${d.key}-';

/// هل تُعرض ورقة الجمعة الآن؟ أول فتح في الجمعة فقط.
bool shouldShowFriday(WidgetRef ref, Day date) {
  final data = ref.read(appDataProvider);
  final today = ref.read(todayProvider);
  if (date != today || date.weekday != DateTime.friday) return false;
  if (data.profile?.islam != true || !data.settings.fridaySheet) return false;
  if (data.meta['friday.seen'] == date.key) return false;
  // الورقة تفيد قبل الصلاة فقط؛ بعدها تبقى البطاقة في الجدول.
  final plan = ref.read(dayPlanProvider(date));
  if (ref.read(nowMinuteProvider) >= _jumuahStart(plan)) return false;
  return !data.oneOffs.any((o) => o.id.startsWith(_fridayPrefix(date)));
}

int _jumuahStart(DayPlan plan) =>
    plan.byKey('prayer:jumuah')?.start ?? (plan.prayers.dhuhr - 20);

/// ورقة «جمعة مباركة».
Future<void> showFridaySheet(BuildContext context, WidgetRef ref, Day date) {
  ref.read(appDataProvider.notifier).setMeta('friday.seen', date.key);
  return showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    builder: (_) => _FridaySheet(date: date),
  );
}

class _FridaySheet extends ConsumerStatefulWidget {
  const _FridaySheet({required this.date});
  final Day date;
  @override
  ConsumerState<_FridaySheet> createState() => _FridaySheetState();
}

class _FridaySheetState extends ConsumerState<_FridaySheet> {
  final _on = {for (final d in _deeds) d.id};

  Future<void> _add() async {
    final ctrl = ref.read(appDataProvider.notifier);
    final d = widget.date;
    final plan = ref.read(dayPlanProvider(d));
    final pr = plan.prayers;
    final j = _jumuahStart(plan);
    final p = _fridayPrefix(d);
    final now = ref.read(nowMinuteProvider);
    // ما فات وقته يُقترح بعد الآن بدل أن يظهر «فاتت» مباشرة.
    int at(int m) => m > now + 5 ? m : ((now + 14) ~/ 5) * 5;
    for (final deed in _deeds.where((x) => _on.contains(x.id))) {
      switch (deed.id) {
        case 'kahf':
          await ctrl.addOneOff(
            OneOff(
              id: '${p}kahf',
              kind: OneOffKind.task,
              title: deed.title,
              date: d,
              duration: 20,
              window: now < pr.sunrise + 60 ? Window.afterFajr : Window.any,
              preferred: at(pr.fajr + 30),
              icon: deed.icon,
            ),
          );
        case 'ghusl':
          await ctrl.addOneOff(
            OneOff(
              id: '${p}ghusl',
              kind: OneOffKind.task,
              title: deed.title,
              date: d,
              duration: 15,
              preferred: at(j - 75),
              icon: deed.icon,
              note: 'الجمعة',
            ),
          );
        case 'early':
          await ctrl.addOneOff(
            OneOff(
              id: '${p}early',
              kind: OneOffKind.task,
              title: deed.title,
              date: d,
              duration: 25,
              preferred: at(j - 30),
              icon: deed.icon,
            ),
          );
        case 'salawat':
          final wake = plan.wake;
          var k = 0;
          for (var t = at(wake + 120); t < pr.maghrib; t += 120) {
            await ctrl.addOneOff(
              OneOff(
                id: '${p}salawat$k',
                kind: OneOffKind.reminder,
                title: 'الصلاة على النبي ﷺ',
                date: d,
                start: (t ~/ 5) * 5,
                icon: deed.icon,
              ),
            );
            k++;
          }
        case 'dua':
          await ctrl.addOneOff(
            OneOff(
              id: '${p}dua',
              kind: OneOffKind.task,
              title: deed.title,
              date: d,
              duration: 60,
              preferred: at(pr.maghrib - 60),
              icon: deed.icon,
              note: 'قبل المغرب',
            ),
          );
      }
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final plan = ref.watch(dayPlanProvider(widget.date));
    final settings = ref.watch(appDataProvider.select((d) => d.settings));
    final j = _jumuahStart(plan);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHeader(
              'جمعة مباركة',
              subtitle:
                  'أعمال يوم الجمعة. اختر ما تبغى نذكّرك فيه ونرتّبه في يومك.',
            ),
            SettingsGroup(
              children: [
                for (final d in _deeds)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12),
                    child: Row(
                      children: [
                        IconSquare(iconFor(d.icon), fg: c.accent),
                        Expanded(
                          child: SettingsRow(
                            title: d.title,
                            subtitle: d.hint(plan.prayers, j),
                            toggle: _on.contains(d.id),
                            onToggle: (v) => setState(
                              () => v ? _on.add(d.id) : _on.remove(d.id),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SettingsRow(
              title: 'اعرض هذه الورقة كل جمعة',
              toggle: settings.fridaySheet,
              onToggle: (v) => ref
                  .read(appDataProvider.notifier)
                  .updateSettings(settings.copyWith(fridaySheet: v)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PrimaryButton(
                    label: 'أضفها إلى يومي',
                    onPressed: _on.isEmpty ? null : _add,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ليس الآن'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// البطاقة المثبّتة أعلى يومي بعد الإضافة: «١ من ٥ · التالي: …».
class FridayCard extends ConsumerWidget {
  const FridayCard({super.key, required this.date, required this.plan});
  final Day date;
  final DayPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final prefix = isFridayChild;
    final items = plan.items.where((i) => prefix(i.key)).toList();
    final lines = plan.lines.where((l) => prefix(l.key)).toList();
    if (items.isEmpty && lines.isEmpty) return const SizedBox.shrink();
    final total = items.length + (lines.isEmpty ? 0 : 1);
    final done =
        items.where((i) => i.isDoneLike).length +
        (lines.any((l) => l.done) ? 1 : 0);
    final now = ref.watch(nowMinuteProvider);
    final next = items
        .where((i) => i.status == ItemStatus.pending && i.end > now)
        .firstOrNull;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(R.lg),
        border: Border.all(color: c.line),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconSquare(iconFor('kahf'), bg: c.accentSoft, fg: c.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('أعمال يوم الجمعة', style: T.cardTitle),
                    Text(
                      [
                        '${fmtCount(done, total)} تمّت',
                        if (next != null) 'التالي: ${next.title}',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.meta.copyWith(color: c.muted),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : done / total,
                        minHeight: 4,
                        backgroundColor: c.sunk,
                        color: c.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, top: 6),
              child: ChildItems(items: items, date: date),
            ),
          for (final l in lines.take(1))
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 30, top: 6),
              child: Row(
                children: [
                  Icon(iconFor('salawat'), size: 16, color: c.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${l.title} · ${nums(lines.length)} تذكيرات خفيفة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.micro.copyWith(color: c.muted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// عناصر أعمال الجمعة تظهر داخل بطاقتها الأب لا في الجدول.
bool isFridayChild(String key) => key.startsWith('once:friday-');
