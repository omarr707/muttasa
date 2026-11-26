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
              style: TextStyle(color: c.ink2, fontSize: 13),
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
            style: TextStyle(color: c.muted, fontSize: 12.5),
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
  late Set<int> _days = widget.initial.weekdays;
  late int _start = widget.initial.start;
  late int _end = widget.initial.end;

  @override
  void dispose() {
    _title.dispose();
    _who.dispose();
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _EditorScaffold(
    title: 'حصة أو دورة',
    canSave: _title.text.trim().isNotEmpty && _days.isNotEmpty && _end > _start,
    onSave: () => Navigator.pop(
      context,
      ClassConfig(
        title: _title.text.trim(),
        who: _who.text.trim().isEmpty ? 'أنا' : _who.text.trim(),
        weekdays: _days,
        start: _start,
        end: _end,
        place: _place.text.trim().isEmpty ? null : _place.text.trim(),
      ),
    ),
    children: [
      const FieldLabel('الاسم'),
      TextField(
        controller: _title,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(hintText: 'مثل: حصة موسيقى'),
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
      const SizedBox(height: 12),
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
    ],
  );
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
            style: TextStyle(color: c.muted, fontSize: 12.5),
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
          if (_pages != null) ...[
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
                  style: const TextStyle(fontFamily: fontDisplay, fontSize: 20),
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
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
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
            style: TextStyle(color: c.muted, fontSize: 12.5),
          ),
        ),
        const FieldLabel('السنن الرواتب'),
        Text(
          'تظهر داخل بطاقة الصلاة نفسها كبنود فرعية تأكدها منها، ولا تدخل في نسبة الإنجاز.',
          style: TextStyle(color: c.ink2, fontSize: 13),
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

class _RemindersEditorState extends State<_RemindersEditor> {
  late bool _water = widget.initial.water;
  late int _cups = widget.initial.cups;
  late bool _stand = widget.initial.stand;
  late bool _breathe = widget.initial.breathe;
  @override
  Widget build(BuildContext context) => _EditorScaffold(
    title: 'تذكيرات قصيرة',
    onSave: () => Navigator.pop(
      context,
      RemindersConfig(
        water: _water,
        cups: _cups,
        stand: _stand,
        breathe: _breathe,
      ),
    ),
    children: [
      Text(
        'خطوط خفيفة بين البطاقات. ما تحجز وقت وما تنحسب في الإنجاز.',
        style: TextStyle(color: context.c.ink2),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('الماء'),
        subtitle: const Text('مع الوجبات والاستراحة، ثم نوزّع الباقي على يومك'),
        value: _water,
        onChanged: (v) => setState(() => _water = v),
      ),
      if (_water)
        ChoiceChips<int>(
          values: const [4, 6, 8, 10, 12],
          label: (n) => '$n أكواب',
          selected: (n) => n == _cups,
          onSelected: (n) => setState(() => _cups = n),
        ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('الوقوف'),
        subtitle: const Text('كل ساعتين داخل الدوام'),
        value: _stand,
        onChanged: (v) => setState(() => _stand = v),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('التنفّس'),
        subtitle: const Text('دقيقة بعد العصر'),
        value: _breathe,
        onChanged: (v) => setState(() => _breathe = v),
      ),
    ],
  );
}
