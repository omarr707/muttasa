import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';
import 'settings_screen.dart' show SettingsPage;

/// ملخص سطر الإعدادات: «الأصحاب كل أسبوعين · العائلة أسبوعيًا».
String outingsSummary(ContactsConfig c) {
  final on = [
    for (final k in OutingKind.values)
      if (c.outing(k).enabled)
        '${k == OutingKind.friends ? 'الأصحاب' : 'العائلة'} ${c.outing(k).frequencyLabel}',
  ];
  return on.isEmpty ? 'متوقفة' : on.join(' · ');
}

/// الطلعات: تبويبان، خرجة الأصحاب وطلعة العائلة. كل واحدة بأيامها وفترتها
/// ومدتها وتكرارها، ثابتة أو مقترحة، ومع مين.
class OutingsPage extends ConsumerStatefulWidget {
  const OutingsPage({super.key});
  @override
  ConsumerState<OutingsPage> createState() => _OutingsPageState();
}

class _OutingsPageState extends ConsumerState<OutingsPage> {
  OutingKind _tab = OutingKind.friends;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cfg = ref.watch(appDataProvider.select((d) => d.contacts));
    final people = ref.watch(appDataProvider.select((d) => d.people));
    final o = cfg.outing(_tab);
    final ctrl = ref.read(appDataProvider.notifier);
    void set(OutingConfig n) => ctrl.updateContacts(cfg.withOuting(n));
    Widget label(String t) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 18, 4, 8),
      child: Text(t, style: T.label.copyWith(color: c.muted)),
    );

    return SettingsPage(
      title: 'الطلعات',
      children: [
        const SizedBox(height: 8),
        Segmented<OutingKind>(
          values: OutingKind.values,
          labels: [for (final k in OutingKind.values) k.label],
          selected: _tab,
          onChanged: (k) => setState(() => _tab = k),
        ),
        const SizedBox(height: 12),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: _tab == OutingKind.friends
                  ? Icons.local_cafe_outlined
                  : Icons.family_restroom,
              title: _tab.label,
              subtitle: 'نحجز لها وقتًا في يومك حسب إعدادك',
              toggle: o.enabled,
              onToggle: (v) => set(o.copyWith(enabled: v)),
            ),
          ],
        ),
        if (o.enabled) ...[
          label('الأيام'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final d in weekOrder)
                FilterChip(
                  label: Text(arabicWeekdays[d]!),
                  selected: o.days.contains(d),
                  showCheckmark: false,
                  onSelected: (on) => set(
                    o.copyWith(
                      days: on ? {...o.days, d} : ({...o.days}..remove(d)),
                    ),
                  ),
                ),
            ],
          ),
          label('الفترة'),
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.schedule,
                title: 'من',
                value: fmtTime(o.windowStart),
                onTap: () async {
                  final t = await pickTime(
                    context,
                    initial: o.windowStart,
                    title: 'من',
                  );
                  if (t != null) set(o.copyWith(windowStart: t));
                },
              ),
              SettingsRow(
                icon: Icons.schedule,
                title: 'إلى',
                value: fmtTime(o.windowEnd),
                onTap: () async {
                  final t = await pickTime(
                    context,
                    initial: o.windowEnd,
                    title: 'إلى',
                  );
                  if (t != null && t > o.windowStart) {
                    set(o.copyWith(windowEnd: t));
                  }
                },
              ),
            ],
          ),
          label('المدة'),
          ChoiceChips<int>(
            values: const [60, 90, 120, 180, 240],
            label: fmtDuration,
            selected: (v) => v == o.duration,
            onSelected: (v) => set(o.copyWith(duration: v)),
          ),
          label('كم مرة؟'),
          Segmented<int>(
            values: const [1, 2, 4],
            labels: const ['أسبوعيًا', 'كل أسبوعين', 'شهريًا'],
            selected: o.everyWeeks,
            onChanged: (v) => set(o.copyWith(everyWeeks: v)),
          ),
          label('ثابتة أو مقترحة؟'),
          Segmented<bool>(
            values: const [true, false],
            labels: const ['مقترحة', 'ثابتة'],
            selected: o.suggested,
            onChanged: (v) => set(o.copyWith(suggested: v)),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 6, 4, 0),
            child: Text(
              o.suggested
                  ? 'تظهر «مقترحة» في يومك وتثبّتها بضغطة، أو تتركها.'
                  : 'تنحجز مباشرة في يومك.',
              style: T.meta.copyWith(color: c.muted),
            ),
          ),
          label('مع مين؟ (اختياري)'),
          if (people.isEmpty)
            Text(
              'أضف أشخاصًا من الإعدادات › التواصل، وتقدر تختارهم هنا.',
              style: T.meta.copyWith(color: c.muted),
            )
          else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in people)
                  FilterChip(
                    label: Text(p.name),
                    selected: o.people.contains(p.id),
                    showCheckmark: false,
                    onSelected: (on) => set(
                      o.copyWith(
                        people: on
                            ? [...o.people, p.id]
                            : (o.people.where((x) => x != p.id).toList()),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 6, 4, 0),
              child: Text(
                'إذا تمّت الطلعة تنحسب تواصلًا مع اللي اخترتهم.',
                style: T.meta.copyWith(color: c.muted),
              ),
            ),
          ],
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}
