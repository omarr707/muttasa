import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';

/// «قبل 15 مارس» مع السنة إذا غير السنة الحالية.
String fmtDue(Day d, Day today) => nums(
  'قبل ${d.day} ${arabicMonths[d.month - 1]}${d.year != today.year ? ' ${d.year}' : ''}',
);

/// يفتح محرر الهدف. [goal] = null لهدف جديد.
Future<void> openGoalEditor(BuildContext context, {Goal? goal}) =>
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => GoalEditor(goal: goal),
      ),
    );

class GoalEditor extends ConsumerStatefulWidget {
  const GoalEditor({super.key, this.goal});
  final Goal? goal;
  @override
  ConsumerState<GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends ConsumerState<GoalEditor> {
  late final _title = TextEditingController(text: widget.goal?.title ?? '');
  late final _target = TextEditingController(
    text: widget.goal == null ? '' : '${widget.goal!.target}',
  );
  late final _unit = TextEditingController(text: widget.goal?.unit ?? 'مرة');
  late GoalMetric _metric = widget.goal?.metric ?? GoalMetric.books;
  late Day? _due = widget.goal?.due;
  late String? _link = widget.goal?.linkKey;
  int? _template;

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    _unit.dispose();
    super.dispose();
  }

  void _applyTemplate(int i, Day today) {
    final t = goalTemplates[i];
    setState(() {
      _template = i;
      _title.text = t.title;
      _target.text = '${t.target}';
      _metric = t.metric;
      _due = today.add(t.days);
      _link = t.linkKey;
      if (t.unit != null) _unit.text = t.unit!;
    });
  }

  int? get _targetValue => int.tryParse(_target.text.trim());

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final today = ref.watch(todayProvider);
    final engine = ref.watch(engineProvider);
    final currency = ref.watch(
      appDataProvider.select((d) => d.profile?.currency ?? 'ريال'),
    );
    final editing = widget.goal != null;
    final habits = engine
        .rulesOn(today, includePaused: true)
        .where(
          (r) =>
              r.config is FlexConfig &&
              (r.kind == RuleKind.habit || r.kind == RuleKind.quran),
        )
        .where(
          (r) =>
              _metric != GoalMetric.pages ||
              (r.config as FlexConfig).pages != null,
        )
        .toList();
    // العادة المختارة لم تعد متاحة؟ نختار الأولى.
    if (_metric.linkable &&
        _link != null &&
        !habits.any((r) => r.key == _link)) {
      _link = _metric == GoalMetric.books || habits.isEmpty
          ? null
          : habits.first.key;
    }
    final canSave =
        _title.text.trim().isNotEmpty &&
        (_targetValue ?? 0) > 0 &&
        (_metric != GoalMetric.pages && _metric != GoalMetric.sessions ||
            _link != null);

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'عدّل الهدف' : 'هدف جديد')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            if (!editing) ...[
              const FieldLabel('أفكار جاهزة'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < goalTemplates.length; i++)
                    ChoiceChip(
                      label: Text(nums(goalTemplates[i].title)),
                      selected: _template == i,
                      showCheckmark: false,
                      onSelected: (_) => _applyTemplate(i, today),
                    ),
                ],
              ),
            ],
            const FieldLabel('اسم الهدف'),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                hintText: 'مثلًا: أقرأ 12 كتاب هالسنة',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const FieldLabel('نقيسه بـ'),
            ChoiceChips<GoalMetric>(
              values: GoalMetric.pickable,
              label: (m) => m.label,
              selected: (m) => m == _metric,
              onSelected: (m) => setState(() {
                _metric = m;
                if (!m.linkable) _link = null;
                if (m.linkable && m != GoalMetric.books && _link == null) {
                  _link = habits.isEmpty ? null : habits.first.key;
                }
              }),
            ),
            const FieldLabel('الرقم المطلوب'),
            TextField(
              controller: _target,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                suffixText: _metric == GoalMetric.count
                    ? _unit.text
                    : (_metric == GoalMetric.money ? currency : _metric.unit),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_metric == GoalMetric.count) ...[
              const FieldLabel('الوحدة'),
              TextField(
                controller: _unit,
                decoration: const InputDecoration(hintText: 'حديث، دورة، مرة'),
                onChanged: (_) => setState(() {}),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('له موعد'),
              subtitle: Text(
                _due == null
                    ? 'بدون موعد نعرض كم باقي فقط'
                    : '${fmtDue(_due!, today)} · نقارن وين وصلت بوين المفروض تكون',
              ),
              value: _due != null,
              onChanged: (v) => setState(() => _due = v ? today.add(90) : null),
            ),
            if (_due != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: SmallButton(
                  icon: Icons.event_outlined,
                  label: fmtDayLong(_due!),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      firstDate: today.at(0),
                      lastDate: today.add(365 * 5).at(0),
                      initialDate: _due!.at(0),
                      helpText: 'موعد الهدف',
                    );
                    if (d != null) setState(() => _due = Day.fromDateTime(d));
                  },
                ),
              ),
            if (_metric.linkable) ...[
              const FieldLabel('العادة اللي تغذيه'),
              if (habits.isEmpty)
                Text(
                  _metric == GoalMetric.pages
                      ? 'أضف عادة فيها متابعة صفحات من «روتيني» ← المكتبة.'
                      : 'أضف عادة من «روتيني» ← المكتبة أولًا.',
                  style: TextStyle(color: c.warn),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_metric == GoalMetric.books)
                      ChoiceChip(
                        label: const Text('بدون'),
                        selected: _link == null,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _link = null),
                      ),
                    for (final r in habits)
                      ChoiceChip(
                        label: Text((r.config as FlexConfig).title),
                        selected: _link == r.key,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _link = r.key),
                      ),
                  ],
                ),
            ],
            const SizedBox(height: 12),
            Text(switch (_metric) {
              GoalMetric.pages =>
                'تنحسب الصفحات اللي تسجلها في جلسات العادة من اليوم.',
              GoalMetric.books =>
                'كل ما تخلص كتاب اضغط «+١». العادة تبيّن لك وين تقرأ.',
              GoalMetric.sessions => 'تنحسب كل جلسة «تمت» للعادة من اليوم.',
              GoalMetric.money =>
                'ينحسب مجموع ما سجّلته من ادخار، من بطاقة يوم الراتب أو يدويًا.',
              _ => 'تسجّله بنفسك من بطاقة الهدف.',
            }, style: T.meta.copyWith(color: c.muted, fontSize: 12.5)),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'احفظ',
              onPressed: canSave ? () => _save(today) : null,
            ),
            if (editing) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await ref
                      .read(appDataProvider.notifier)
                      .deleteGoal(widget.goal!.id);
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text('احذف الهدف', style: TextStyle(color: c.warn)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save(Day today) async {
    final old = widget.goal;
    final g = Goal(
      id: old?.id ?? newId(),
      title: _title.text.trim(),
      metric: _metric,
      target: _targetValue!,
      start: old?.start ?? today,
      due: _due,
      unit: _metric == GoalMetric.count && _unit.text.trim().isNotEmpty
          ? _unit.text.trim()
          : null,
      linkKey: _metric.linkable ? _link : null,
      entries: old?.entries ?? const [],
    );
    await ref.read(appDataProvider.notifier).saveGoal(g);
    if (mounted) Navigator.pop(context);
  }
}
