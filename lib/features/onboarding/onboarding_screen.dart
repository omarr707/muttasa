import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/defaults.dart';
import '../../data/library.dart';
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
    this.rules, {
    this.islam = false,
  });
  final String id;
  final String label;
  final IconData icon;
  final List<String> rules;
  final bool islam;
}

const _interests = [
  _Interest('prayer', 'الصلاة في وقتها', Icons.mosque_outlined, [
    'prayers',
    'adhkar',
  ], islam: true),
  _Interest('quran', 'القرآن', Icons.auto_stories_outlined, [
    'quran:wird',
  ], islam: true),
  _Interest('sport', 'الرياضة', Icons.directions_walk, ['habit:walk']),
  _Interest('read', 'القراءة', Icons.menu_book_outlined, ['habit:read']),
  _Interest('lang', 'تعلّم لغة', Icons.translate, ['habit:language']),
  _Interest('water', 'شرب الماء', Icons.water_drop_outlined, ['reminders']),
  _Interest('family', 'وقت مع الأهل', Icons.family_restroom, []),
  _Interest('people', 'التواصل مع الناس', Icons.forum_outlined, []),
  _Interest('sleep', 'نوم مبكر', Icons.bedtime_outlined, []),
  _Interest('save', 'الادخار', Icons.savings_outlined, []),
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
  bool _remind = true;
  bool _generating = false;

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
                            onPressed: () => _go(_step - 1),
                            icon: const Icon(Icons.arrow_forward, size: 20),
                          ),
                          for (var i = 1; i <= 4; i++)
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
                          if (_step < 4)
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: c.muted,
                                textStyle: T.label,
                              ),
                              onPressed: () => _go(_step + 1),
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
                        _dayStep(),
                        _interestsStep(),
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
            'أربع أسئلة قصيرة، وكل شيء قابل للتعديل بعدين.',
            style: T.meta.copyWith(color: c.muted),
          ),
          const SizedBox(height: 10),
          PrimaryButton(label: 'ابدأ', onPressed: () => _go(1)),
        ],
      ),
    );
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
            setState(() => _work = w);
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
      ],
      next: 'التالي',
      onNext: () => _go(3),
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
    final list = _interests.where((i) => !i.islam || _islam).toList();
    return _page(
      title: 'وش تبغى يكون في يومك؟',
      subtitle: 'اختر ما يهمّك، ونقترح له وقتًا في فراغك.',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            for (final i in list)
              FilterChip(
                avatar: Icon(
                  i.icon,
                  size: 18,
                  color: _picked.contains(i.id) ? c.accent : c.ink2,
                ),
                label: Text(i.label),
                selected: _picked.contains(i.id),
                showCheckmark: false,
                labelStyle: T.label.copyWith(
                  fontSize: 13,
                  color: _picked.contains(i.id) ? c.accent : c.ink,
                ),
                side: BorderSide(
                  color: _picked.contains(i.id) ? c.accent : c.line,
                ),
                onSelected: (v) => setState(
                  () => v ? _picked.add(i.id) : _picked.remove(i.id),
                ),
              ),
          ],
        ),
      ],
      footer: Center(
        child: Text(
          'اخترت ${nums(_picked.length)} · تقدر تضيف أهدافك الخاصة بعدين',
          style: T.meta.copyWith(color: c.muted),
        ),
      ),
      next: 'التالي',
      onNext: () => _go(4),
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
    final people = _picked.contains('people') || _picked.contains('family');
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
                title: '${nums(3)} اقتراحات تواصل أسبوعيًا',
                subtitle: 'تضيف الأسماء من الإعدادات › التواصل',
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
    );
    final keys = _ruleKeys;
    final work = _workCfg;
    final rules = <Rule>[
      for (final e in libraryEntries)
        if (keys.contains(e.key) && (!e.islamOnly || _islam))
          Rule(id: newId(), key: e.key, validFrom: today, config: e.build()),
      if (work != null)
        Rule(id: newId(), key: 'work', validFrom: today, config: work),
    ];
    final people = _picked.contains('people') || _picked.contains('family');
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
          contacts: ContactsConfig(enabled: people),
          settings: ref
              .read(appDataProvider)
              .settings
              .copyWith(eveningReview: true),
        );
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
