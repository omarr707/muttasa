import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';

/// يفتح محرر القاعدة المناسب ويعيد الإعداد الجديد، أو null عند الإلغاء.
Future<RuleConfig?> editRuleConfig(
  BuildContext context,
  RuleConfig initial, {
  Set<int> weekend = const {5, 6},
}) {
  final Widget page = switch (initial) {
    WorkConfig() => _WorkEditor(initial: initial, weekend: weekend),
    KidConfig() => _KidEditor(initial: initial, weekend: weekend),
    ClassConfig() => _ClassEditor(initial: initial),
    FlexConfig() => _FlexEditor(initial: initial),
    PrayersConfig() => _PrayersEditor(initial: initial),
    AdhkarConfig() => _AdhkarEditor(initial: initial),
    RemindersConfig() => _RemindersEditor(initial: initial),
    SavingsConfig() => _SavingsEditor(initial: initial),
    HealthConfig() => _HealthEditor(initial: initial),
    MotherConfig() => _MotherEditor(initial: initial),
  };
  return Navigator.of(context).push<RuleConfig>(
    MaterialPageRoute(builder: (_) => page, fullscreenDialog: true),
  );
}

Set<int> workdays(Set<int> weekend) => {
  for (final d in weekOrder)
    if (!weekend.contains(d)) d,
};

class _EditorScaffold extends StatelessWidget {
  const _EditorScaffold({
    required this.title,
    required this.children,
    required this.onSave,
    this.canSave = true,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback onSave;
  final bool canSave;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          ...children,
          const SizedBox(height: 24),
          PrimaryButton(label: 'احفظ', onPressed: canSave ? onSave : null),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// الدوام: نمط جاهز، ولكل يوم فترة، والاستراحة فجوة متاحة.
// ---------------------------------------------------------------------------

class _WorkEditor extends StatefulWidget {
  const _WorkEditor({required this.initial, required this.weekend});
  final WorkConfig initial;
  final Set<int> weekend;
  @override
  State<_WorkEditor> createState() => _WorkEditorState();
}

class _WorkEditorState extends State<_WorkEditor> {
  late WorkPattern _pattern = widget.initial.pattern;
  late Map<int, WorkPeriod> _days = {
    for (final e in widget.initial.days.entries)
      if (e.value.isNotEmpty) e.key: e.value.first,
  };
  late bool _same =
      _days.values.map((p) => '${p.start}-${p.end}').toSet().length <= 1;
  late WorkPeriod _base =
      _days.values.firstOrNull ??
      const WorkPeriod(450, 960, breakStart: 720, breakEnd: 750);
  late bool _break = _base.hasBreak;

  void _applyPattern(WorkPattern p) {
    final base = switch (p) {
      WorkPattern.morning => const WorkPeriod(
        450,
        960,
        breakStart: 720,
        breakEnd: 750,
      ),
      WorkPattern.evening => const WorkPeriod(
        14 * 60,
        22 * 60,
        breakStart: 18 * 60,
        breakEnd: 18 * 60 + 30,
      ),
      WorkPattern.night => const WorkPeriod(22 * 60, 6 * 60),
      WorkPattern.custom => _base,
    };
    setState(() {
      _pattern = p;
      _base = base;
      _break = base.hasBreak;
      final ds = _days.isEmpty ? workdays(widget.weekend) : _days.keys.toSet();
      _days = {for (final d in ds) d: base};
      _same = true;
    });
  }

  WorkPeriod _withBreak(WorkPeriod p) => WorkPeriod(
    p.start,
    p.end,
    breakStart: _break ? (_base.breakStart ?? p.start + 240) : null,
    breakEnd: _break ? (_base.breakEnd ?? p.start + 270) : null,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _EditorScaffold(
      title: 'الدوام',
      canSave: _days.isNotEmpty,
      onSave: () => Navigator.pop(
        context,
        WorkConfig(
          title: widget.initial.title,
          pattern: _pattern,
          days: {
            for (final e in _days.entries)
              e.key: [_withBreak(_same ? _base : e.value)],
          },
        ),
      ),
      children: [
        const FieldLabel('النمط'),
        ChoiceChips<WorkPattern>(
          values: WorkPattern.values,
          label: (p) => p.label,
          selected: (p) => p == _pattern,
          onSelected: _applyPattern,
        ),
        const FieldLabel('أيام الدوام'),
        WeekdayPicker(
          selected: _days.keys.toSet(),
          onChanged: (s) =>
              setState(() => _days = {for (final d in s) d: _days[d] ?? _base}),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('نفس الوقت لكل الأيام'),
          value: _same,
          onChanged: (v) => setState(() {
            _same = v;
            _pattern = WorkPattern.custom;
          }),
        ),
        if (_same) ...[
          TimeField(
            label: 'البداية',
            value: _base.start,
            onChanged: (v) => setState(
              () => _base = WorkPeriod(
                v,
                _base.end,
                breakStart: _base.breakStart,
                breakEnd: _base.breakEnd,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TimeField(
            label: 'النهاية',
            value: _base.end,
            onChanged: (v) => setState(
              () => _base = WorkPeriod(
                _base.start,
                v,
                breakStart: _base.breakStart,
                breakEnd: _base.breakEnd,
              ),
            ),
          ),
        ] else
          for (final d in weekOrder.where(_days.containsKey)) ...[
            FieldLabel(arabicWeekdays[d]!),
            Row(
              children: [
                Expanded(
                  child: TimeField(
                    label: 'من',
                    value: _days[d]!.start,
                    onChanged: (v) =>
                        setState(() => _days[d] = WorkPeriod(v, _days[d]!.end)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TimeField(
                    label: 'إلى',
                    value: _days[d]!.end,
                    onChanged: (v) => setState(
                      () => _days[d] = WorkPeriod(_days[d]!.start, v),
                    ),
                  ),
                ),
              ],
            ),
          ],
        if ((_same ? _base : _days.values.firstOrNull)?.crossesMidnight ??
            false)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'الوردية تعبر منتصف الليل. ننام بعدها 7 ساعات تبدأ بعد نصف ساعة من نهايتها.',
              style: TextStyle(color: c.ink2, fontSize: 12.5),
            ),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('استراحة'),
          subtitle: const Text('فجوة متاحة داخل الدوام، نحط فيها أشياء قصيرة'),
          value: _break,
          onChanged: (v) => setState(() {
            _break = v;
            if (v && !_base.hasBreak) {
              _base = WorkPeriod(
                _base.start,
                _base.end,
                breakStart: _base.start + 270,
                breakEnd: _base.start + 300,
              );
            }
          }),
        ),
        if (_break)
          Row(
            children: [
              Expanded(
                child: TimeField(
                  label: 'من',
                  value: _base.breakStart ?? 720,
                  onChanged: (v) => setState(
                    () => _base = WorkPeriod(
                      _base.start,
                      _base.end,
                      breakStart: v,
                      breakEnd: _base.breakEnd ?? v + 30,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TimeField(
                  label: 'إلى',
                  value: _base.breakEnd ?? 750,
                  onChanged: (v) => setState(
                    () => _base = WorkPeriod(
                      _base.start,
                      _base.end,
                      breakStart: _base.breakStart,
                      breakEnd: v,
                    ),
                  ),
                ),
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            'الدوام يحجز الوقت فقط. الحضور اختياري وخارج نسبة الإنجاز.',
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// توصيل واستلام
// ---------------------------------------------------------------------------

class _KidEditor extends StatefulWidget {
  const _KidEditor({required this.initial, required this.weekend});
  final KidConfig initial;
  final Set<int> weekend;
  @override
  State<_KidEditor> createState() => _KidEditorState();
}

class _KidEditorState extends State<_KidEditor> {
  late final _name = TextEditingController(text: widget.initial.child);
  late final _place = TextEditingController(text: widget.initial.place ?? '');
  late Set<int> _days = widget.initial.days.isEmpty
      ? workdays(widget.weekend)
      : widget.initial.days.keys.toSet();
  late int? _drop =
      widget.initial.days.values.firstOrNull?.drop ??
      (widget.initial.days.isEmpty ? 6 * 60 + 45 : null);
  late int? _pick =
      widget.initial.days.values.firstOrNull?.pick ??
      (widget.initial.days.isEmpty ? 13 * 60 : null);
  late int _trip = widget.initial.trip;

  @override
  void dispose() {
    _name.dispose();
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _EditorScaffold(
    title: 'توصيل واستلام',
    canSave:
        _name.text.trim().isNotEmpty &&
        _days.isNotEmpty &&
        (_drop != null || _pick != null),
    onSave: () => Navigator.pop(
      context,
      KidConfig(
        child: _name.text.trim(),
        place: _place.text.trim().isEmpty ? null : _place.text.trim(),
        trip: _trip,
        days: {for (final d in _days) d: KidDay(drop: _drop, pick: _pick)},
      ),
    ),
    children: [
      const FieldLabel('اسم الطفل'),
      TextField(
        controller: _name,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(hintText: 'مثل: سلمى'),
      ),
      const FieldLabel('المدرسة أو المكان (اختياري)'),
      TextField(controller: _place),
      const FieldLabel('الأيام'),
      WeekdayPicker(
        selected: _days,
        onChanged: (s) => setState(() => _days = s),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('التوصيل'),
        value: _drop != null,
        onChanged: (v) => setState(() => _drop = v ? 6 * 60 + 45 : null),
      ),
      if (_drop != null)
        TimeField(
          label: 'وقت التوصيل',
          value: _drop!,
          onChanged: (v) => setState(() => _drop = v),
        ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('الاستلام'),
        value: _pick != null,
        onChanged: (v) => setState(() => _pick = v ? 13 * 60 : null),
      ),
      if (_pick != null)
        TimeField(
          label: 'وقت الاستلام',
          value: _pick!,
          onChanged: (v) => setState(() => _pick = v),
        ),
      const FieldLabel('مدة المشوار'),
      ChoiceChips<int>(
        values: const [10, 15, 20, 30, 45],
        label: fmtDuration,
        selected: (v) => v == _trip,
        onSelected: (v) => setState(() => _trip = v),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// حصة أو نادٍ أو دورة
// ---------------------------------------------------------------------------

class _ClassEditor extends StatefulWidget {
  const _ClassEditor({required this.initial});
  final ClassConfig initial;
  @override
  State<_ClassEditor> createState() => _ClassEditorState();
}

class _ClassEditorState extends State<_ClassEditor> {
  late final _title = TextEditingController(text: widget.initial.title);
  late final _who = TextEditingController(text: widget.initial.who);
  late final _place = TextEditingController(text: widget.initial.place ?? '');
  late CommitmentType _type = widget.initial.type;
  late Set<int> _days = widget.initial.slots.isNotEmpty
      ? widget.initial.slots.keys.toSet()
      : widget.initial.weekdays;
  late int _start = widget.initial.start;
  late int _end = widget.initial.end;

  /// «نفس الوقت كل الأيام» أو فترات لكل يوم (ولو أكثر من فترة).
  late bool _same = widget.initial.slots.isEmpty;
  late final Map<int, List<Slot>> _slots = {
    for (final e in widget.initial.slots.entries) e.key: [...e.value],
  };

  @override
  void dispose() {
    _title.dispose();
    _who.dispose();
    _place.dispose();
    super.dispose();
  }

  List<Slot> _daySlots(int d) => _slots[d] ??= [Slot(_start, _end)];

  bool get _valid {
    if (_title.text.trim().isEmpty || _days.isEmpty) return false;
    if (_same) return _end > _start;
    return _days.every((d) => _daySlots(d).every((s) => s.end > s.start));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _EditorScaffold(
      title: 'التزام',
      canSave: _valid,
      onSave: () => Navigator.pop(
        context,
        ClassConfig(
          title: _title.text.trim(),
          who: _who.text.trim().isEmpty ? 'أنا' : _who.text.trim(),
          weekdays: _days,
          start: _same ? _start : _daySlots(_days.first).first.start,
          end: _same ? _end : _daySlots(_days.first).first.end,
          place: _place.text.trim().isEmpty ? null : _place.text.trim(),
          type: _type,
          slots: _same
              ? const {}
              : {
                  for (final d in _days)
                    d: ([..._daySlots(d)]
                      ..sort((a, b) => a.start.compareTo(b.start))),
                },
        ),
      ),
      children: [
        const FieldLabel('النوع'),
        ChoiceChips<CommitmentType>(
          values: CommitmentType.values,
          label: (t) => t.label,
          selected: (t) => t == _type,
          onSelected: (t) => setState(() {
            final wasDefault =
                _title.text.trim().isEmpty ||
                CommitmentType.values.any(
                  (x) => x.defaultTitle == _title.text.trim(),
                );
            _type = t;
            if (wasDefault) _title.text = t.defaultTitle;
          }),
        ),
        const FieldLabel('الاسم'),
        TextField(
          controller: _title,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'مثل: محاضرات الجامعة، نادي، دورة إنجليزي',
          ),
        ),
        const FieldLabel('لمن؟'),
        TextField(
          controller: _who,
          decoration: const InputDecoration(hintText: 'أنا، أو اسم الطفل'),
        ),
        const FieldLabel('المكان أو الرابط (اختياري)'),
        TextField(controller: _place),
        const FieldLabel('الأيام'),
        WeekdayPicker(
          selected: _days,
          onChanged: (s) => setState(() => _days = s),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('نفس الوقت كل الأيام'),
          subtitle: const Text('أطفها لو كل يوم له وقت، أو فيه أكثر من فترة'),
          value: _same,
          onChanged: (v) => setState(() => _same = v),
        ),
        if (_same) ...[
          TimeField(
            label: 'البداية',
            value: _start,
            onChanged: (v) => setState(() => _start = v),
          ),
          const SizedBox(height: 8),
          TimeField(
            label: 'النهاية',
            value: _end,
            onChanged: (v) => setState(() => _end = v),
          ),
        ] else
          for (final d in weekOrder.where(_days.contains)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                arabicWeekdays[d]!,
                style: T.label.copyWith(color: c.muted),
              ),
            ),
            for (var k = 0; k < _daySlots(d).length; k++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TimeField(
                        label: 'من',
                        value: _daySlots(d)[k].start,
                        onChanged: (v) => setState(
                          () => _slots[d]![k] = Slot(v, _slots[d]![k].end),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TimeField(
                        label: 'إلى',
                        value: _daySlots(d)[k].end,
                        onChanged: (v) => setState(
                          () => _slots[d]![k] = Slot(_slots[d]![k].start, v),
                        ),
                      ),
                    ),
                    if (k > 0)
                      IconButton(
                        tooltip: 'احذف الفترة',
                        onPressed: () => setState(() => _slots[d]!.removeAt(k)),
                        icon: Icon(Icons.close, color: c.muted),
                      ),
                  ],
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  final last = _daySlots(d).last;
                  _slots[d]!.add(
                    Slot(last.end + 15, (last.end + 75).clamp(0, 1439)),
                  );
                }),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('فترة ثانية'),
              ),
            ),
          ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// عادة أو ورد أو وجبة
// ---------------------------------------------------------------------------

enum _RecType { daily, weekdays, perWeek }

class _FlexEditor extends StatefulWidget {
  const _FlexEditor({required this.initial});
  final FlexConfig initial;
  @override
  State<_FlexEditor> createState() => _FlexEditorState();
}

class _FlexEditorState extends State<_FlexEditor> {
  late final _title = TextEditingController(text: widget.initial.title);
  late final _book = TextEditingController(text: widget.initial.book ?? '');
  late int _duration = widget.initial.duration;
  late _RecType _rec = switch (widget.initial.recurrence) {
    Weekdays() => _RecType.weekdays,
    TimesPerWeek() => _RecType.perWeek,
    _ => _RecType.daily,
  };
  late Set<int> _days = switch (widget.initial.recurrence) {
    Weekdays(:final days) => days,
    _ => {...weekOrder},
  };
  late int _n = switch (widget.initial.recurrence) {
    TimesPerWeek(:final n) => n,
    _ => 3,
  };
  late int _perDay = widget.initial.perDay;
  late final List<Window> _windows = [...widget.initial.windows];
  late int? _preferred = widget.initial.preferred;
  late TrackMode _track = widget.initial.track;
  late bool _optional = widget.initial.optional;
  late int? _pages = widget.initial.pages;
  late int _startPage = widget.initial.startPage ?? 1;
  late String _icon = widget.initial.icon;
  late Day? _khatmaBy = widget.initial.khatmaBy;

  @override
  void dispose() {
    _title.dispose();
    _book.dispose();
    super.dispose();
  }

  Window _w(int i) =>
      _windows.isEmpty ? Window.any : _windows[i.clamp(0, _windows.length - 1)];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isMeal = widget.initial.kind == RuleKind.meal;
    final isQuran = widget.initial.kind == RuleKind.quran;
    return _EditorScaffold(
      title: _title.text.isEmpty ? 'عادة جديدة' : _title.text,
      canSave:
          _title.text.trim().isNotEmpty &&
          (_rec != _RecType.weekdays || _days.isNotEmpty),
      onSave: () => Navigator.pop(
        context,
        FlexConfig(
          kind: widget.initial.kind,
          title: _title.text.trim(),
          subtitle: widget.initial.subtitle,
          icon: _icon,
          recurrence: switch (_rec) {
            _RecType.daily => const Daily(),
            _RecType.weekdays => Weekdays(_days),
            _RecType.perWeek => TimesPerWeek(_n),
          },
          duration: _duration,
          windows: [for (var i = 0; i < _perDay; i++) _w(i)],
          preferred: _preferred,
          perDay: _perDay,
          track: _track,
          optional: _optional,
          counted: widget.initial.counted,
          category: widget.initial.category,
          pages: _pages,
          book: _pages == null
              ? null
              : (_book.text.trim().isEmpty ? null : _book.text.trim()),
          startPage: _pages == null ? null : _startPage,
          khatmaBy: isQuran && _pages != null ? _khatmaBy : null,
        ),
      ),
      children: [
        const FieldLabel('الاسم'),
        TextField(controller: _title, onChanged: (_) => setState(() {})),
        if (!isMeal && !isQuran) ...[
          const FieldLabel('الأيقونة'),
          Wrap(
            spacing: 6,
            children: [
              for (final ic in pickableIcons)
                IconButton.filledTonal(
                  isSelected: ic == _icon,
                  onPressed: () => setState(() => _icon = ic),
                  icon: Icon(iconFor(ic)),
                ),
            ],
          ),
        ],
        const FieldLabel('التكرار'),
        ChoiceChips<_RecType>(
          values: _RecType.values,
          label: (r) => switch (r) {
            _RecType.daily => 'كل يوم',
            _RecType.weekdays => 'أيام محددة',
            _RecType.perWeek => 'عدد بالأسبوع',
          },
          selected: (r) => r == _rec,
          onSelected: (r) => setState(() => _rec = r),
        ),
        if (_rec == _RecType.weekdays) ...[
          const SizedBox(height: 8),
          WeekdayPicker(
            selected: _days,
            onChanged: (s) => setState(() => _days = s),
          ),
        ],
        if (_rec == _RecType.perWeek) ...[
          const SizedBox(height: 8),
          ChoiceChips<int>(
            values: const [1, 2, 3, 4, 5, 6],
            label: (n) => '$n',
            selected: (n) => n == _n,
            onSelected: (n) => setState(() => _n = n),
          ),
          Text(
            'نوزّعها على الأسبوع ونختار الأيام اللي فيها مكان.',
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
        ],
        const FieldLabel('مدة الجلسة'),
        ChoiceChips<int>(
          values: const [5, 10, 15, 20, 25, 30, 45, 60, 90],
          label: fmtDuration,
          selected: (v) => v == _duration,
          onSelected: (v) => setState(() => _duration = v),
        ),
        if (!isMeal) ...[
          const FieldLabel('جلسات باليوم'),
          ChoiceChips<int>(
            values: const [1, 2, 3],
            label: (n) => '$n',
            selected: (n) => n == _perDay,
            onSelected: (n) => setState(() => _perDay = n),
          ),
        ],
        for (var i = 0; i < _perDay; i++) ...[
          FieldLabel(_perDay == 1 ? 'الفترة المفضلة' : 'فترة الجلسة ${i + 1}'),
          ChoiceChips<Window>(
            values: Window.values,
            label: (w) => w.label,
            selected: (w) => w == _w(i),
            onSelected: (w) => setState(() {
              while (_windows.length <= i) {
                _windows.add(_windows.isEmpty ? Window.any : _windows.last);
              }
              _windows[i] = w;
            }),
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('وقت مفضل'),
          subtitle: Text(
            _preferred == null
                ? 'نختار أول وقت فاضي داخل الفترة'
                : 'نبدأ البحث من ${fmtTime(_preferred!)}',
          ),
          value: _preferred != null,
          onChanged: (v) => setState(() => _preferred = v ? 17 * 60 : null),
        ),
        if (_preferred != null)
          TimeField(
            label: 'الوقت المفضل',
            value: _preferred!,
            onChanged: (v) => setState(() => _preferred = v),
          ),
        if (!isMeal) ...[
          const FieldLabel('طريقة التسجيل'),
          ChoiceChips<TrackMode>(
            values: const [
              TrackMode.confirm,
              TrackMode.start,
              TrackMode.autocount,
            ],
            label: (t) => switch (t) {
              TrackMode.confirm => 'تأكيد سريع',
              TrackMode.start => 'مؤقت «ابدأ»',
              _ => 'تُحسب ما لم أستثنها',
            },
            selected: (t) => t == _track,
            onSelected: (t) => setState(() => _track = t),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('وقت اختياري'),
            subtitle: const Text(
              'يدخل في الحد اليومي للوقت الاختياري، فلا يزدحم يومك',
            ),
            value: _optional,
            onChanged: (v) => setState(() => _optional = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('أتابع الصفحات'),
            value: _pages != null,
            onChanged: (v) =>
                setState(() => _pages = v ? (isQuran ? 4 : 20) : null),
          ),
          if (_pages != null && isQuran) ...[
            const FieldLabel('النوع'),
            ChoiceChips<bool>(
              values: const [false, true],
              label: (k) => k ? 'ختمة بموعد' : 'ورد ثابت',
              selected: (k) => k == (_khatmaBy != null),
              onSelected: (k) => setState(
                () => _khatmaBy = k
                    ? (_khatmaBy ?? Day.fromDateTime(DateTime.now()).add(60))
                    : null,
              ),
            ),
            if (_khatmaBy != null) ...[
              const FieldLabel('أختم قبل'),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: SmallButton(
                  icon: Icons.event_outlined,
                  label: fmtDayLong(_khatmaBy!),
                  onTap: () async {
                    final today = Day.fromDateTime(DateTime.now());
                    final d = await showDatePicker(
                      context: context,
                      firstDate: today.next.at(0),
                      lastDate: today.add(800).at(0),
                      initialDate: _khatmaBy!.at(0),
                      helpText: 'موعد الختمة',
                    );
                    if (d != null) {
                      setState(() => _khatmaBy = Day.fromDateTime(d));
                    }
                  },
                ),
              ),
              const SizedBox(height: 6),
              Text(
                nums(
                  'نقسم المتبقي من ${604 - _startPage + 1} صفحة على أيام القراءة، ونعيد الحساب كل ما سجّلت.',
                ),
                style: TextStyle(color: c.muted, fontSize: 12),
              ),
            ],
          ],
          if (_pages != null && _khatmaBy == null) ...[
            const FieldLabel('صفحات اليوم'),
            ChoiceChips<int>(
              values: isQuran
                  ? const [1, 2, 4, 6, 10, 20]
                  : const [5, 10, 20, 30, 50],
              label: (n) => '$n',
              selected: (n) => n == _pages,
              onSelected: (n) => setState(() => _pages = n),
            ),
            if (!isQuran) ...[
              const FieldLabel('اسم الكتاب'),
              TextField(
                controller: _book,
                decoration: const InputDecoration(hintText: 'كتابك الحالي'),
              ),
            ],
            const FieldLabel('أبدأ من صفحة'),
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _startPage++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                Text(
                  '$_startPage',
                  style: const TextStyle(fontFamily: fontDisplay, fontSize: 17),
                ),
                IconButton(
                  onPressed: _startPage > 1
                      ? () => setState(() => _startPage--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _PrayersEditor extends ConsumerStatefulWidget {
  const _PrayersEditor({required this.initial});
  final PrayersConfig initial;
  @override
  ConsumerState<_PrayersEditor> createState() => _PrayersEditorState();
}

class _PrayersEditorState extends ConsumerState<_PrayersEditor> {
  late final _place = TextEditingController(text: widget.initial.place);
  late TrackMode _track = widget.initial.track;
  late final Set<String> _sunnah = widget.initial.sunnah.toSet();
  static const _all = ['fajr', 'dhuhr', 'maghrib', 'isha', 'witr'];
  static const _labels = {
    'fajr': ('سنة الفجر', 'ركعتان قبل الصلاة'),
    'dhuhr': ('سنة الظهر', 'أربع قبلها وركعتان بعدها، وسنة الجمعة يوم الجمعة'),
    'maghrib': ('سنة المغرب', 'ركعتان بعد الصلاة'),
    'isha': ('سنة العشاء', 'ركعتان بعد الصلاة'),
    'witr': ('الوتر', 'داخل بطاقة العشاء'),
  };

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final today = ref.watch(todayProvider);
    final pr = ref.watch(engineProvider).prayersFor(today);
    final friday = today.weekday == DateTime.friday;
    final times = [
      ('الفجر', pr.fajr),
      ('الشروق', pr.sunrise),
      (friday ? 'الجمعة' : 'الظهر', pr.dhuhr),
      ('العصر', pr.asr),
      ('المغرب', pr.maghrib),
      ('العشاء', pr.isha),
    ];
    return _EditorScaffold(
      title: 'الصلوات',
      onSave: () => Navigator.pop(
        context,
        PrayersConfig(
          place: _place.text.trim(),
          track: _track,
          sunnah: [
            for (final k in _all)
              if (_sunnah.contains(k)) k,
          ],
        ),
      ),
      children: [
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.9,
          children: [
            for (final (n, m) in times)
              Container(
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.line),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(n, style: TextStyle(fontSize: 12, color: c.muted)),
                    Text(
                      fmtTime(m),
                      style: const TextStyle(
                        fontFamily: fontDisplay,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'مواقيت اليوم. طريقة الحساب والمدينة من الإعدادات ← الإسلام.',
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
        ),
        const FieldLabel('السنن الرواتب'),
        Text(
          'تظهر داخل بطاقة الصلاة نفسها كبنود فرعية تأكدها منها، ولا تدخل في نسبة الإنجاز.',
          style: TextStyle(color: c.ink2, fontSize: 12.5),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('فعّل السنن الرواتب'),
          value: _sunnah.isNotEmpty,
          onChanged: (v) => setState(() {
            _sunnah.clear();
            if (v) _sunnah.addAll(_all.where((k) => k != 'witr'));
          }),
        ),
        if (_sunnah.isNotEmpty)
          for (final k in _all)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(_labels[k]!.$1),
              subtitle: Text(_labels[k]!.$2),
              value: _sunnah.contains(k),
              onChanged: (v) => setState(
                () => v == true ? _sunnah.add(k) : _sunnah.remove(k),
              ),
            ),
        const FieldLabel('وين تصلي عادة؟ (اختياري)'),
        TextField(controller: _place),
        const FieldLabel('طريقة التسجيل'),
        ChoiceChips<TrackMode>(
          values: const [TrackMode.confirm, TrackMode.autocount],
          label: (t) =>
              t == TrackMode.confirm ? 'تأكيد سريع' : 'تُحسب ما لم أستثنها',
          selected: (t) => t == _track,
          onSelected: (t) => setState(() => _track = t),
        ),
      ],
    );
  }
}

class _AdhkarEditor extends StatefulWidget {
  const _AdhkarEditor({required this.initial});
  final AdhkarConfig initial;
  @override
  State<_AdhkarEditor> createState() => _AdhkarEditorState();
}

class _AdhkarEditorState extends State<_AdhkarEditor> {
  late bool _m = widget.initial.morning;
  late bool _e = widget.initial.evening;
  late int _min = widget.initial.minutes;
  @override
  Widget build(BuildContext context) => _EditorScaffold(
    title: 'الأذكار',
    canSave: _m || _e,
    onSave: () => Navigator.pop(
      context,
      AdhkarConfig(morning: _m, evening: _e, minutes: _min),
    ),
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('أذكار الصباح'),
        subtitle: const Text('بعد الفجر'),
        value: _m,
        onChanged: (v) => setState(() => _m = v),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('أذكار المساء'),
        subtitle: const Text('بعد المغرب'),
        value: _e,
        onChanged: (v) => setState(() => _e = v),
      ),
      const FieldLabel('المدة'),
      ChoiceChips<int>(
        values: const [5, 10, 15, 20],
        label: fmtDuration,
        selected: (v) => v == _min,
        onSelected: (v) => setState(() => _min = v),
      ),
    ],
  );
}

class _RemindersEditor extends StatefulWidget {
  const _RemindersEditor({required this.initial});
  final RemindersConfig initial;
  @override
  State<_RemindersEditor> createState() => _RemindersEditorState();
}

/// الماء والحركة والتنفّس: لكل عادة أيامها وعدد تذكيراتها، منفصلة عن الدوام.
class _RemindersEditorState extends State<_RemindersEditor> {
  late RemindersConfig _c = widget.initial;

  void _set(RemindersConfig c) => setState(() => _c = c);

  Widget _section(String title, String sub, bool on, ValueChanged<bool> f) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: T.cardTitle),
        subtitle: Text(sub),
        value: on,
        onChanged: f,
      );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(t, style: T.label.copyWith(color: c.muted)),
    );
    return _EditorScaffold(
      title: 'الماء والحركة والتنفّس',
      onSave: () => Navigator.pop(context, _c),
      children: [
        Text(
          'تظهر كل يوم تختاره، في الدوام والإجازة، وأوقاتها تتماشى مع يومك. ما تنحسب في الإنجاز.',
          style: TextStyle(color: c.ink2),
        ),
        const SizedBox(height: 8),
        _section(
          'الماء',
          'أكواب الشرب فقط',
          _c.water,
          (v) => _set(_c.copyWith(water: v)),
        ),
        if (_c.water) ...[
          label('هدفك اليومي'),
          ChoiceChips<int>(
            values: const [4, 6, 8, 10, 12],
            label: (n) => nums('$n أكواب'),
            selected: (n) => n == _c.cups,
            onSelected: (n) => _set(_c.copyWith(cups: n)),
          ),
          label('كم تذكير؟'),
          ChoiceChips<int?>(
            values: const [null, 2, 4, 6],
            label: (n) => n == null ? 'بعدد الأكواب' : nums('$n'),
            selected: (n) => n == _c.waterAlerts,
            onSelected: (n) => _set(
              n == null
                  ? _c.copyWith(clearAlerts: true)
                  : _c.copyWith(waterAlerts: n),
            ),
          ),
          label('الأيام'),
          WeekdayPicker(
            selected: _c.waterDays,
            onChanged: (d) => _set(_c.copyWith(waterDays: d)),
          ),
        ],
        const Divider(height: 28),
        _section(
          'تمرين حركة قصير',
          'دقيقتين حركة خفيفة تكسر الجلوس',
          _c.stand,
          (v) => _set(_c.copyWith(stand: v)),
        ),
        if (_c.stand) ...[
          label('كل كم؟'),
          ChoiceChips<int>(
            values: const [60, 90, 120, 180],
            label: (m) => 'كل ${fmtDuration(m)}',
            selected: (m) => m == _c.standEvery,
            onSelected: (m) => _set(_c.copyWith(standEvery: m)),
          ),
          label('الأيام'),
          WeekdayPicker(
            selected: _c.standDays,
            onChanged: (d) => _set(_c.copyWith(standDays: d)),
          ),
        ],
        const Divider(height: 28),
        _section(
          'التنفّس',
          'جلسة هادئة تتبع فيها الزهرة',
          _c.breathe,
          (v) => _set(_c.copyWith(breathe: v)),
        ),
        if (_c.breathe) ...[
          label('متى؟ (تقدر تختار أكثر من وقت)'),
          ChoiceChips<BreatheSlot>(
            values: BreatheSlot.values,
            label: (b) => b.label,
            selected: _c.breatheSlots.contains,
            onSelected: (b) {
              final next = _c.breatheSlots.contains(b)
                  ? ({..._c.breatheSlots}..remove(b))
                  : {..._c.breatheSlots, b};
              if (next.isNotEmpty) _set(_c.copyWith(breatheSlots: next));
            },
          ),
          label('مدة الجلسة'),
          ChoiceChips<int>(
            values: const [1, 3, 5],
            label: (m) => fmtDuration(m),
            selected: (m) => m == _c.breatheMinutes,
            onSelected: (m) => _set(_c.copyWith(breatheMinutes: m)),
          ),
          label('الأيام'),
          WeekdayPicker(
            selected: _c.breatheDays,
            onChanged: (d) => _set(_c.copyWith(breatheDays: d)),
          ),
        ],
      ],
    );
  }
}

class _SavingsEditor extends StatefulWidget {
  const _SavingsEditor({required this.initial});
  final SavingsConfig initial;
  @override
  State<_SavingsEditor> createState() => _SavingsEditorState();
}

class _SavingsEditorState extends State<_SavingsEditor> {
  late int _payDay = widget.initial.payDay;
  late int _monthly = widget.initial.monthly;
  late int? _target = widget.initial.target;
  late Day? _by = widget.initial.targetBy;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _EditorScaffold(
      title: 'الادخار',
      onSave: () => Navigator.pop(
        context,
        SavingsConfig(
          payDay: _payDay,
          monthly: _monthly,
          target: _target,
          targetBy: _target == null ? null : _by,
        ),
      ),
      children: [
        Text(
          'نذكّرك يوم الراتب تحط المبلغ على جنب، وتسجّل كم ادّخرت بنفسك. ما نربط حسابك البنكي ولا نعطي نصائح استثمار.',
          style: TextStyle(color: c.ink2),
        ),
        const FieldLabel('يوم الراتب من الشهر'),
        ChoiceChips<int>(
          values: const [1, 10, 15, 25, 26, 27, 28, 31],
          label: (d) => d == 31 ? nums('آخر يوم') : nums('$d'),
          selected: (d) => d == _payDay,
          onSelected: (d) => setState(() => _payDay = d),
        ),
        const FieldLabel('المبلغ الشهري'),
        ChoiceChips<int>(
          values: const [200, 300, 500, 1000, 2000, 3000],
          label: (v) => nums(fmtThousands(v)),
          selected: (v) => v == _monthly,
          onSelected: (v) => setState(() => _monthly = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('هدف ادخار'),
          subtitle: const Text('يظهر في «أهدافي» مع حالته'),
          value: _target != null,
          onChanged: (v) => setState(() => _target = v ? 10000 : null),
        ),
        if (_target != null) ...[
          ChoiceChips<int>(
            values: const [5000, 10000, 20000, 50000],
            label: (v) => nums(fmtThousands(v)),
            selected: (v) => v == _target,
            onSelected: (v) => setState(() => _target = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('بموعد'),
            value: _by != null,
            onChanged: (v) => setState(
              () => _by = v ? Day.fromDateTime(DateTime.now()).add(365) : null,
            ),
          ),
          if (_by != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SmallButton(
                icon: Icons.event_outlined,
                label: fmtDayLong(_by!),
                onTap: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: context,
                    firstDate: now,
                    lastDate: DateTime(now.year + 10),
                    initialDate: _by!.at(0),
                  );
                  if (d != null) setState(() => _by = Day.fromDateTime(d));
                },
              ),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// صحتي والحمل والطفل: تذكير وتسجيل فقط، بلا نصائح علاجية.
// ---------------------------------------------------------------------------

class _Disclaimer extends StatelessWidget {
  const _Disclaimer(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.amberSoft,
        borderRadius: BorderRadius.circular(R.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: c.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: T.meta.copyWith(color: c.ink)),
          ),
        ],
      ),
    );
  }
}

class _HealthEditor extends StatefulWidget {
  const _HealthEditor({required this.initial});
  final HealthConfig initial;
  @override
  State<_HealthEditor> createState() => _HealthEditorState();
}

class _HealthEditorState extends State<_HealthEditor> {
  late final List<HealthCheck> _checks = [...widget.initial.checks];

  Future<void> _edit([int? index]) async {
    final cur = index == null ? null : _checks[index];
    final res = await showModalBottomSheet<HealthCheck>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      builder: (_) => _HealthCheckSheet(initial: cur),
    );
    if (res == null) return;
    setState(() {
      if (index == null) {
        _checks.add(res);
      } else {
        _checks[index] = res;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _EditorScaffold(
      title: 'صحتي',
      onSave: () => Navigator.pop(context, HealthConfig(checks: [..._checks])),
      children: [
        const _Disclaimer(
          'التطبيق يذكّرك ويسجّل قراءاتك فقط، وما يعطي نصيحة طبية. أوقات القياس والدواء حسب كلام طبيبك.',
        ),
        for (var k = 0; k < _checks.length; k++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MCard(
              onTap: () => _edit(k),
              child: Row(
                children: [
                  Icon(iconFor(_checks[k].kind.icon), color: c.ink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_checks[k].title, style: T.cardTitle),
                        Text(
                          nums(
                            [
                              ..._checks[k].times.map(fmtTime),
                              fmtWeekdays(_checks[k].days),
                            ].join(' · '),
                          ),
                          style: T.meta.copyWith(color: c.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'احذف',
                    onPressed: () => setState(() => _checks.removeAt(k)),
                    icon: Icon(Icons.delete_outline, color: c.muted),
                  ),
                ],
              ),
            ),
          ),
        PillButton(
          label: '+ أضف متابعة',
          soft: true,
          expand: true,
          onPressed: () => _edit(),
        ),
      ],
    );
  }
}

class _HealthCheckSheet extends StatefulWidget {
  const _HealthCheckSheet({this.initial});
  final HealthCheck? initial;
  @override
  State<_HealthCheckSheet> createState() => _HealthCheckSheetState();
}

class _HealthCheckSheetState extends State<_HealthCheckSheet> {
  late HealthCheckKind _kind = widget.initial?.kind ?? HealthCheckKind.glucose;
  late final _title = TextEditingController(
    text: widget.initial?.title ?? HealthCheckKind.glucose.label,
  );
  late List<int> _times = [...?widget.initial?.times];
  late Set<int> _days = widget.initial?.days ?? allWeekdays;

  @override
  void initState() {
    super.initState();
    if (_times.isEmpty) _times = [7 * 60, 21 * 60];
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHeader('متابعة صحية'),
              ChoiceChips<HealthCheckKind>(
                values: HealthCheckKind.values,
                label: (k) => k.label,
                selected: (k) => k == _kind,
                onSelected: (k) => setState(() {
                  if (HealthCheckKind.values.any(
                    (x) => x.label == _title.text.trim(),
                  )) {
                    _title.text = k.label;
                  }
                  _kind = k;
                }),
              ),
              const FieldLabel('الاسم'),
              TextField(controller: _title),
              const FieldLabel('الأوقات (حسب كلام طبيبك)'),
              for (var k = 0; k < _times.length; k++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: TimeField(
                          label: 'المرة ${nums(k + 1)}',
                          value: _times[k],
                          onChanged: (v) => setState(() => _times[k] = v),
                        ),
                      ),
                      if (_times.length > 1)
                        IconButton(
                          tooltip: 'احذف الوقت',
                          onPressed: () => setState(() => _times.removeAt(k)),
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                ),
              if (_times.length < 6)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => setState(
                      () => _times.add((_times.last + 180) % minutesPerDay),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('وقت ثاني'),
                  ),
                ),
              const FieldLabel('الأيام'),
              WeekdayPicker(
                selected: _days,
                onChanged: (d) => setState(() => _days = d),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'احفظ',
                onPressed: _title.text.trim().isEmpty || _days.isEmpty
                    ? null
                    : () => Navigator.pop(
                        context,
                        HealthCheck(
                          id: widget.initial?.id ?? newId().substring(0, 8),
                          kind: _kind,
                          title: _title.text.trim(),
                          times: [..._times]..sort(),
                          days: _days,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MotherEditor extends StatefulWidget {
  const _MotherEditor({required this.initial});
  final MotherConfig initial;
  @override
  State<_MotherEditor> createState() => _MotherEditorState();
}

class _MotherEditorState extends State<_MotherEditor> {
  late MotherConfig _m = widget.initial;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final born = _m.babyBorn;
    final months = born == null
        ? null
        : (Day.fromDateTime(DateTime.now()).difference(born) / 30.4).floor();
    return _EditorScaffold(
      title: 'الحمل والطفل',
      onSave: () => Navigator.pop(context, _m),
      children: [
        const _Disclaimer(
          'تذكيرات بسيطة وتسجيل فقط. أي نشاط أو تغيير استشيري فيه طبيبتك. مواعيد المتابعة أضيفيها من زر «+».',
        ),
        Segmented<MotherStage>(
          values: MotherStage.values,
          labels: [for (final s in MotherStage.values) s.label],
          selected: _m.stage,
          onChanged: (s) => setState(() => _m = _m.copyWith(stage: s)),
        ),
        const SizedBox(height: 12),
        if (_m.stage == MotherStage.pregnant) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('مشي خفيف'),
            subtitle: const Text('إذا وافقت عليه طبيبتك'),
            value: _m.walk,
            onChanged: (v) => setState(() => _m = _m.copyWith(walk: v)),
          ),
          if (_m.walk)
            ChoiceChips<int>(
              values: const [10, 15, 20, 30],
              label: fmtDuration,
              selected: (v) => v == _m.walkMinutes,
              onSelected: (v) =>
                  setState(() => _m = _m.copyWith(walkMinutes: v)),
            ),
        ] else ...[
          SettingsRow(
            icon: Icons.cake_outlined,
            title: 'تاريخ ولادة الطفل',
            value: born == null
                ? 'اختر'
                : nums('${born.day}/${born.month}/${born.year}'),
            onTap: () async {
              final now = DateTime.now();
              final d = await showDatePicker(
                context: context,
                firstDate: now.subtract(const Duration(days: 365 * 2)),
                lastDate: now,
                initialDate: now.subtract(const Duration(days: 30)),
              );
              if (d != null) {
                setState(() => _m = _m.copyWith(babyBorn: Day.fromDateTime(d)));
              }
            },
          ),
          if (months != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                months < 1
                    ? 'عمر طفلك أقل من شهر'
                    : 'عمر طفلك ${nums(months)} ${months <= 10 ? 'أشهر' : 'شهرًا'}',
                style: T.meta.copyWith(color: c.muted),
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('تذكير الرضعات'),
            subtitle: const Text('خط خفيف في يومك، وتسجّلين الرضعة بلمسة'),
            value: _m.feeds,
            onChanged: (v) => setState(() => _m = _m.copyWith(feeds: v)),
          ),
          if (_m.feeds)
            ChoiceChips<int>(
              values: const [120, 150, 180, 240],
              label: (v) => 'كل ${fmtDuration(v)}',
              selected: (v) => v == _m.feedEvery,
              onSelected: (v) => setState(() => _m = _m.copyWith(feedEvery: v)),
            ),
        ],
      ],
    );
  }
}
