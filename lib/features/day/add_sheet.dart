import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';
import 'item_sheet.dart';

class _AddType {
  const _AddType(
    this.kind,
    this.title,
    this.desc,
    this.icon, {
    this.enabled = true,
  });
  final OneOffKind? kind;
  final String title;
  final String desc;
  final IconData icon;
  final bool enabled;
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
    null,
    'تواصل',
    'اتصال أو رسالة أو زيارة. في المرحلة الثانية',
    Icons.call_outlined,
    enabled: false,
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
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
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
                    Opacity(
                      opacity: t.enabled ? 1 : .45,
                      child: MCard(
                        onTap: t.enabled
                            ? () => Navigator.pop(ctx, t.kind)
                            : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(t.icon, color: c.ink),
                            const Spacer(),
                            Text(
                              t.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
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

  @override
  void initState() {
    super.initState();
    final now = ref.read(nowMinuteProvider);
    _start = ((now + 60) ~/ 30) * 30 % minutesPerDay;
    if (widget.kind == OneOffKind.period) _duration = 60;
    if (widget.kind == OneOffKind.event) _duration = 120;
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
    final canSave = isHabit ? _habit != null : _title.text.trim().isNotEmpty;

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
                fontWeight: FontWeight.w700,
                fontSize: 20,
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
                    '${arabicWeekdays[_date.weekday]} ${_date.day}/${_date.month}',
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
            if (widget.kind == OneOffKind.task || isHabit) ...[
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
            if (widget.kind == OneOffKind.period ||
                widget.kind == OneOffKind.event)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'الفترات والأحداث خارج نسبة الإنجاز.',
                  style: TextStyle(color: c.muted, fontSize: 12.5),
                ),
              ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'أضف', onPressed: canSave ? _save : null),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final isHabit = widget.kind == OneOffKind.habitSession;
    final hc = _habit?.config as FlexConfig?;
    final timed = _timed || widget.kind == OneOffKind.reminder;
    final o = OneOff(
      id: newId(),
      kind: widget.kind,
      title: isHabit ? 'جلسة إضافية: ${hc!.title}' : _title.text.trim(),
      date: _date,
      start: timed ? _start : null,
      duration: _duration,
      window: _window,
      habitKey: _habit?.key,
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
