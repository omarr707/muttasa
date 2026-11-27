import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';
import '../settings/contacts_screens.dart' show PersonEditPage;
import 'item_sheet.dart';

class _AddType {
  const _AddType(this.kind, this.title, this.desc, this.icon);
  final OneOffKind kind;
  final String title;
  final String desc;
  final IconData icon;
}

const _types = [
  _AddType(
    OneOffKind.habitSession,
    'جلسة لعادة',
    'قراءة أو رياضة أو قرآن مرة زيادة',
    Icons.menu_book_outlined,
  ),
  _AddType(
    OneOffKind.task,
    'مهمة',
    'شي تسويه، بوقت محدد أو مرن',
    Icons.check_box_outlined,
  ),
  _AddType(
    OneOffKind.period,
    'فترة',
    'وقت محجوز، مثل جلسة مع عميل أو دورة',
    Icons.timelapse,
  ),
  _AddType(
    OneOffKind.event,
    'حدث',
    'مناسبة بتاريخ ووقت، مثل دعوة زواج',
    Icons.event_outlined,
  ),
  _AddType(
    OneOffKind.contact,
    'تواصل',
    'اتصال أو رسالة أو زيارة لشخص',
    Icons.call_outlined,
  ),
  _AddType(
    OneOffKind.reminder,
    'تذكير قصير',
    'سطر خفيف، مثل خذ الدواء',
    Icons.notifications_none,
  ),
];

/// «+ إضافة»: وش تبغى تضيف؟ كل نوع يظهر في الجدول بشكل مختلف.
Future<void> showAddSheet(BuildContext context, WidgetRef ref, Day date) async {
  final kind = await showModalBottomSheet<OneOffKind>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
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
                'وش تبغى تضيف؟',
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                ),
              ),
              Text(
                'كل نوع يظهر في الجدول بشكل مختلف.',
                style: TextStyle(color: c.ink2),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.45,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final t in _types)
                    MCard(
                      onTap: () => Navigator.pop(ctx, t.kind),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(t.icon, color: c.ink),
                          const Spacer(),
                          Text(
                            t.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            t.desc,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: c.ink2),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  if (kind == null || !context.mounted) return;
  await showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _AddForm(kind: kind, date: date),
    ),
  );
}

class _AddForm extends ConsumerStatefulWidget {
  const _AddForm({required this.kind, required this.date});
  final OneOffKind kind;
  final Day date;
  @override
  ConsumerState<_AddForm> createState() => _AddFormState();
}

class _AddFormState extends ConsumerState<_AddForm> {
  final _title = TextEditingController();
  late Day _date = widget.date;
  late bool _timed =
      widget.kind != OneOffKind.task && widget.kind != OneOffKind.habitSession;
  int _start = 17 * 60;
  int _duration = 30;
  Window _window = Window.any;
  Rule? _habit;

  // التواصل.
  Person? _person;
  String _method = 'call';

  // البطاقة الأب (اختياري).
  PlanItem? _parent;

  static const _methods = ['call', 'message', 'visit'];
  static const _methodLabels = {
    'call': 'اتصال',
    'message': 'رسالة',
    'visit': 'زيارة',
  };
  static const _methodMinutes = {'call': 15, 'message': 5, 'visit': 60};

  void _pickPerson(Person p) => setState(() {
    _person = p;
    _method = switch (p.method) {
      ContactMethod.visit => 'visit',
      ContactMethod.sms || ContactMethod.whatsapp => 'message',
      _ => 'call',
    };
    _duration = _methodMinutes[_method]!;
  });

  @override
  void initState() {
    super.initState();
    final now = ref.read(nowMinuteProvider);
    _start = ((now + 60) ~/ 30) * 30 % minutesPerDay;
    if (widget.kind == OneOffKind.period) _duration = 60;
    if (widget.kind == OneOffKind.event) _duration = 120;
    if (widget.kind == OneOffKind.contact) _duration = 15;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final engine = ref.watch(engineProvider);
    final habits = engine
        .rulesOn(_date)
        .where(
          (r) =>
              r.config is FlexConfig &&
              (r.kind == RuleKind.habit || r.kind == RuleKind.quran),
        )
        .toList();
    final isHabit = widget.kind == OneOffKind.habitSession;
    final isReminder = widget.kind == OneOffKind.reminder;
    final isContact = widget.kind == OneOffKind.contact;
    final people = ref.watch(appDataProvider.select((d) => d.people));
    final canSave = isHabit
        ? _habit != null
        : (isContact ? _person != null : _title.text.trim().isNotEmpty);
    final canNest = widget.kind == OneOffKind.task || isContact;
    final parents = canNest
        ? ref
              .watch(dayPlanProvider(_date))
              .items
              .where((i) => i.kind != ItemKind.contact || i.oneOffId == null)
              .where((i) => !_isChild(i))
              .toList()
        : const <PlanItem>[];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.kind.label,
              style: const TextStyle(
                fontFamily: fontDisplay,
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
            if (isHabit) ...[
              const FieldLabel('أي عادة؟'),
              if (habits.isEmpty)
                Text(
                  'ما عندك عادات بعد. أضفها من «روتيني».',
                  style: TextStyle(color: c.ink2),
                ),
              ChoiceChips<Rule>(
                values: habits,
                label: (r) => (r.config as FlexConfig).title,
                selected: (r) => r.key == _habit?.key,
                onSelected: (r) => setState(() {
                  _habit = r;
                  _duration = (r.config as FlexConfig).duration;
                }),
              ),
            ] else if (isContact) ...[
              const FieldLabel('مع مين؟'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in people)
                    ChoiceChip(
                      label: Text(p.name),
                      selected: _person?.id == p.id,
                      showCheckmark: false,
                      onSelected: (_) => _pickPerson(p),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.person_add_alt, size: 18),
                    label: const Text('أضف شخصًا'),
                    onPressed: () async {
                      final before = people.map((p) => p.id).toSet();
                      await Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PersonEditPage(),
                        ),
                      );
                      if (!mounted) return;
                      final added = ref
                          .read(appDataProvider)
                          .people
                          .where((p) => !before.contains(p.id))
                          .firstOrNull;
                      if (added != null) _pickPerson(added);
                    },
                  ),
                ],
              ),
              const FieldLabel('الطريقة'),
              ChoiceChips<String>(
                values: _methods,
                label: (m) => _methodLabels[m]!,
                selected: (m) => m == _method,
                onSelected: (m) => setState(() {
                  _method = m;
                  _duration = _methodMinutes[m]!;
                }),
              ),
            ] else ...[
              const FieldLabel('العنوان'),
              TextField(
                controller: _title,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: switch (widget.kind) {
                    OneOffKind.task => 'مثل: تجديد الرخصة',
                    OneOffKind.period => 'مثل: جلسة مع عميل',
                    OneOffKind.event => 'مثل: دعوة زواج',
                    _ => 'مثل: خذ الدواء',
                  },
                ),
              ),
            ],
            const FieldLabel('اليوم'),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(
                    nums(
                      '${arabicWeekdays[_date.weekday]} ${_date.day}/${_date.month}',
                    ),
                  ),
                  selected: true,
                  showCheckmark: false,
                ),
                ActionChip(
                  label: const Text('غيّر اليوم'),
                  onPressed: () async {
                    final d = await pickDay(
                      context,
                      from: ref.read(todayProvider),
                      days: 30,
                    );
                    if (d != null) setState(() => _date = d);
                  },
                ),
              ],
            ),
            if (widget.kind == OneOffKind.task || isHabit || isContact) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('بوقت محدد'),
                subtitle: Text(
                  _timed ? 'تثبت في وقتها' : 'مرنة: نلقى لها أقرب وقت فاضي',
                ),
                value: _timed,
                onChanged: (v) => setState(() => _timed = v),
              ),
            ],
            if (_timed || isReminder) ...[
              const SizedBox(height: 8),
              TimeField(
                label: isReminder ? 'وقت التذكير' : 'البداية',
                value: _start,
                onChanged: (v) => setState(() => _start = v),
              ),
            ] else ...[
              const FieldLabel('الفترة المفضلة'),
              ChoiceChips<Window>(
                values: const [
                  Window.morning,
                  Window.afternoon,
                  Window.night,
                  Window.any,
                ],
                label: (w) => w.label,
                selected: (w) => w == _window,
                onSelected: (w) => setState(() => _window = w),
              ),
            ],
            if (!isReminder) ...[
              const FieldLabel('المدة'),
              ChoiceChips<int>(
                values: const [10, 15, 30, 45, 60, 90, 120, 180],
                label: fmtDuration,
                selected: (v) => v == _duration,
                onSelected: (v) => setState(() => _duration = v),
              ),
            ],
            if (parents.isNotEmpty) ...[
              const FieldLabel('تحت بطاقة (اختياري)'),
              Text(
                'يظهر داخل البطاقة الأب في «يومي» كعنصر فرعي.',
                style: TextStyle(color: c.muted, fontSize: 12),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        label: const Text('بدون'),
                        selected: _parent == null,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _parent = null),
                      ),
                    ),
                    for (final p in parents)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          label: Text('${p.title} · ${fmtTime(p.start)}'),
                          selected: _parent?.key == p.key,
                          showCheckmark: false,
                          onSelected: (_) => setState(() {
                            _parent = p;
                            _timed = true;
                            _start = p.start;
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (widget.kind == OneOffKind.period ||
                widget.kind == OneOffKind.event)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'الفترات والأحداث خارج نسبة الإنجاز.',
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
              ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'أضف', onPressed: canSave ? _save : null),
          ],
        ),
      ),
    );
  }

  bool _isChild(PlanItem i) {
    if (i.key.startsWith('once:friday-')) return true;
    if (i.oneOffId == null) return false;
    return ref
            .read(appDataProvider)
            .oneOffs
            .where((o) => o.id == i.oneOffId)
            .firstOrNull
            ?.parent !=
        null;
  }

  Future<void> _save() async {
    final isHabit = widget.kind == OneOffKind.habitSession;
    final isContact = widget.kind == OneOffKind.contact;
    final hc = _habit?.config as FlexConfig?;
    final timed = _timed || widget.kind == OneOffKind.reminder;
    final p = _person;
    final title = isHabit
        ? 'جلسة إضافية: ${hc!.title}'
        : isContact
        ? switch (_method) {
            'message' => 'أرسل لـ${p!.name}',
            'visit' => 'زيارة ${p!.name}',
            _ => 'اتصل بـ${p!.name}',
          }
        : _title.text.trim();
    final o = OneOff(
      id: newId(),
      kind: widget.kind,
      title: title,
      date: _date,
      start: timed ? _start : null,
      duration: _duration,
      window: _window,
      habitKey: _habit?.key,
      icon: isContact ? _method : null,
      personId: p?.id,
      note: isContact && _method == 'message'
          ? contactDraft(p!, timed ? _start : 17 * 60)
          : (isContact ? p!.relation.label : null),
      parent: _parent?.key,
    );
    final ctrl = ref.read(appDataProvider.notifier);
    await ctrl.addOneOff(o);
    if (!mounted) return;
    Navigator.pop(context);
    final plan = ref.read(dayPlanProvider(_date));
    final placed = plan.byKey(o.itemKey);
    if (widget.kind == OneOffKind.reminder) {
      toast(context, 'انضاف التذكير ${fmtTime(_start)}');
    } else if (placed != null) {
      final conflict = plan.conflicts.any(
        (c) => c.a.key == o.itemKey || c.b.key == o.itemKey,
      );
      toast(
        context,
        conflict
            ? 'انضافت، لكن تتعارض مع موعد ثابت'
            : 'انضافت ${fmtTime(placed.start)}',
      );
    } else {
      toast(context, 'ما لقت وقت فاضي في هذا اليوم');
    }
  }
}
