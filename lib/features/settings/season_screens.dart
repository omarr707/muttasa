import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/calendar_link.dart';
import '../../data/defaults.dart';
import '../../services/calendar.dart';
import '../../state/providers.dart';
import 'settings_screen.dart' show SettingsPage, pushPage;

// -----------------------------------------------------------------------------
// رمضان والعيد
// -----------------------------------------------------------------------------

/// المواسم: وضع الصيام، جدول رمضان، العيد، والعطل الرسمية.
class RamadanPage extends ConsumerWidget {
  const RamadanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appDataProvider.select((d) => d.settings.season));
    final p = ref.watch(appDataProvider.select((d) => d.profile))!;
    final today = ref.watch(todayProvider);
    final ctrl = ref.read(appDataProvider.notifier);
    final h = HijriDay.of(today, offset: p.hijriOffset);
    // السنة الهجرية لرمضان القادم (أو الحالي).
    final year = h.month <= 9 ? h.year : h.year + 1;
    final answer = s.ramadanYears[year];
    void set(SeasonSettings v) => ctrl.updateSeason(v);

    return SettingsPage(
      title: 'رمضان والعيد',
      children: [
        SettingsGroup(
          title: 'الصيام',
          children: [
            for (final m in FastingMode.values)
              SettingsRow(
                title: m.label,
                subtitle: switch (m) {
                  FastingMode.off => 'جدولك ما يتغير في رمضان',
                  FastingMode.ramadan => 'نسألك قبل رمضان بأيام ونجهّز جدوله',
                  FastingMode.ramadanMonThu =>
                    'والاثنين والخميس: سحور وإفطار بدل الوجبات، والدوام كما هو',
                },
                trailing: s.fasting == m
                    ? Icon(Icons.check, color: context.c.accent)
                    : null,
                onTap: () => set(s.copyWith(fasting: m)),
              ),
          ],
        ),
        if (s.fasting != FastingMode.off) ...[
          SettingsGroup(
            title: 'جدول رمضان ${nums(year)} هـ',
            children: [
              SettingsRow(
                title: 'جدول رمضان',
                subtitle: switch (answer) {
                  true => 'يشتغل مع دخول الشهر، ويرجع جدولك بعد العيد',
                  false => 'جدولك يبقى كما هو في رمضان',
                  null => 'نسألك من ٢٧ شعبان',
                },
                toggle: answer == true,
                onToggle: (v) => ctrl.answerRamadan(year, v),
              ),
              SettingsRow(
                title: 'دوام رمضان',
                subtitle: s.ramadanWork
                    ? fmtRange(s.ramadanWorkStart, s.ramadanWorkEnd)
                    : 'دوامك العادي',
                toggle: s.ramadanWork,
                onToggle: (v) => set(s.copyWith(ramadanWork: v)),
              ),
              if (s.ramadanWork)
                SettingsRow(
                  title: 'ساعات دوام رمضان',
                  value: fmtRange(s.ramadanWorkStart, s.ramadanWorkEnd),
                  onTap: () async {
                    final a = await pickTime(
                      context,
                      initial: s.ramadanWorkStart,
                      title: 'يبدأ دوام رمضان',
                    );
                    if (a == null || !context.mounted) return;
                    final b = await pickTime(
                      context,
                      initial: s.ramadanWorkEnd,
                      title: 'ينتهي دوام رمضان',
                    );
                    if (b == null || b <= a) return;
                    set(s.copyWith(ramadanWorkStart: a, ramadanWorkEnd: b));
                  },
                ),
              SettingsRow(
                title: 'التراويح بعد العشاء',
                subtitle: 'ساعة، بعد العشاء بـ ٢٠ دقيقة',
                toggle: s.taraweeh,
                onToggle: (v) => set(s.copyWith(taraweeh: v)),
              ),
              SettingsRow(
                title: 'المشي والطلعات بعد الإفطار',
                toggle: s.lateOutings,
                onToggle: (v) => set(s.copyWith(lateOutings: v)),
              ),
              SettingsRow(
                title: 'وقت النوم في رمضان',
                value: fmtTime(s.ramadanSleep),
                onTap: () async {
                  final t = await pickTime(
                    context,
                    initial: s.ramadanSleep,
                    title: 'وقت النوم في رمضان',
                  );
                  if (t != null) set(s.copyWith(ramadanSleep: t));
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              nums(
                'السحور قبل الفجر بـ 45 دقيقة، والإفطار مع أذان المغرب، والماء بعد الإفطار فقط. '
                'بأم القرى العشاء بعد المغرب بساعتين في رمضان. وزكاة الفطر تذكير من 27 رمضان.',
              ),
              style: T.meta.copyWith(color: context.c.muted),
            ),
          ),
        ],
        SettingsGroup(
          title: 'العيد',
          children: [
            SettingsRow(
              title: 'وضع العيد',
              subtitle: 'صلاة العيد، معايدة الأهل، والدوام إجازة',
              toggle: s.eid,
              onToggle: (v) => set(s.copyWith(eid: v)),
            ),
          ],
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// الأوضاع
// -----------------------------------------------------------------------------

String modeLine(LifeMode m) {
  final range = m.from == m.to
      ? fmtDayShort(m.from)
      : '${fmtDayShort(m.from)} إلى ${fmtDayShort(m.to)}';
  return switch (m.kind) {
    ModeKind.vacation => range,
    ModeKind.travel => '${m.city ?? 'سفر'} · $range',
    ModeKind.pause => range,
  };
}

/// الأوضاع: إجازة، سفر، إيقاف مؤقت، والعطل الرسمية.
class ModesPage extends ConsumerWidget {
  const ModesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modes = ref.watch(appDataProvider.select((d) => d.modes));
    final today = ref.watch(todayProvider);
    final season = ref.watch(appDataProvider.select((d) => d.settings.season));
    final holidays = ref.watch(holidaysProvider);
    final ctrl = ref.read(appDataProvider.notifier);
    final current = modes.where((m) => !m.to.isBefore(today)).toList();
    final past = modes.where((m) => m.to.isBefore(today)).toList();
    final upcoming = holidays.where((h) => !h.hijri).toList()
      ..sort((a, b) => _nextDate(a, today).compareTo(_nextDate(b, today)));

    return SettingsPage(
      title: 'الأوضاع',
      children: [
        SettingsGroup(
          title: 'أضف وضعًا',
          children: [
            for (final k in ModeKind.values)
              SettingsRow(
                icon: _modeIcon(k),
                title: k.label,
                subtitle: switch (k) {
                  ModeKind.vacation =>
                    'لا دوام، ومشاوير المدرسة تتوقف إذا تبغى',
                  ModeKind.travel => 'المدينة والمواقيت تتبع وجهتك',
                  ModeKind.pause =>
                    'تبقى الصلاة والمواعيد الثابتة، والعادات تختفي ولا تنحسب',
                },
                onTap: () => pushPage(context, ModeEditor(kind: k)),
              ),
          ],
        ),
        if (current.isNotEmpty)
          SettingsGroup(
            title: 'الحالية والقادمة',
            children: [
              for (final m in current)
                SettingsRow(
                  icon: _modeIcon(m.kind),
                  title: m.kind.label,
                  subtitle: modeLine(m),
                  onTap: () =>
                      pushPage(context, ModeEditor(kind: m.kind, mode: m)),
                ),
            ],
          ),
        if (past.isNotEmpty)
          SettingsGroup(
            title: 'السابقة',
            children: [
              for (final m in past.reversed.take(5))
                SettingsRow(
                  title: m.kind.label,
                  subtitle: modeLine(m),
                  trailing: IconButton(
                    tooltip: 'احذف',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => ctrl.deleteMode(m.id),
                  ),
                ),
            ],
          ),
        SettingsGroup(
          title: 'العطل الرسمية',
          children: [
            SettingsRow(
              title: 'العطلة تلغي الدوام والمدرسة',
              subtitle: 'المناسبات الوطنية لدولتك تظهر في يومك',
              toggle: season.holidays,
              onToggle: (v) => ctrl.updateSeason(season.copyWith(holidays: v)),
            ),
            for (final h in upcoming.take(4))
              SettingsRow(
                title: h.name,
                value: fmtDayShort(_nextDate(h, today)),
                subtitle: h.off ? null : 'مناسبة بلا عطلة',
              ),
          ],
        ),
      ],
    );
  }

  static Day _nextDate(Holiday h, Day today) {
    final d = Day(today.year, h.month, h.day);
    return d.isBefore(today) ? Day(today.year + 1, h.month, h.day) : d;
  }
}

IconData _modeIcon(ModeKind k) => switch (k) {
  ModeKind.vacation => Icons.beach_access_outlined,
  ModeKind.travel => Icons.flight_takeoff,
  ModeKind.pause => Icons.pause_circle_outline,
};

/// إضافة وضع أو تعديله.
class ModeEditor extends ConsumerStatefulWidget {
  const ModeEditor({super.key, required this.kind, this.mode});
  final ModeKind kind;
  final LifeMode? mode;

  @override
  ConsumerState<ModeEditor> createState() => _ModeEditorState();
}

class _ModeEditorState extends ConsumerState<ModeEditor> {
  late Day _from;
  late Day _to;
  late bool _workOff;
  late bool _kidsOff;
  Country? _country;
  City? _city;

  @override
  void initState() {
    super.initState();
    final today = ref.read(todayProvider);
    final m = widget.mode;
    _from = m?.from ?? today;
    _to = m?.to ?? today.add(widget.kind == ModeKind.pause ? 3 : 6);
    _workOff = m?.workOff ?? true;
    _kidsOff = m?.kidsOff ?? true;
    if (m?.country != null) {
      final defaults = ref.read(defaultsProvider);
      _country = defaults.countries
          .where((c) => c.code == m!.country)
          .firstOrNull;
      _city = _country?.cities.where((c) => c.name == m!.city).firstOrNull;
    }
  }

  Future<void> _pickRange() async {
    final today = ref.read(todayProvider);
    final r = await showDateRangePicker(
      context: context,
      firstDate: today.add(-30).at(0),
      lastDate: today.add(400).at(0),
      initialDateRange: DateTimeRange(start: _from.at(0), end: _to.at(0)),
      helpText: widget.kind.label,
      saveText: 'تم',
    );
    if (r == null) return;
    setState(() {
      _from = Day.fromDateTime(r.start);
      _to = Day.fromDateTime(r.end);
    });
  }

  Future<void> _pickPlace() async {
    final defaults = ref.read(defaultsProvider);
    final picked = await showModalBottomSheet<(Country, City)>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * .8,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final co in defaults.countries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    co.name,
                    style: T.label.copyWith(color: ctx.c.muted),
                  ),
                ),
                for (final ci in co.cities)
                  ListTile(
                    title: Text(ci.name),
                    trailing: ci.name == _city?.name
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(ctx, (co, ci)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _country = picked.$1;
      _city = picked.$2;
    });
  }

  Future<void> _save() async {
    final travel = widget.kind == ModeKind.travel;
    if (travel && _city == null) {
      toast(context, 'اختر وجهتك');
      return;
    }
    final ctrl = ref.read(appDataProvider.notifier);
    final m = LifeMode(
      id: widget.mode?.id ?? newId(),
      kind: widget.kind,
      from: _from,
      to: _to,
      workOff: widget.kind == ModeKind.vacation ? true : _workOff,
      kidsOff: _kidsOff,
      country: travel ? _country!.code : null,
      city: travel ? _city!.name : null,
      lat: travel ? _city!.lat : null,
      lng: travel ? _city!.lng : null,
      timezone: travel ? _city!.tz : null,
      calcMethod: travel ? _country!.method : null,
    );
    await ctrl.saveMode(m);
    if (!mounted) return;
    Navigator.pop(context);
    toast(context, '${widget.kind.label}: ${modeLine(m)}');
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kind;
    final p = ref.watch(appDataProvider.select((d) => d.profile))!;
    final days = _to.difference(_from) + 1;
    final c = context.c;
    return SettingsPage(
      title: widget.mode == null ? k.label : 'تعديل ${k.label}',
      children: [
        SettingsGroup(
          title: 'المدة',
          children: [
            SettingsRow(
              icon: Icons.date_range,
              title: '${fmtDayShort(_from)} إلى ${fmtDayShort(_to)}',
              subtitle: days == 1 ? 'يوم واحد' : '${nums(days)} أيام',
              onTap: _pickRange,
            ),
          ],
        ),
        if (k == ModeKind.travel)
          SettingsGroup(
            title: 'الوجهة',
            children: [
              SettingsRow(
                icon: Icons.place_outlined,
                title: _city?.name ?? 'اختر المدينة',
                subtitle: _country == null
                    ? 'مواقيت الصلاة بتوقيت الوجهة'
                    : '${_country!.name} · ${_country!.method.label}',
                onTap: _pickPlace,
              ),
              SettingsRow(
                title: 'إجازة من الدوام',
                toggle: _workOff,
                onToggle: (v) => setState(() => _workOff = v),
              ),
            ],
          ),
        if (k == ModeKind.vacation)
          SettingsGroup(
            children: [
              SettingsRow(
                title: 'وقّف مشاوير المدرسة والحصص',
                toggle: _kidsOff,
                onToggle: (v) => setState(() => _kidsOff = v),
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 16),
          child: Text(switch (k) {
            ModeKind.vacation =>
              'الدوام يختفي من هذه الأيام، وعاداتك تنتقل للوقت اللي صار فاضي.',
            ModeKind.travel =>
              'الصلاة بمواقيت ${_city?.name ?? 'الوجهة'}، ومشاوير الأولاد تتوقف. '
                  'إذا سافرت في رمضان، رمضان يحدد الجدول والوجهة تحدد المواقيت. '
                  'التنبيهات تتبع توقيت جوالك، فخلّه على الوقت التلقائي.',
            ModeKind.pause =>
              'تبقى ${p.islam ? 'الصلاة و' : ''}المواعيد الثابتة والوجبات. '
                  'العادات والورد والاقتراحات تختفي ولا تنحسب عليك.',
          }, style: T.meta.copyWith(color: c.muted)),
        ),
        PrimaryButton(label: 'احفظ', onPressed: _save),
        if (widget.mode != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              await ref
                  .read(appDataProvider.notifier)
                  .deleteMode(widget.mode!.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text('احذف ${k.label}', style: TextStyle(color: c.amber)),
          ),
        ],
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// التقويمات
// -----------------------------------------------------------------------------

/// ربط تقويمات الجهاز (Google وApple): قراءة فقط.
class CalendarsPage extends ConsumerStatefulWidget {
  const CalendarsPage({super.key});
  @override
  ConsumerState<CalendarsPage> createState() => _CalendarsPageState();
}

class _CalendarsPageState extends ConsumerState<CalendarsPage> {
  List<DeviceCal>? _available;
  bool _loading = false;
  bool _denied = false;

  Future<void> _load() async {
    setState(() => _loading = true);
    final ok = await CalendarService.ensurePermission();
    final list = ok ? await CalendarService.calendars() : <DeviceCal>[];
    if (!mounted) return;
    setState(() {
      _loading = false;
      _denied = !ok;
      _available = list;
    });
  }

  Future<void> _toggle(DeviceCal cal, bool on) async {
    final ctrl = ref.read(appDataProvider.notifier);
    final link = ref.read(appDataProvider).calendar;
    final list = [
      for (final c in link.calendars)
        if (c.id != cal.id) c,
      if (on) cal,
    ];
    await ctrl.saveCalendar(CalendarLink(calendars: list, events: link.events));
    await ctrl.refreshCalendar();
    if (list.isEmpty) await ctrl.saveCalendar(const CalendarLink());
  }

  @override
  Widget build(BuildContext context) {
    final link = ref.watch(appDataProvider.select((d) => d.calendar));
    final chosen = {for (final c in link.calendars) c.id};
    final c = context.c;
    final available = _available;
    return SettingsPage(
      title: 'التقويمات',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            'نقرأ مواعيدك من تقويمات جوالك (Google أو Apple) ونرتّب جدولك حولها. '
            'المواعيد ثابتة وما تنحسب في الإنجاز. ما نكتب في تقويمك أبدًا.',
            style: T.meta.copyWith(color: c.muted),
          ),
        ),
        if (link.linked)
          SettingsGroup(
            title: 'المربوطة',
            children: [
              for (final cal in link.calendars)
                SettingsRow(
                  icon: Icons.event_outlined,
                  title: cal.name,
                  subtitle: cal.source,
                  toggle: true,
                  onToggle: (v) => _toggle(cal, v),
                ),
              SettingsRow(
                title: 'آخر قراءة',
                subtitle: nums(
                  '${link.events.where((e) => !e.allDay).length} موعد في الشهر القادم',
                ),
                trailing: IconButton(
                  tooltip: 'حدّث',
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () async {
                    await ref.read(appDataProvider.notifier).refreshCalendar();
                    if (context.mounted) toast(context, 'تحدّثت المواعيد');
                  },
                ),
              ),
            ],
          ),
        if (available == null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: PrimaryButton(
              label: _loading ? 'لحظة…' : 'اربط تقويم',
              onPressed: _loading ? null : _load,
            ),
          )
        else if (_denied)
          SettingsGroup(
            children: [
              const SettingsRow(
                icon: Icons.lock_outline,
                title: 'ما عندنا إذن قراءة التقويم',
                subtitle: 'تقدر تسمح من إعدادات الجوال ثم ترجع هنا',
              ),
              SettingsRow(
                title: 'افتح إعدادات الجوال',
                onTap: () => launchUrl(Uri.parse('app-settings:')),
              ),
            ],
          )
        else if (available.isEmpty)
          const SettingsGroup(
            children: [SettingsRow(title: 'ما لقينا تقويمات في جوالك')],
          )
        else
          SettingsGroup(
            title: 'تقويمات جوالك',
            children: [
              for (final cal in available.where((x) => !chosen.contains(x.id)))
                SettingsRow(
                  icon: Icons.calendar_month_outlined,
                  title: cal.name,
                  subtitle: cal.source,
                  toggle: false,
                  onToggle: (v) => _toggle(cal, v),
                ),
            ],
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// مشاركة مشاوير الأولاد
// -----------------------------------------------------------------------------

/// مشاركة مع الزوج/الزوجة: لكل مشوار أنا أو الشريك أو حسب الأيام،
/// و«أرسل جدول الأسبوع» عبر واتساب.
class PartnerPage extends ConsumerStatefulWidget {
  const PartnerPage({super.key});
  @override
  ConsumerState<PartnerPage> createState() => _PartnerPageState();
}

class _PartnerPageState extends ConsumerState<PartnerPage> {
  late final TextEditingController _name;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    final p = ref.read(appDataProvider).partner;
    _name = TextEditingController(text: p.name);
    _phone = TextEditingController(text: p.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _saveContact() {
    final p = ref.read(appDataProvider).partner;
    return ref
        .read(appDataProvider.notifier)
        .savePartner(
          p.copyWith(
            name: _name.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          ),
        );
  }

  Future<void> _send() async {
    await _saveContact();
    final text = weekRunsText(ref);
    final phone = _phone.text.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = phone.isEmpty
        ? Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}')
        : Uri.parse(
            'https://wa.me/${phone.replaceFirst('+', '')}?text=${Uri.encodeComponent(text)}',
          );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) toast(context, 'ما قدرنا نفتح واتساب');
  }

  @override
  Widget build(BuildContext context) {
    final share = ref.watch(appDataProvider.select((d) => d.partner));
    final today = ref.watch(todayProvider);
    final kids = ref
        .watch(engineProvider)
        .rulesOn(today, includePaused: true)
        .where((r) => r.config is KidConfig)
        .toList();
    final ctrl = ref.read(appDataProvider.notifier);
    final c = context.c;
    final runs = <(String, String)>[
      for (final r in kids)
        for (final (what, label) in [('drop', 'توصيل'), ('pick', 'استلام')])
          if ((r.config as KidConfig).days.values.any(
            (d) => (what == 'drop' ? d.drop : d.pick) != null,
          ))
            ('${r.key}:$what', '$label ${(r.config as KidConfig).child}'),
    ];

    return SettingsPage(
      title: 'مشاركة مع الزوج/الزوجة',
      children: [
        SettingsGroup(
          title: 'الشريك',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'الاسم',
                  hintText: 'مثلًا: أم عيسى',
                ),
                onEditingComplete: _saveContact,
                onTapOutside: (_) => _saveContact(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'الجوال (لواتساب)',
                ),
                onEditingComplete: _saveContact,
                onTapOutside: (_) => _saveContact(),
              ),
            ),
          ],
        ),
        if (runs.isEmpty)
          const SettingsGroup(
            children: [
              SettingsRow(
                title: 'ما فيه مشاوير أولاد في روتينك',
                subtitle: 'أضفها من روتيني ← المكتبة',
              ),
            ],
          )
        else
          SettingsGroup(
            title: 'مين يسوّي المشوار؟',
            children: [
              for (final (key, label) in runs)
                _RunRow(
                  label: label,
                  assign: share.runs[key] ?? const RunAssign(RunWho.me),
                  partnerName: share.name.isEmpty ? 'الشريك' : share.name,
                  onChanged: (a) => ctrl.savePartner(
                    share.copyWith(runs: {...share.runs, key: a}),
                  ),
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 16),
          child: Text(
            'مشاوير الشريك تظهر في يومك للعلم، وما تحجز وقتك ولا تنحسب عليك. '
            'وتقدر تبدّل يوم معيّن من البطاقة.',
            style: T.meta.copyWith(color: c.muted),
          ),
        ),
        PrimaryButton(
          label: 'أرسل جدول الأسبوع',
          onPressed: runs.isEmpty ? null : _send,
        ),
      ],
    );
  }
}

class _RunRow extends StatelessWidget {
  const _RunRow({
    required this.label,
    required this.assign,
    required this.partnerName,
    required this.onChanged,
  });
  final String label;
  final RunAssign assign;
  final String partnerName;
  final ValueChanged<RunAssign> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: T.body.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Segmented<RunWho>(
          small: true,
          values: RunWho.values,
          labels: ['أنا', partnerName, 'حسب الأيام'],
          selected: assign.who,
          onChanged: (w) =>
              onChanged(RunAssign(w, partnerDays: assign.partnerDays)),
        ),
        if (assign.who == RunWho.byDays) ...[
          const SizedBox(height: 8),
          Text(
            'أيام $partnerName',
            style: T.meta.copyWith(color: context.c.muted),
          ),
          const SizedBox(height: 4),
          WeekdayPicker(
            selected: assign.partnerDays,
            onChanged: (d) =>
                onChanged(RunAssign(RunWho.byDays, partnerDays: d)),
          ),
        ],
      ],
    ),
  );
}

/// نص جدول مشاوير الأسبوع لواتساب.
String weekRunsText(WidgetRef ref) {
  final engine = ref.read(engineProvider);
  final today = ref.read(todayProvider);
  final data = ref.read(appDataProvider);
  final name = data.partner.name.isEmpty ? 'أنت' : data.partner.name;
  final me = data.profile?.name ?? '';
  final lines = <String>[];
  for (var i = 0; i < 7; i++) {
    final d = today.add(i);
    final runs = engine
        .day(d)
        .items
        .where((x) => x.kind == ItemKind.kid)
        .toList();
    if (runs.isEmpty) continue;
    lines.add(
      '${arabicWeekdays[d.weekday]} ${d.day}/${d.month}: ${runs.map((x) => '${x.title} ${fmtTime(x.start)} (${x.partner ? name : (me.isEmpty ? 'أنا' : me)})').join(' · ')}',
    );
  }
  return [
    'جدول مشاوير الأولاد هالأسبوع:',
    ...lines,
    if (me.isNotEmpty) '— $me',
  ].join('\n');
}
