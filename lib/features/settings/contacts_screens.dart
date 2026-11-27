import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';
import 'settings_screen.dart';

String _people(int n) => n == 1
    ? 'شخص واحد'
    : (n == 2 ? 'شخصان' : '${nums(n)} ${n <= 10 ? 'أشخاص' : 'شخصًا'}');

/// الإعدادات › التواصل مع الناس: المفتاح والمستوى والأشخاص والجدولة.
class ContactsSettingsPage extends ConsumerWidget {
  const ContactsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final data = ref.watch(appDataProvider);
    final cfg = data.contacts;
    final ctrl = ref.read(appDataProvider.notifier);
    final today = ref.watch(todayProvider);
    final week = ref.watch(engineProvider).contactWeek(today);
    final weekCount = week.values.fold<int>(0, (a, l) => a + l.length);
    void set(ContactsConfig n) => ctrl.updateContacts(n);

    return SettingsPage(
      title: 'التواصل مع الناس',
      children: [
        const SizedBox(height: 8),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.forum_outlined,
              title: 'التواصل مع الناس',
              subtitle: 'اقتراحات الاتصال والرسائل في «يومي»',
              toggle: cfg.enabled,
              onToggle: (v) => set(cfg.copyWith(enabled: v)),
            ),
          ],
        ),
        if (cfg.enabled) ...[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 20, 4, 8),
            child: Text(
              'كم مرة في الأسبوع؟',
              style: T.label.copyWith(color: c.muted),
            ),
          ),
          Segmented<ContactLevel>(
            values: const [
              ContactLevel.low,
              ContactLevel.mid,
              ContactLevel.high,
              ContactLevel.off,
            ],
            labels: const ['قليل', 'متوسط', 'كثير', 'إيقاف'],
            selected: cfg.level,
            onChanged: (v) => set(cfg.copyWith(level: v)),
          ),
          const SizedBox(height: 12),
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.group_outlined,
                title: 'الأشخاص',
                value: _people(data.people.length),
                onTap: () => pushPage(context, const PeoplePage()),
              ),
              SettingsRow(
                icon: Icons.view_week_outlined,
                title: 'جدول الأسبوع',
                value: '${nums(weekCount)} تواصلات',
                onTap: () => pushPage(context, const ContactWeekPage()),
              ),
            ],
          ),
          SettingsGroup(
            title: 'يشمل',
            children: [
              SettingsRow(
                icon: Icons.call_outlined,
                title: 'تذكير بالاتصال',
                toggle: cfg.calls,
                onToggle: (v) => set(cfg.copyWith(calls: v)),
              ),
              SettingsRow(
                icon: Icons.chat_outlined,
                title: 'تذكير بالرسائل ومسوداتها',
                toggle: cfg.messages,
                onToggle: (v) => set(cfg.copyWith(messages: v)),
              ),
              SettingsRow(
                icon: Icons.celebration_outlined,
                title: 'المناسبات والتهاني',
                toggle: cfg.occasions,
                onToggle: (v) => set(cfg.copyWith(occasions: v)),
              ),
              SettingsRow(
                icon: Icons.redeem_outlined,
                title: 'أفكار الهدايا حسب الميزانية',
                toggle: cfg.gifts,
                onToggle: (v) => set(cfg.copyWith(gifts: v)),
              ),
            ],
          ),
          _SchedulingGroup(cfg: cfg),
        ],
      ],
    );
  }
}

class _SchedulingGroup extends ConsumerWidget {
  const _SchedulingGroup({required this.cfg, this.withVisits = false});
  final ContactsConfig cfg;
  final bool withVisits;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(appDataProvider.notifier);
    return SettingsGroup(
      title: withVisits ? 'كيف نختار الوقت' : 'الجدولة',
      children: [
        SettingsRow(
          icon: Icons.schedule,
          title: 'وقت الاقتراحات',
          value: 'المساء ${fmtRange(cfg.windowStart, cfg.windowEnd)}',
          onTap: () async {
            final a = await pickTime(
              context,
              initial: cfg.windowStart,
              title: 'من',
            );
            if (a == null || !context.mounted) return;
            final b = await pickTime(
              context,
              initial: cfg.windowEnd,
              title: 'إلى',
            );
            if (b == null || b <= a) return;
            await ctrl.updateContacts(
              cfg.copyWith(windowStart: a, windowEnd: b),
            );
          },
        ),
        SettingsRow(
          icon: Icons.work_off_outlined,
          title: 'لا تقترح وقت الدوام',
          toggle: cfg.avoidWork,
          onToggle: (v) => ctrl.updateContacts(cfg.copyWith(avoidWork: v)),
        ),
        if (withVisits)
          SettingsRow(
            icon: Icons.weekend_outlined,
            title: 'الزيارات في الإجازة فقط',
            toggle: cfg.visitsWeekendOnly,
            onToggle: (v) =>
                ctrl.updateContacts(cfg.copyWith(visitsWeekendOnly: v)),
          ),
      ],
    );
  }
}

/// قائمة الأشخاص مع البحث.
class PeoplePage extends ConsumerStatefulWidget {
  const PeoplePage({super.key});
  @override
  ConsumerState<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends ConsumerState<PeoplePage> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final data = ref.watch(appDataProvider);
    final today = ref.watch(todayProvider);
    final q = _q.text.trim();
    final list =
        data.people.where((p) => q.isEmpty || p.name.contains(q)).toList()
          ..sort((a, b) {
            if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
            return a.name.compareTo(b.name);
          });
    String last(Person p) {
      Day? d;
      for (final l in data.logs.values) {
        if (l.itemKey == p.itemKey && l.status == ItemStatus.done) {
          if (d == null || l.date.isAfter(d)) d = l.date;
        }
      }
      if (d == null) return 'ما تواصلت بعد';
      final n = today.difference(d);
      return switch (n) {
        0 => 'اليوم',
        1 => 'أمس',
        _ => 'قبل ${nums(n)} ${n <= 10 ? 'أيام' : 'يومًا'}',
      };
    }

    return Scaffold(
      appBar: AppBar(title: const Text('الأشخاص')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => pushPage(context, const PersonEditPage()),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('أضف شخصًا'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'ابحث بالاسم',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            if (data.people.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'أضف الناس اللي تبغى تتواصل معهم، ونقترح عليك وقتًا مناسبًا كل أسبوع.',
                  textAlign: TextAlign.center,
                  style: T.body.copyWith(color: c.muted),
                ),
              )
            else
              SettingsGroup(
                children: [
                  for (final p in list)
                    InkWell(
                      onTap: () => pushPage(context, PersonEditPage(person: p)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: c.accentSoft,
                              child: Text(
                                p.initial,
                                style: T.section.copyWith(color: c.accent),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: T.cardTitle,
                                  ),
                                  Text(
                                    '${p.relation.label} · ${p.freq.label} · ${last(p)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: T.meta.copyWith(color: c.muted),
                                  ),
                                ],
                              ),
                            ),
                            if (p.pinned) const _PinBadge(),
                          ],
                        ),
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

class _PinBadge extends StatelessWidget {
  const _PinBadge();
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.push_pin_outlined, size: 14, color: c.accent),
          const SizedBox(width: 4),
          Text('مثبّت', style: T.micro.copyWith(color: c.accent)),
        ],
      ),
    );
  }
}

/// إضافة شخص أو تعديله. نحفظ الاسم والرقم فقط.
class PersonEditPage extends ConsumerStatefulWidget {
  const PersonEditPage({super.key, this.person});
  final Person? person;
  @override
  ConsumerState<PersonEditPage> createState() => _PersonEditPageState();
}

class _PersonEditPageState extends ConsumerState<PersonEditPage> {
  late final _name = TextEditingController(text: widget.person?.name ?? '');
  late final _phone = TextEditingController(text: widget.person?.phone ?? '');
  late final _budget = TextEditingController(
    text: widget.person?.giftBudget?.toString() ?? '',
  );
  late Relation _relation = widget.person?.relation ?? Relation.family;
  late ContactFreq _freq = widget.person?.freq ?? ContactFreq.biweekly;
  late ContactMethod _method = widget.person?.method ?? ContactMethod.call;
  late bool _pinned = widget.person?.pinned ?? false;
  late List<Occasion> _occasions = [...?widget.person?.occasions];

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _addOccasion(OccasionKind kind) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year + 5),
      initialDate: now,
      helpText: kind.label,
    );
    if (d == null) return;
    setState(() {
      _occasions = [
        ..._occasions.where((o) => o.kind != kind),
        Occasion(
          kind: kind,
          month: d.month,
          day: d.day,
          year: kind == OccasionKind.birthday ? null : d.year,
        ),
      ];
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'اكتب الاسم');
      return;
    }
    final old = widget.person;
    final p = Person(
      id: old?.id ?? newId(),
      name: name,
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      relation: _relation,
      freq: _freq,
      method: _method,
      pinned: _pinned,
      occasions: _occasions,
      giftBudget: int.tryParse(_budget.text.trim()),
      addedAt: old?.addedAt ?? ref.read(todayProvider),
    );
    await ref.read(appDataProvider.notifier).savePerson(p);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget label(String t) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 18, 4, 8),
      child: Text(t, style: T.label.copyWith(color: c.muted)),
    );
    String occ(OccasionKind k) {
      final o = _occasions.where((o) => o.kind == k).firstOrNull;
      if (o == null) return 'أضف';
      return nums('${o.day}/${o.month}${o.year == null ? '' : '/${o.year}'}');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.person == null ? 'أضف شخصًا' : 'تعديل'),
        actions: [
          if (widget.person != null)
            IconButton(
              tooltip: 'احذف',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await ref
                    .read(appDataProvider.notifier)
                    .deletePerson(widget.person!.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              'نحفظ الاسم والرقم فقط، على جهازك.',
              style: T.meta.copyWith(color: c.muted),
            ),
            label('الاسم'),
            TextField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'مثل: خالد'),
            ),
            label('الجوال'),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
              ],
              decoration: const InputDecoration(hintText: '+966 5x xxx xxxx'),
            ),
            label('العلاقة'),
            Segmented<Relation>(
              values: Relation.values,
              labels: [for (final r in Relation.values) r.label],
              selected: _relation,
              onChanged: (v) => setState(() => _relation = v),
            ),
            label('كم مرة؟'),
            Segmented<ContactFreq>(
              values: ContactFreq.values,
              labels: [for (final f in ContactFreq.values) f.label],
              selected: _freq,
              onChanged: (v) => setState(() => _freq = v),
            ),
            label('الطريقة'),
            Segmented<ContactMethod>(
              values: ContactMethod.values,
              labels: [for (final m in ContactMethod.values) m.label],
              selected: _method,
              onChanged: (v) => setState(() => _method = v),
            ),
            const SizedBox(height: 12),
            SettingsGroup(
              children: [
                SettingsRow(
                  icon: Icons.push_pin_outlined,
                  title: 'ثبّته',
                  subtitle: 'يُقترح بتكراره دائمًا، خارج العدد الأسبوعي',
                  toggle: _pinned,
                  onToggle: (v) => setState(() => _pinned = v),
                ),
              ],
            ),
            SettingsGroup(
              title: 'مناسباته',
              children: [
                SettingsRow(
                  icon: Icons.cake_outlined,
                  title: 'عيد الميلاد',
                  value: occ(OccasionKind.birthday),
                  onTap: () => _addOccasion(OccasionKind.birthday),
                ),
                SettingsRow(
                  icon: Icons.celebration_outlined,
                  title: 'الزواج',
                  value: occ(OccasionKind.wedding),
                  onTap: () => _addOccasion(OccasionKind.wedding),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      const IconSquare(Icons.redeem_outlined, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'ميزانية الهدية',
                          style: T.body.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: _budget,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(suffixText: 'ر.س'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'حفظ', onPressed: _save),
          ],
        ),
      ),
    );
  }
}

/// جدول التواصل هذا الأسبوع: يوم بيوم.
class ContactWeekPage extends ConsumerWidget {
  const ContactWeekPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final today = ref.watch(todayProvider);
    final engine = ref.watch(engineProvider);
    final cfg = ref.watch(appDataProvider.select((d) => d.contacts));
    final ws = today.weekStart;
    final rows = <Widget>[];
    var total = 0;
    for (var k = 0; k < 7; k++) {
      final d = ws.add(k);
      final plan = engine.day(d);
      final items = plan.items
          .where((i) => i.kind == ItemKind.contact)
          .toList();
      total += items.length;
      final workMins = plan.items
          .where((i) => i.kind == ItemKind.work)
          .fold<int>(0, (a, i) => a + i.duration);
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  arabicWeekdays[d.weekday]!,
                  style: T.body.copyWith(
                    fontWeight: d == today ? FontWeight.w600 : FontWeight.w500,
                    color: d == today ? c.accent : c.ink,
                  ),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Text(
                        workMins >= 8 * 60
                            ? 'لا شيء · يوم دوام طويل'
                            : 'لا شيء',
                        style: T.meta.copyWith(color: c.muted),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final i in items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          i.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: T.cardTitle.copyWith(
                                            fontSize: 14,
                                            color: i.isDoneLike
                                                ? c.muted
                                                : c.ink,
                                          ),
                                        ),
                                        Text(
                                          fmtTime(i.start),
                                          style: T.meta.copyWith(
                                            color: c.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (ref
                                          .read(appDataProvider)
                                          .people
                                          .where((p) => p.id == i.personId)
                                          .firstOrNull
                                          ?.pinned ==
                                      true)
                                    const _PinBadge(),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
    }
    return SettingsPage(
      title: 'جدول التواصل',
      children: [
        Text(
          'هذا الأسبوع · ${nums(total)} تواصلات في فراغك',
          style: T.meta.copyWith(color: c.muted),
        ),
        const SizedBox(height: 8),
        SettingsGroup(children: rows),
        _SchedulingGroup(cfg: cfg, withVisits: true),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            shape: const StadiumBorder(),
            side: BorderSide(color: c.line),
            foregroundColor: c.ink,
            backgroundColor: c.card,
          ),
          onPressed: () async {
            await ref.read(appDataProvider.notifier).resetContactWeek(today);
            if (context.mounted) toast(context, 'وزّعنا الأسبوع من جديد');
          },
          icon: const Icon(Icons.auto_fix_high, size: 18),
          label: const Text('أعد توزيع الأسبوع'),
        ),
      ],
    );
  }
}
