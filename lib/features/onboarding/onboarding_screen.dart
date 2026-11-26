import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/defaults.dart';
import '../../data/library.dart';
import '../../services/notifications.dart';
import '../../state/providers.dart';
import '../routine/labels.dart';
import '../routine/rule_editors.dart';

/// التهيئة: الاسم، الدولة والمدينة، الدين، الصحيان والنوم، ثم «تشكيلتي»،
/// ثم مكتبة الفئات ببطاقات تُفعّل بنقرة. التواصل في المرحلة الثانية.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _steps = 7;
  final _pages = PageController();
  int _step = 0;

  final _name = TextEditingController();
  Country? _country;
  City? _city;
  Religion _religion = Religion.islam;
  int _wake = 4 * 60 + 30;
  int _sleep = 22 * 60 + 30;
  final List<(String, RuleConfig)> _fixed = [];
  final Set<String> _library = {
    'prayers',
    'adhkar',
    'quran:wird',
    'meal:breakfast',
    'meal:dinner',
    'habit:walk',
    'reminders',
  };
  bool _generating = false;

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    _pages.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                children: [
                  for (var i = 0; i < _steps; i++)
                    Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i <= _step ? c.accent2 : c.line,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_step > 0 && !_generating)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconButton(
                  tooltip: 'رجوع',
                  onPressed: () => _go(_step - 1),
                  icon: const Icon(Icons.arrow_forward),
                ),
              )
            else
              const SizedBox(height: 48),
            Expanded(
              child: _generating
                  ? _Generating(
                      city: _city?.name ?? '',
                      country: _country?.name ?? '',
                      islam: _religion == Religion.islam,
                    )
                  : PageView(
                      controller: _pages,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _welcome(),
                        _nameStep(),
                        _countryStep(),
                        _religionStep(),
                        _sleepStep(),
                        _fixedStep(),
                        _libraryStep(),
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
    required Widget bottom,
  }) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w700,
              fontSize: 24,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(subtitle, style: TextStyle(color: c.ink2)),
            ),
          const SizedBox(height: 16),
          Expanded(child: ListView(children: children)),
          bottom,
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
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(Icons.schedule, size: 52, color: c.accentInk),
          ),
          const SizedBox(height: 20),
          const Text(
            'مُتَّسَع',
            style: TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w700,
              fontSize: 34,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'تختار كيف تبغى تعيش يومك، والتطبيق يحوّل اختياراتك إلى جدول قابل للتنفيذ، ويبيّن لك مدى التزامك مع الوقت.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.ink2, fontSize: 15),
          ),
          const SizedBox(height: 14),
          Text(
            'رتّب يومك، وخلّ فيه وقت للناس اللي يهمّونك.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.accent2, fontSize: 13),
          ),
          const Spacer(flex: 2),
          PrimaryButton(label: 'ابدأ', onPressed: () => _go(1)),
        ],
      ),
    );
  }

  Widget _nameStep() => _page(
    title: 'وش نناديك؟',
    subtitle: 'نستخدم اسمك في الترحيب وتوقيع الرسائل لاحقًا. يبقى على جهازك.',
    children: [
      TextField(
        controller: _name,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => _go(2),
        decoration: const InputDecoration(hintText: 'اسمك'),
      ),
    ],
    bottom: PrimaryButton(label: 'التالي', onPressed: () => _go(2)),
  );

  Widget _countryStep() {
    final defaults = ref.watch(defaultsProvider);
    final c = context.c;
    return _page(
      title: 'وين تعيش؟',
      subtitle: 'نحسب مواقيت الصلاة والإجازات حسب دولتك ومدينتك، بدون إنترنت.',
      children: [
        for (final co in defaults.countries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MCard(
              border: co == _country ? c.accent2 : null,
              color: co == _country ? c.nowCard : null,
              onTap: () => setState(() {
                _country = co;
                _city = co.cities.first;
              }),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    co.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${co.cities.first.name} · ${co.weekendLabel}',
                    style: TextStyle(color: c.ink2, fontSize: 13),
                  ),
                  if (co == _country && co.cities.length > 1) ...[
                    const SizedBox(height: 10),
                    ChoiceChips<City>(
                      values: co.cities,
                      label: (ci) => ci.name,
                      selected: (ci) => ci == _city,
                      onSelected: (ci) => setState(() => _city = ci),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
      bottom: PrimaryButton(
        label: 'التالي',
        onPressed: _city == null ? null : () => _go(3),
      ),
    );
  }

  Widget _religionStep() {
    final c = context.c;
    Widget option(Religion r, String title, String desc) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MCard(
        border: r == _religion ? c.accent2 : null,
        color: r == _religion ? c.nowCard : null,
        onTap: () => setState(() => _religion = r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Text(desc, style: TextStyle(color: c.ink2, fontSize: 13)),
          ],
        ),
      ),
    );
    return _page(
      title: 'المحتوى الديني',
      subtitle: 'نضيفه كحزمة محتوى، وتقدر تغيّره من الإعدادات.',
      children: [
        option(
          Religion.islam,
          'الإسلام',
          'الصلوات، الأذكار، ورد القرآن، الجمعة والتاريخ الهجري',
        ),
        option(Religion.none, 'بدون', 'جدول بدون محتوى ديني'),
      ],
      bottom: Column(
        children: [
          PrimaryButton(label: 'التالي', onPressed: () => _go(4)),
          TextButton(
            onPressed: () {
              setState(() => _religion = Religion.none);
              _go(4);
            },
            child: const Text('تخطَّ السؤال'),
          ),
        ],
      ),
    );
  }

  Widget _sleepStep() => _page(
    title: 'متى تصحى ومتى تنام؟',
    subtitle: 'نحجز وقت النوم ولا نحط فيه شي، ونرتّب يومك بين الوقتين.',
    children: [
      TimeField(
        label: 'الصحيان',
        value: _wake,
        onChanged: (v) => setState(() => _wake = v),
      ),
      const SizedBox(height: 10),
      TimeField(
        label: 'النوم',
        value: _sleep,
        onChanged: (v) => setState(() => _sleep = v),
      ),
    ],
    bottom: PrimaryButton(label: 'التالي', onPressed: () => _go(5)),
  );

  Widget _fixedStep() {
    final c = context.c;
    final weekend = _country?.weekend ?? const {5, 6};
    Future<void> add(String kind) async {
      final RuleConfig initial = switch (kind) {
        'work' => WorkConfig(
          days: {
            for (final d in workdays(weekend))
              d: [const WorkPeriod(450, 960, breakStart: 720, breakEnd: 750)],
          },
        ),
        'kid' => const KidConfig(child: '', days: {}),
        _ => const ClassConfig(
          title: '',
          weekdays: {DateTime.tuesday},
          start: 17 * 60,
          end: 18 * 60,
        ),
      };
      final cfg = await editRuleConfig(context, initial, weekend: weekend);
      if (cfg == null) return;
      final key = switch (kind) {
        'work' => 'work',
        'kid' => 'kid:${newId().substring(0, 8)}',
        _ => 'class:${newId().substring(0, 8)}',
      };
      setState(() {
        _fixed.removeWhere((e) => e.$1 == 'work' && key == 'work');
        _fixed.add((key, cfg));
      });
    }

    Widget example(String kind, String title, String desc, String icon) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: MCard(
            dashed: true,
            color: c.bg,
            border: c.accent,
            onTap: () => add(kind),
            child: Row(
              children: [
                Icon(iconFor(icon)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        desc,
                        style: TextStyle(color: c.ink2, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.add_circle_outline, color: c.accent2),
              ],
            ),
          ),
        );

    return _page(
      title: 'تشكيلتي',
      subtitle:
          'مواعيدك الثابتة ما تتحرك أبدًا، والباقي يترتب حولها. تقدر تكمّلها لاحقًا.',
      children: [
        for (final (key, cfg) in _fixed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MCard(
              child: Row(
                children: [
                  Icon(iconFor(ruleIcon(cfg))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ruleTitle(cfg),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          ruleSummary(cfg),
                          style: TextStyle(color: c.ink2, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'احذف',
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        setState(() => _fixed.removeWhere((e) => e.$1 == key)),
                  ),
                ],
              ),
            ),
          ),
        if (!_fixed.any((e) => e.$1 == 'work'))
          example(
            'work',
            'الدوام',
            'صباحي، مسائي، ليلي أو مخصص، مع الاستراحة',
            'work',
          ),
        example(
          'kid',
          'توصيل واستلام',
          'اختر الطفل، وفعّل التوصيل أو الاستلام أو الاثنين',
          'kid',
        ),
        example(
          'class',
          'حصة أو دورة',
          'حصة موسيقى، نادي، جامعة أو دورة بموعد أسبوعي',
          'class',
        ),
      ],
      bottom: Column(
        children: [
          PrimaryButton(label: 'التالي', onPressed: () => _go(6)),
          if (_fixed.isEmpty)
            TextButton(
              onPressed: () => _go(6),
              child: const Text('أكمل لاحقًا'),
            ),
        ],
      ),
    );
  }

  Widget _libraryStep() {
    final c = context.c;
    final islam = _religion == Religion.islam;
    final entries = libraryEntries.where((e) => !e.islamOnly || islam).toList();
    return _page(
      title: 'وش تبغى في يومك؟',
      subtitle: 'فعّل بنقرة، وخصّص كل وحدة من «روتيني» بعدين.',
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MCard(
              border: _library.contains(e.key) ? c.accent2 : null,
              color: _library.contains(e.key) ? c.nowCard : null,
              onTap: () => setState(
                () => _library.contains(e.key)
                    ? _library.remove(e.key)
                    : _library.add(e.key),
              ),
              child: Row(
                children: [
                  Icon(iconFor(e.icon)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          e.description,
                          style: TextStyle(color: c.ink2, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _library.contains(e.key)
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: _library.contains(e.key) ? c.accent2 : c.line,
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'التواصل مع الناس، والأهداف، والطلعات تجي في المرحلة الثانية.',
            style: TextStyle(color: c.muted, fontSize: 12.5),
          ),
        ),
      ],
      bottom: PrimaryButton(label: 'جهّز جدولي', onPressed: _finish),
    );
  }

  Future<void> _finish() async {
    setState(() => _generating = true);
    final now = DateTime.now();
    final today = Day.fromDateTime(now);
    final co = _country!;
    final ci = _city!;
    final profile = UserProfile(
      name: _name.text.trim(),
      country: co.code,
      city: ci.name,
      lat: ci.lat,
      lng: ci.lng,
      timezone: ci.tz,
      religion: _religion,
      calcMethod: co.method,
      wake: _wake,
      sleep: _sleep,
      joinedAt: now,
      weekend: co.weekend,
      currency: co.currency,
    );
    final islam = _religion == Religion.islam;
    final rules = <Rule>[
      for (final e in libraryEntries)
        if (_library.contains(e.key) && (!e.islamOnly || islam))
          Rule(id: newId(), key: e.key, validFrom: today, config: e.build()),
      for (final (key, cfg) in _fixed)
        Rule(id: newId(), key: key, validFrom: today, config: cfg),
    ];
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    // نطلب إذن التنبيهات بعد التهيئة مع شرح، وقبل أن ينتقل الموجّه إلى «يومي».
    final ask = await askNotificationPermission(context);
    if (ask == true) await NotificationService.instance.requestPermissions();
    await ref.read(appDataProvider.notifier).completeOnboarding(profile, rules);
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
          const Text(
            'نحوّل روتينك إلى جدول',
            style: TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w700,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'نجهز الأيام الجاية بالتفصيل، والأبعد يتولد تلقائيًا من روتينك.',
            style: TextStyle(color: c.ink2),
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
                      color: i < _shown ? c.good : c.line,
                    ),
                    const SizedBox(width: 10),
                    Text(_lines[i]),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
