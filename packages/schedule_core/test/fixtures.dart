import 'package:schedule_core/schedule_core.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

bool _tzReady = false;

void initTz() {
  if (_tzReady) return;
  tzdata.initializeTimeZones();
  _tzReady = true;
}

UserProfile riyadh({DateTime? joinedAt, int wake = 270, int sleep = 1350}) =>
    UserProfile(
      name: 'عمر',
      country: 'SA',
      city: 'الرياض',
      lat: 24.7136,
      lng: 46.6753,
      timezone: 'Asia/Riyadh',
      joinedAt: joinedAt ?? DateTime(2026, 1, 1),
      wake: wake,
      sleep: sleep,
    );

UserProfile cairo() => UserProfile(
  name: 'عمر',
  country: 'EG',
  city: 'القاهرة',
  lat: 30.0444,
  lng: 31.2357,
  timezone: 'Africa/Cairo',
  calcMethod: CalcMethod.egyptian,
  joinedAt: DateTime(2026, 1, 1),
);

Rule rule(String key, RuleConfig c, {Day? from, Day? to}) => Rule(
  id: '$key-${from?.key ?? 'base'}',
  key: key,
  validFrom: from ?? const Day(2026, 1, 1),
  validTo: to,
  config: c,
);

final basicRules = <Rule>[
  rule('prayers', const PrayersConfig()),
  rule('adhkar', const AdhkarConfig()),
  rule(
    'quran:wird',
    const FlexConfig(
      kind: RuleKind.quran,
      title: 'ورد القرآن',
      icon: 'book',
      duration: 10,
      windows: [Window.afterFajr],
      pages: 4,
      book: 'المصحف',
      category: 'quran',
    ),
  ),
  rule(
    'meal:breakfast',
    const FlexConfig(
      kind: RuleKind.meal,
      title: 'الفطور',
      icon: 'meal',
      duration: 25,
      windows: [Window.morning],
      preferred: 6 * 60 + 30,
      category: 'meals',
    ),
  ),
  rule(
    'habit:walk',
    const FlexConfig(
      kind: RuleKind.habit,
      title: 'المشي',
      icon: 'walk',
      duration: 30,
      windows: [Window.afternoon],
      recurrence: TimesPerWeek(3),
      track: TrackMode.start,
      optional: true,
    ),
  ),
  rule('reminders', const RemindersConfig()),
];

WorkConfig morningWork({
  int start = 450,
  int end = 960,
  int? bs = 720,
  int? be = 750,
}) => WorkConfig(
  days: {
    for (final d in [
      DateTime.sunday,
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
    ])
      d: [WorkPeriod(start, end, breakStart: bs, breakEnd: be)],
  },
);

EngineInput input({
  UserProfile? profile,
  List<Rule>? rules,
  Day today = const Day(2026, 11, 26),
  int now = 9 * 60,
  Map<String, DayOverride> overrides = const {},
  Map<String, ItemLog> logs = const {},
  List<OneOff> oneOffs = const [],
  List<CarryOver> carries = const [],
  AppSettings settings = const AppSettings(),
}) {
  initTz();
  final p = profile ?? riyadh();
  final calc = PrayerCalculator.forProfile(p);
  return EngineInput(
    profile: p,
    settings: settings,
    rules: rules ?? basicRules,
    oneOffs: oneOffs,
    overrides: overrides,
    carries: carries,
    logs: logs,
    prayers: calc.forDay,
    today: today,
    nowMinute: now,
  );
}
