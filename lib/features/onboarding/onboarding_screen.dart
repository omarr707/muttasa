import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/defaults.dart';
import '../../data/library.dart';
import '../../services/location.dart';
import '../../services/notifications.dart';
import '../../state/providers.dart';
import '../routine/labels.dart';
import '../routine/rule_editors.dart';

/// اهتمام في شاشة «وش تبغى يكون في يومك؟» وما يفعّله من القواعد.
class _Interest {
  const _Interest(
    this.id,
    this.label,
    this.icon,
    this.rules,
    this.desc, {
    this.islam = false,
    this.tags = const {},
    this.notFor = const {},
  });
  final String id;
  final String desc;
  final String label;
  final IconData icon;
  final List<String> rules;
  final bool islam;

  /// الأوضاع اللي يناسبها (يظهر أولًا كـ«مقترح لك»). فاضي = يناسب الكل.
  final Set<String> tags;

  /// قيم الجنس اللي ما يظهر لها.
  final Set<String> notFor;
}

/// «وش يتكرر في أسبوعك؟»: اختيار متعدد.
const _roleOptions = <(String, String, IconData)>[
  ('work', 'دوام', Icons.work_outline),
  ('university', 'دراسة جامعية', Icons.account_balance_outlined),
  ('school', 'مدرسة', Icons.backpack_outlined),
  ('kids', 'أطفال', Icons.child_care_outlined),
  ('freelance', 'عمل حر', Icons.laptop_mac),
  ('pregnant', 'حمل', Icons.pregnant_woman),
  ('infant', 'طفل رضيع', Icons.crib_outlined),
  ('retired', 'متقاعد', Icons.weekend_outlined),
];

const _ages = ['أقل من 18', '18–24', '25–34', '35–44', '45–59', '60+'];

const _interests = [
  _Interest(
    'prayer',
    'الصلاة في وقتها',
    Icons.mosque_outlined,
    ['prayers', 'adhkar'],
    'المواقيت والأذكار',
    islam: true,
  ),
  _Interest(
    'quran',
    'القرآن',
    Icons.auto_stories_outlined,
    ['quran:wird'],
    'ورد يومي أو ختمة',
    islam: true,
  ),
  _Interest(
    'study',
    'المذاكرة',
    Icons.school_outlined,
    ['habit:study'],
    'جلسات بين المحاضرات',
    tags: {'university', 'school'},
  ),
  _Interest(
    'kids',
    'وقت مع الأطفال',
    Icons.child_care_outlined,
    ['habit:kids'],
    'نصف ساعة كل يوم',
    tags: {'kids'},
  ),
  _Interest(
    'mother',
    'الحمل والطفل',
    Icons.pregnant_woman,
    [],
    'مشي خفيف وتذكير الرضعات',
    tags: {'pregnant', 'infant'},
    notFor: {'male'},
  ),
  _Interest(
    'health',
    'صحتي',
    Icons.monitor_heart_outlined,
    [],
    'قياس السكر والضغط والدواء',
  ),
  _Interest('sport', 'الرياضة', Icons.directions_walk, [
    'habit:walk',
  ], 'مشي أو تمرين'),
  _Interest('read', 'القراءة', Icons.menu_book_outlined, [
    'habit:read',
  ], 'صفحات كل يوم'),
  _Interest('lang', 'تعلّم لغة', Icons.translate, [
    'habit:language',
  ], 'جلسات قصيرة'),
  _Interest('water', 'الماء والحركة', Icons.water_drop_outlined, [
    'reminders',
  ], 'ماء، حركة قصيرة، تنفّس'),
  _Interest(
    'family',
    'وقت مع الأهل',
    Icons.family_restroom,
    [],
    'طلعات وزيارات',
    tags: {'kids', 'retired'},
  ),
  _Interest(
    'people',
    'التواصل مع الناس',
    Icons.forum_outlined,
    [],
    'اتصال ورسالة',
  ),
  _Interest('sleep', 'نوم مبكر', Icons.bedtime_outlined, [
    'habit:winddown',
  ], 'تجهيز قبل النوم'),
  _Interest(
    'save',
    'الادخار',
    Icons.savings_outlined,
    ['savings'],
    'يوم الراتب',
    tags: {'work', 'freelance'},
  ),
];

enum _Work { none, fixed, shifts }

/// التهيئة: سؤال واحد في كل شاشة. ترحيب، المدينة، كيف يمشي يومك،
/// الاهتمامات، ثم ملخص «جدولك جاهز». الدين يُفعّل افتراضيًا حسب الدولة.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _step = 0;

  final _search = TextEditingController();
  Country? _country;
  City? _city;
  int _wake = 4 * 60 + 45;
  int _sleep = 22 * 60 + 30;
  _Work _work = _Work.fixed;
  int _workFrom = 7 * 60 + 30;
  int _workTo = 15 * 60 + 30;
  Set<int>? _workDays;
  WorkConfig? _shifts;
  final Set<String> _picked = {'prayer', 'quran', 'water', 'people'};

  // «عنك»: كلها اختيارية.
  final Set<String> _roles = {};
  String? _age;
  String? _gender;
  bool _showAll = false;
  bool _workTouched = false;

  /// التزامات الجامعة والمدرسة وغيرها، تدخل الجدول أولًا.
  final List<ClassConfig> _commitments = [];
  HealthConfig? _health;
  MotherConfig? _mother;
  bool _remind = true;
  bool _generating = false;

  // «مين تبغى تتواصل معه؟»: أسماء فقط، والتطبيق يوزّع.
  final _people = <Person>[];
  final _personName = TextEditingController();
  String? _personPhone;
  Relation _personRelation = Relation.family;
  ContactLevel _level = ContactLevel.mid;

  bool get _wantsPeople => _picked.contains('people');

  bool get _islam {
    // مفعّل افتراضيًا في الدول المضمّنة، ويُطفأ من الإعدادات ‹ الأقسام.
    return true;
  }

  Set<int> get _weekend => _country?.weekend ?? const {5, 6};
  Set<int> get _days => _workDays ?? workdays(_weekend);

  @override
  void initState() {
    super.initState();
    final defaults = ref.read(defaultsProvider);
    if (defaults.countries.isNotEmpty) {
      _country = defaults.countries.first;
      _city = _country!.cities.first;
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _search.dispose();
    _personName.dispose();
    super.dispose();
  }

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    _pages.animateToPage(
      step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      body: SafeArea(
        child: _generating
            ? _Generating(
                city: _city?.name ?? '',
                country: _country?.name ?? '',
                islam: _islam,
              )
            : Column(
                children: [
                  if (_step > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'رجوع',
                            onPressed: () => _go(
                              _step == 6 && !_wantsPeople ? 4 : _step - 1,
                            ),
                            icon: const Icon(Icons.arrow_forward, size: 20),
                          ),
                          for (var i = 1; i <= 6; i++)
                            Expanded(
                              child: Container(
                                height: 3,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: i <= _step ? c.accent : c.line,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          if (_step < 6)
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: c.muted,
                                textStyle: T.label,
                              ),
                              onPressed: () => _go(
                                _step == 4 && !_wantsPeople ? 6 : _step + 1,
                              ),
                              child: const Text('تخطَّ'),
                            )
                          else
                            const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  Expanded(
                    child: PageView(
                      controller: _pages,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _welcome(),
                        _cityStep(),
                        _aboutStep(),
                        _dayStep(),
                        _interestsStep(),
                        _peopleStep(),
                        _summaryStep(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _page({
    required String title,
    String? subtitle,
    required List<Widget> children,
    Widget? footer,
    required String next,
    VoidCallback? onNext,
  }) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: T.onboardTitle),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(subtitle, style: T.body.copyWith(color: c.muted)),
            ),
          const SizedBox(height: 20),
          Expanded(child: ListView(children: children)),
          if (footer != null) ...[footer, const SizedBox(height: 10)],
          PrimaryButton(label: next, onPressed: onNext),
        ],
      ),
    );
  }

  Widget _welcome() {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(R.lg),
            ),
            child: Icon(Icons.wb_twilight, size: 36, color: c.accent),
          ),
          const SizedBox(height: 20),
          Text('مُتَّسَع', style: T.brand.copyWith(fontSize: 30, height: 1.3)),
          const SizedBox(height: 10),
          Text(
            'تختار كيف تبغى تعيش يومك، والتطبيق يحوّل اختياراتك إلى جدول قابل للتنفيذ، ويبيّن لك مدى التزامك مع الوقت.',
            textAlign: TextAlign.center,
            style: T.body.copyWith(color: c.ink2),
          ),
          const SizedBox(height: 12),
          Text(
            'رتّب يومك، وخلّ فيه وقت للناس اللي يهمّونك.',
            textAlign: TextAlign.center,
            style: T.meta.copyWith(color: c.accent, fontSize: 13),
          ),
          const Spacer(flex: 2),
          Text(
            'أسئلة قصيرة، وكل شيء قابل للتعديل بعدين.',
            style: T.meta.copyWith(color: c.muted),
          ),
          const SizedBox(height: 10),
          PrimaryButton(label: 'ابدأ', onPressed: () => _go(1)),
        ],
      ),
    );
  }

  bool _locating = false;

  Future<void> _useLocation() async {
    setState(() => _locating = true);
    try {
      final found = await locateMe(ref.read(defaultsProvider));
      if (!mounted) return;
      setState(() {
        _country = found.country;
        _city = found.city;
        _search.clear();
      });
    } catch (e) {
      if (mounted) {
        toast(
          context,
          e is LocationException ? e.message : 'ما قدرنا نحدد موقعك الحين',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Widget _cityStep() {
    final c = context.c;
    final defaults = ref.watch(defaultsProvider);
    final q = _search.text.trim();
    final all = [
      for (final co in defaults.countries)
        for (final ci in co.cities) (co, ci),
    ];
    final list = q.isEmpty
        ? all
        : all
              .where((e) => e.$2.name.contains(q) || e.$1.name.contains(q))
              .toList();
    return _page(
      title: 'في أي مدينة تعيش؟',
      subtitle: 'نحسب مواقيت الصلاة والإجازات والمناسبات الوطنية.',
      children: [
        PillButton(
          label: _locating ? 'نحدد موقعك…' : 'استخدم موقعي',
          icon: Icons.my_location,
          soft: true,
          expand: true,
          onPressed: _locating ? null : _useLocation,
        ),
        const SizedBox(height: 4),
        Text(
          'مرة واحدة لاختيار المدينة، ولا نتتبّع موقعك.',
          textAlign: TextAlign.center,
          style: T.meta.copyWith(color: c.muted),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'ابحث عن مدينتك',
            prefixIcon: Icon(Icons.search, size: 20),
          ),
        ),
        const SizedBox(height: 12),
        SettingsGroup(
          children: [
            if (_city != null && !all.any((e) => e.$2 == _city))
              SettingsRow(
                icon: Icons.my_location,
                title: _city!.name,
                subtitle: '${_country?.name ?? ''} · من موقعك',
                trailing: Icon(Icons.check, size: 20, color: c.accent),
              ),
            for (final (co, ci) in list.take(30))
              SettingsRow(
                title: ci.name,
                subtitle: co.name,
                trailing: ci == _city
                    ? Icon(Icons.check, size: 20, color: c.accent)
                    : null,
                onTap: () => setState(() {
                  _country = co;
                  _city = ci;
                }),
              ),
          ],
        ),
      ],
      next: 'التالي',
      onNext: _city == null ? null : () => _go(2),
    );
  }

  /// «عنك»: وش يتكرر في أسبوعك، والعمر والجنس اختياريًا. يرتّب ما بعدها.
  Widget _aboutStep() {
    final c = context.c;
    Widget chips(
      List<String> values,
      String? sel,
      ValueChanged<String?> f, {
      Map<String, String>? labels,
    }) => Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(nums(labels?[v] ?? v)),
            selected: sel == v,
            showCheckmark: false,
            onSelected: (on) => setState(() => f(on ? v : null)),
          ),
      ],
    );
    return _page(
      title: 'وش يتكرر في أسبوعك؟',
      subtitle: 'اختر كل اللي ينطبق عليك، ونرتّب الاقتراحات على وضعك.',
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.6,
          children: [
            for (final r in _roleOptions)
              if (!(_gender == 'male' && {'pregnant', 'infant'}.contains(r.$1)))
                _RoleTile(
                  label: r.$2,
                  icon: r.$3,
                  on: _roles.contains(r.$1),
                  onTap: () => setState(
                    () => _roles.contains(r.$1)
                        ? _roles.remove(r.$1)
                        : _roles.add(r.$1),
                  ),
                ),
          ],
        ),
        const SizedBox(height: 20),
        Text('عمرك (اختياري)', style: T.label.copyWith(color: c.muted)),
        const SizedBox(height: 8),
        chips(_ages, _age, (v) => _age = v),
        const SizedBox(height: 16),
        Text('الجنس (اختياري)', style: T.label.copyWith(color: c.muted)),
        const SizedBox(height: 8),
        chips(const ['male', 'female'], _gender, (v) {
          _gender = v;
          if (v == 'male') _roles.removeAll({'pregnant', 'infant'});
        }, labels: const {'male': 'ذكر', 'female': 'أنثى'}),
      ],
      next: 'التالي',
      onNext: () {
        _applyRoles();
        _go(3);
      },
    );
  }

  /// نعبّي الاختيارات الأولية حسب الوضع (والمستخدم يقدر يغيّرها).
  void _applyRoles() {
    setState(() {
      if (!_workTouched) {
        _work = _roles.contains('work') ? _Work.fixed : _Work.none;
      }
      for (final i in _interests) {
        if (i.tags.isNotEmpty &&
            i.tags.any(_roles.contains) &&
            !i.notFor.contains(_gender)) {
          _picked.add(i.id);
        }
      }
      if (_picked.contains('mother')) {
        _mother ??= MotherConfig(
          stage: _roles.contains('infant') && !_roles.contains('pregnant')
              ? MotherStage.infant
              : MotherStage.pregnant,
        );
      }
      for (final (role, type) in const [
        ('university', CommitmentType.university),
        ('school', CommitmentType.school),
      ]) {
        final has = _commitments.any((c) => c.type == type);
        if (_roles.contains(role) && !has) {
          _commitments.add(_presetCommitment(type));
        } else if (!_roles.contains(role) && has) {
          _commitments.removeWhere((c) => c.type == type);
        }
      }
    });
  }

  ClassConfig _presetCommitment(CommitmentType t) => ClassConfig(
    title: t.defaultTitle,
    type: t,
    weekdays: workdays(_weekend),
    start: t == CommitmentType.school ? 7 * 60 : 8 * 60,
    end: t == CommitmentType.school ? 13 * 60 + 30 : 12 * 60,
  );

  Widget _commitmentsGroup() {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text('التزاماتك', style: T.label.copyWith(color: c.muted)),
        const SizedBox(height: 8),
        SettingsGroup(
          children: [
            for (var k = 0; k < _commitments.length; k++)
              SettingsRow(
                icon: iconFor(_commitments[k].type.icon),
                title: _commitments[k].title,
                subtitle: ruleSummary(_commitments[k]),
                onTap: () async {
                  final cfg = await editRuleConfig(
                    context,
                    _commitments[k],
                    weekend: _weekend,
                  );
                  if (cfg is ClassConfig) {
                    setState(() => _commitments[k] = cfg);
                  }
                },
              ),
            SettingsRow(
              icon: Icons.add,
              title: 'أضف التزامًا',
              subtitle: 'محاضرات، مدرسة، نادي، دورة',
              onTap: () async {
                final cfg = await editRuleConfig(
                  context,
                  _presetCommitment(CommitmentType.other),
                  weekend: _weekend,
                );
                if (cfg is ClassConfig) setState(() => _commitments.add(cfg));
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _dayStep() {
    final c = context.c;
    Widget timeRow(String label, IconData icon, int v, ValueChanged<int> set) =>
        SettingsRow(
          icon: icon,
          title: label,
          trailing: Text(
            fmtTime(v),
            style: T.section.copyWith(color: c.accent, fontSize: 15),
          ),
          onTap: () async {
            final t = await pickTime(context, initial: v, title: label);
            if (t != null) setState(() => set(t));
          },
        );
    return _page(
      title: 'كيف يمشي يومك؟',
      subtitle: 'نبني الجدول حول نومك ودوامك، وتقدر تغيّره بعدين.',
      children: [
        SettingsGroup(
          children: [
            timeRow('أصحى', Icons.alarm, _wake, (t) => _wake = t),
            timeRow('أنام', Icons.bedtime_outlined, _sleep, (t) => _sleep = t),
          ],
        ),
        const SizedBox(height: 16),
        Text('عندك دوام؟', style: T.label.copyWith(color: c.muted)),
        const SizedBox(height: 8),
        Segmented<_Work>(
          values: _Work.values,
          labels: const ['لا', 'دوام ثابت', 'ورديات'],
          selected: _work,
          onChanged: (w) async {
            setState(() {
              _work = w;
              _workTouched = true;
            });
            if (w == _Work.shifts) {
              final cfg = await editRuleConfig(
                context,
                _shifts ?? _fixedWork(),
                weekend: _weekend,
              );
              if (cfg is WorkConfig) setState(() => _shifts = cfg);
            }
          },
        ),
        const SizedBox(height: 12),
        if (_work == _Work.fixed)
          SettingsGroup(
            children: [
              timeRow(
                'من',
                Icons.work_outline,
                _workFrom,
                (t) => _workFrom = t,
              ),
              timeRow('إلى', Icons.logout, _workTo, (t) => _workTo = t),
              SettingsRow(
                icon: Icons.calendar_today_outlined,
                title: 'الأيام',
                value: fmtWeekdays(_days),
                onTap: () async {
                  var sel = {..._days};
                  final ok = await showModalBottomSheet<bool>(
                    useRootNavigator: true,
                    context: context,
                    builder: (ctx) => StatefulBuilder(
                      builder: (ctx, set) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SheetHeader('أيام الدوام'),
                              WeekdayPicker(
                                selected: sel,
                                onChanged: (v) => set(() => sel = v),
                              ),
                              const SizedBox(height: 16),
                              PrimaryButton(
                                label: 'تم',
                                onPressed: () => Navigator.pop(ctx, true),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                  if (ok == true) setState(() => _workDays = sel);
                },
              ),
            ],
          ),
        if (_work == _Work.shifts && _shifts != null)
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.work_outline,
                title: 'الورديات',
                subtitle: ruleSummary(_shifts!),
                onTap: () async {
                  final cfg = await editRuleConfig(
                    context,
                    _shifts!,
                    weekend: _weekend,
                  );
                  if (cfg is WorkConfig) setState(() => _shifts = cfg);
                },
              ),
            ],
          ),
        _commitmentsGroup(),
      ],
      next: 'التالي',
      onNext: () => _go(4),
    );
  }

  WorkConfig _fixedWork() => WorkConfig(
    days: {
      for (final d in _days)
        d: [
          WorkPeriod(
            _workFrom,
            _workTo,
            breakStart: _workTo - _workFrom >= 6 * 60 ? 12 * 60 : null,
            breakEnd: _workTo - _workFrom >= 6 * 60 ? 12 * 60 + 30 : null,
          ),
        ],
    },
  );

  WorkConfig? get _workCfg => switch (_work) {
    _Work.none => null,
    _Work.fixed => _fixedWork(),
    _Work.shifts => _shifts,
  };

  Widget _interestsStep() {
    final c = context.c;
    final all = _interests
        .where((i) => !i.islam || _islam)
        .where((i) => !i.notFor.contains(_gender))
        .toList();
    bool suits(_Interest i) => i.tags.any(_roles.contains);
    // المناسب للوضع أولًا، والباقي تحت «عرض الكل» (لو اختار وضعًا).
    final mine = [...all.where(suits), ...all.where((i) => i.tags.isEmpty)];
    final rest = all.where((i) => i.tags.isNotEmpty && !suits(i)).toList();
    final list = _showAll || _roles.isEmpty ? [...mine, ...rest] : mine;
    return _page(
      title: 'وش تبغى يكون في يومك؟',
      subtitle: _roles.isEmpty
          ? 'اختر ما يهمّك، ونقترح له وقتًا في فراغك.'
          : 'رتّبناها على وضعك. اختر ما يهمّك.',
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            for (final i in list)
              _InterestTile(
                interest: i,
                on: _picked.contains(i.id),
                onTap: () => _toggleInterest(i),
              ),
          ],
        ),
        if (rest.isNotEmpty && _roles.isNotEmpty)
          Center(
            child: TextButton(
              onPressed: () => setState(() => _showAll = !_showAll),
              child: Text(_showAll ? 'اعرض المقترح فقط' : 'عرض الكل'),
            ),
          ),
      ],
      footer: Center(
        child: Text(
          'اخترت ${nums(_picked.length)} · تقدر تضيف أهدافك الخاصة بعدين',
          style: T.meta.copyWith(color: c.muted),
        ),
      ),
      next: 'التالي',
      onNext: () => _go(_wantsPeople ? 5 : 6),
    );
  }

  Future<void> _toggleInterest(_Interest i) async {
    if (_picked.contains(i.id)) {
      setState(() => _picked.remove(i.id));
      return;
    }
    // صحتي والحمل والطفل: نفتح إعدادها مباشرة.
    if (i.id == 'health') {
      final cfg = await editRuleConfig(
        context,
        _health ??
            HealthConfig(
              checks: [
                HealthCheck(
                  id: newId().substring(0, 8),
                  kind: HealthCheckKind.glucose,
                  title: HealthCheckKind.glucose.label,
                  times: const [7 * 60, 21 * 60],
                ),
              ],
            ),
      );
      if (cfg is HealthConfig && cfg.checks.isNotEmpty) {
        setState(() {
          _health = cfg;
          _picked.add(i.id);
        });
      }
      return;
    }
    if (i.id == 'mother') {
      final cfg = await editRuleConfig(
        context,
        _mother ??
            MotherConfig(
              stage: _roles.contains('infant') && !_roles.contains('pregnant')
                  ? MotherStage.infant
                  : MotherStage.pregnant,
            ),
      );
      if (cfg is MotherConfig) {
        setState(() {
          _mother = cfg;
          _picked.add(i.id);
        });
      }
      return;
    }
    setState(() => _picked.add(i.id));
  }

  Future<void> _pickPersonFromPhone() async {
    try {
      final picked = await FlutterNativeContactPicker().selectPhoneNumber();
      if (picked == null || !mounted) return;
      final phone =
          picked.selectedPhoneNumber ??
          ((picked.phoneNumbers?.isNotEmpty ?? false)
              ? picked.phoneNumbers!.first
              : null);
      setState(() {
        _personName.text = (picked.fullName ?? '').trim();
        _personPhone = phone?.replaceAll(RegExp(r'[^0-9+ ]'), '').trim();
      });
    } catch (_) {
      if (mounted) toast(context, 'ما قدرنا نفتح جهات الاتصال، اكتب الاسم');
    }
  }

  void _addPerson() {
    final name = _personName.text.trim();
    if (name.isEmpty) return;
    final (freq, method) = relationDefaults(_personRelation);
    setState(() {
      _people.add(
        Person(
          id: newId(),
          name: name,
          phone: _personPhone,
          relation: _personRelation,
          freq: freq,
          method: method,
          addedAt: Day.fromDateTime(DateTime.now()),
        ),
      );
      _personName.clear();
      _personPhone = null;
    });
  }

  Widget _peopleStep() {
    final c = context.c;
    return _page(
      title: 'مين تبغى تتواصل معه؟',
      subtitle:
          'أضف الأسماء مرة وحدة، والتطبيق يقترح اتصال أو رسالة أو زيارة حسب العلاقة، ويوزّعهم على أسابيعك.',
      children: [
        PillButton(
          label: 'اختر من جهات الاتصال',
          icon: Icons.contacts_outlined,
          soft: true,
          expand: true,
          onPressed: _pickPersonFromPhone,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _personName,
          onSubmitted: (_) => _addPerson(),
          decoration: const InputDecoration(
            hintText: 'أو اكتب الاسم، مثل: أمي',
          ),
        ),
        const SizedBox(height: 10),
        Segmented<Relation>(
          values: Relation.values,
          labels: [for (final r in Relation.values) r.label],
          selected: _personRelation,
          onChanged: (r) => setState(() => _personRelation = r),
        ),
        const SizedBox(height: 10),
        PillButton(
          label: 'أضف للقائمة',
          icon: Icons.person_add_alt,
          expand: true,
          onPressed: _addPerson,
        ),
        if (_people.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in _people)
                InputChip(
                  label: Text('${p.name} · ${p.relation.label}'),
                  onDeleted: () => setState(() => _people.remove(p)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        Text(
          'كم مرة في الأسبوع نقترح؟',
          style: T.label.copyWith(color: c.muted),
        ),
        const SizedBox(height: 8),
        Segmented<ContactLevel>(
          values: const [ContactLevel.low, ContactLevel.mid, ContactLevel.high],
          labels: const ['قليل · 1', 'متوسط · 3', 'كثير · 5'],
          selected: _level,
          onChanged: (v) => setState(() => _level = v),
        ),
      ],
      next: _people.isEmpty ? 'أضيفهم بعدين' : 'التالي',
      onNext: () => _go(6),
    );
  }

  Set<String> get _ruleKeys => {
    'meal:breakfast',
    'meal:dinner',
    for (final i in _interests)
      if (_picked.contains(i.id) && (!i.islam || _islam)) ...i.rules,
  };

  Widget _summaryStep() {
    final keys = _ruleKeys;
    final habits = libraryEntries
        .where((e) => keys.contains(e.key))
        .where(
          (e) => !{'prayers', 'meal:breakfast', 'meal:dinner'}.contains(e.key),
        )
        .toList();
    final work = _workCfg;
    final workMins = work == null
        ? 0
        : (work.days.values.firstOrNull ?? const <WorkPeriod>[]).fold<int>(
            0,
            (a, p) =>
                a +
                ((p.end - p.start) % minutesPerDay) -
                (p.hasBreak ? p.breakEnd! - p.breakStart! : 0),
          );
    final people = _wantsPeople;
    return _page(
      title: 'جدولك جاهز',
      subtitle: 'هذا ملخص يومك المعتاد. كل شيء قابل للتعديل.',
      children: [
        SettingsGroup(
          children: [
            if (keys.contains('prayers'))
              SettingsRow(
                icon: Icons.mosque_outlined,
                title: '${nums(5)} صلوات',
                subtitle: 'حسب أوقات ${_city?.name ?? ''}',
              ),
            for (final cm in _commitments)
              SettingsRow(
                icon: iconFor(cm.type.icon),
                title: cm.title,
                subtitle: ruleSummary(cm),
              ),
            if (_picked.contains('health') && _health != null)
              SettingsRow(
                icon: Icons.monitor_heart_outlined,
                title: 'صحتي',
                subtitle: ruleSummary(_health!),
              ),
            if (_picked.contains('mother') && _mother != null)
              SettingsRow(
                icon: Icons.child_care_outlined,
                title: 'الحمل والطفل',
                subtitle: ruleSummary(_mother!),
              ),
            if (work != null)
              SettingsRow(
                icon: Icons.work_outline,
                title: 'الدوام ${fmtDuration(workMins)}',
                subtitle: _work == _Work.fixed ? fmtWeekdays(_days) : 'ورديات',
              ),
            SettingsRow(
              icon: Icons.auto_stories_outlined,
              title:
                  '${nums(habits.length)} ${habits.length <= 10 && habits.length > 2 ? 'عادات' : 'عادة'} يومية',
              subtitle: habits.isEmpty
                  ? 'تضيفها من «روتيني»'
                  : habits.map((e) => e.title).join('، '),
            ),
            if (people)
              SettingsRow(
                icon: Icons.forum_outlined,
                title: '${nums(_level.perWeek)} اقتراحات تواصل أسبوعيًا',
                subtitle: _people.isEmpty
                    ? 'تضيف الأسماء من الإعدادات › التواصل'
                    : _people.map((p) => p.name).join('، '),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsGroup(
          children: [
            SettingsRow(
              title: 'ذكّرني بالمهام',
              subtitle: 'نطلب إذن الإشعارات',
              toggle: _remind,
              onToggle: (v) => setState(() => _remind = v),
            ),
          ],
        ),
      ],
      next: 'افتح يومي',
      onNext: _city == null ? null : _finish,
    );
  }

  Future<void> _finish() async {
    setState(() => _generating = true);
    final now = DateTime.now();
    final today = Day.fromDateTime(now);
    final co = _country!;
    final ci = _city!;
    final profile = UserProfile(
      name: '',
      country: co.code,
      city: ci.name,
      lat: ci.lat,
      lng: ci.lng,
      timezone: ci.tz,
      religion: _islam ? Religion.islam : Religion.none,
      calcMethod: co.method,
      wake: _wake,
      sleep: _sleep,
      joinedAt: now,
      weekend: co.weekend,
      currency: co.currency,
      ageGroup: _age,
      gender: _gender,
      roles: {..._roles},
    );
    final keys = _ruleKeys;
    final work = _workCfg;
    final rules = <Rule>[
      for (final e in libraryEntries)
        if (keys.contains(e.key) && (!e.islamOnly || _islam))
          Rule(id: newId(), key: e.key, validFrom: today, config: e.build()),
      if (work != null)
        Rule(id: newId(), key: 'work', validFrom: today, config: work),
      for (final cm in _commitments)
        Rule(
          id: newId(),
          key: 'class:${newId().substring(0, 8)}',
          validFrom: today,
          config: cm,
        ),
      if (_picked.contains('health') && _health != null)
        Rule(id: newId(), key: 'health', validFrom: today, config: _health!),
      if (_picked.contains('mother') && _mother != null)
        Rule(id: newId(), key: 'mother', validFrom: today, config: _mother!),
    ];
    final people = _wantsPeople;
    final family = _picked.contains('family');
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    if (_remind) {
      try {
        await NotificationService.instance.requestPermissions();
      } catch (_) {
        // بدون إذن يكمل التطبيق، ويُطلب لاحقًا من الإعدادات.
      }
    }
    await ref
        .read(appDataProvider.notifier)
        .completeOnboarding(
          profile,
          rules,
          contacts: ContactsConfig(enabled: people, level: _level).withOuting(
            defaultOutings
                .firstWhere((o) => o.kind == OutingKind.family)
                .copyWith(enabled: family),
          ),
          settings: ref
              .read(appDataProvider)
              .settings
              .copyWith(eveningReview: true),
        );
    final ctrl = ref.read(appDataProvider.notifier);
    for (final p in _people) {
      await ctrl.savePerson(p);
    }
    if (mounted) context.go('/day');
  }
}

class _Generating extends StatefulWidget {
  const _Generating({
    required this.city,
    required this.country,
    required this.islam,
  });
  final String city;
  final String country;
  final bool islam;
  @override
  State<_Generating> createState() => _GeneratingState();
}

class _GeneratingState extends State<_Generating> {
  int _shown = 0;
  Timer? _t;
  late final _lines = [
    if (widget.islam) 'أوقات الصلاة في ${widget.city}',
    'الإجازات الأسبوعية في ${widget.country}',
    'الدوام والاستراحة والمواعيد الثابتة',
    'توزيع العادات على أوقاتك الفاضية',
    'التنبيهات من جدولك نفسه',
  ];

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 320), (_) {
      if (_shown < _lines.length) setState(() => _shown++);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('نحوّل روتينك إلى جدول', style: T.onboardTitle),
          const SizedBox(height: 6),
          Text(
            'نجهز الأيام الجاية بالتفصيل، والأبعد يتولد تلقائيًا من روتينك.',
            style: T.body.copyWith(color: c.muted),
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < _lines.length; i++)
            AnimatedOpacity(
              opacity: i < _shown ? 1 : .25,
              duration: const Duration(milliseconds: 250),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      i < _shown ? Icons.check_circle : Icons.circle_outlined,
                      size: 20,
                      color: i < _shown ? c.good : c.line,
                    ),
                    const SizedBox(width: 10),
                    Text(_lines[i], style: T.body),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// مربع كبير مثل الإضافات: أيقونة، اسم، وصف قصير، وعلامة التفعيل في الزاوية.
class _InterestTile extends StatelessWidget {
  const _InterestTile({
    required this.interest,
    required this.on,
    required this.onTap,
  });
  final _Interest interest;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      selected: on,
      label: interest.label,
      excludeSemantics: true,
      child: Material(
        color: on ? c.accentSoft : c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(R.lg),
          side: BorderSide(color: on ? c.accent : c.line, width: on ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: on ? c.accent : c.sunk,
                        borderRadius: BorderRadius.circular(R.md),
                      ),
                      child: Icon(
                        interest.icon,
                        size: 26,
                        color: on ? c.onAccent : c.ink2,
                      ),
                    ),
                    const Spacer(),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: on ? c.accent : Colors.transparent,
                        border: Border.all(
                          color: on ? c.accent : c.lineStrong,
                          width: 1.5,
                        ),
                      ),
                      child: on
                          ? Icon(Icons.check, size: 15, color: c.onAccent)
                          : null,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  interest.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.cardTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  interest.desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.meta.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.label,
    required this.icon,
    required this.on,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      selected: on,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: on ? c.accentSoft : c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(R.md),
          side: BorderSide(color: on ? c.accent : c.line, width: on ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(icon, size: 22, color: on ? c.accent : c.ink2),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.label.copyWith(fontSize: 14),
                  ),
                ),
                if (on) Icon(Icons.check_circle, size: 18, color: c.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
