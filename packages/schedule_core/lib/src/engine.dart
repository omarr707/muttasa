import 'contacts.dart';
import 'partner.dart';
import 'season.dart';
import 'day.dart';
import 'format.dart';
import 'prayer.dart';
import 'plan.dart';
import 'profile.dart';
import 'records.dart';
import 'recurrence.dart';
import 'rules.dart';

/// كل ما يحتاجه المحرك. لا شيء من Flutter ولا القاعدة.
class EngineInput {
  EngineInput({
    required this.profile,
    this.settings = const AppSettings(),
    required this.rules,
    this.oneOffs = const [],
    this.overrides = const {},
    this.carries = const [],
    this.logs = const {},
    this.people = const [],
    this.contacts = const ContactsConfig(),
    this.modes = const [],
    this.holidays = const [],
    this.partner = const PartnerShare(),
    this.imported = const [],
    required this.prayers,
    required this.today,
    required this.nowMinute,
  });

  final UserProfile profile;
  final AppSettings settings;
  final List<Rule> rules;
  final List<OneOff> oneOffs;

  /// بمفتاح [recordKey].
  final Map<String, DayOverride> overrides;
  final List<CarryOver> carries;

  /// بمفتاح [recordKey].
  final Map<String, ItemLog> logs;

  /// قائمة التواصل وإعداداتها.
  final List<Person> people;
  final ContactsConfig contacts;

  /// الأوضاع: إجازة، سفر، إيقاف مؤقت.
  final List<LifeMode> modes;

  /// المناسبات الوطنية والعطل لدولة المستخدم.
  final List<Holiday> holidays;

  /// مشاركة مشاوير الأولاد مع الزوج أو الزوجة.
  final PartnerShare partner;

  /// مواعيد التقويم المستوردة (قراءة فقط).
  final List<ImportedEvent> imported;

  /// مواقيت اليوم. لمن اختار «بدون» دين تُستخدم مراسٍ محايدة.
  final DayPrayers Function(Day) prayers;
  final Day today;
  final int nowMinute;

  EngineInput copyWith({
    List<Rule>? rules,
    Map<String, DayOverride>? overrides,
    Map<String, ItemLog>? logs,
    List<CarryOver>? carries,
    List<OneOff>? oneOffs,
    UserProfile? profile,
    AppSettings? settings,
    Day? today,
    int? nowMinute,
  }) => EngineInput(
    profile: profile ?? this.profile,
    settings: settings ?? this.settings,
    rules: rules ?? this.rules,
    oneOffs: oneOffs ?? this.oneOffs,
    overrides: overrides ?? this.overrides,
    carries: carries ?? this.carries,
    logs: logs ?? this.logs,
    people: people,
    contacts: contacts,
    modes: modes,
    holidays: holidays,
    partner: partner,
    imported: imported,
    prayers: prayers,
    today: today ?? this.today,
    nowMinute: nowMinute ?? this.nowMinute,
  );
}

const _step = 5;

/// صفحات المصحف.
const mushafPages = 604;

/// ألقاب الصلوات ومددها في الجدول.
const prayerTitles = {
  'fajr': 'صلاة الفجر',
  'dhuhr': 'صلاة الظهر',
  'jumuah': 'صلاة الجمعة',
  'asr': 'صلاة العصر',
  'maghrib': 'صلاة المغرب',
  'isha': 'صلاة العشاء',
};

/// المحرك: دالة نقية. نفس المدخلات تعطي نفس اليوم دائمًا.
class ScheduleEngine {
  ScheduleEngine(this.input);

  final EngineInput input;
  final _dayCache = <Day, DayPlan>{};
  final _baseCache = <Day, DayPlan>{};
  final _weekCache = <Day, Map<String, Set<Day>>>{};
  final _contactCache = <Day, Map<Day, List<Person>>>{};
  final _ctxCache = <Day, DayContext>{};

  UserProfile get _p => input.profile;

  DayPlan day(Day d) =>
      _dayCache.putIfAbsent(d, () => _generate(d, withWeekly: true));

  List<DayPlan> week(Day anyDay) {
    final ws = anyDay.weekStart;
    return [for (var i = 0; i < 7; i++) day(ws.add(i))];
  }

  // ---------------------------------------------------------------------------
  // القواعد السارية
  // ---------------------------------------------------------------------------

  /// النسخة السارية من كل قاعدة في يوم [d]، غير الموقوفة.
  List<Rule> rulesOn(Day d, {bool includePaused = false}) {
    final byKey = <String, Rule>{};
    for (final r in input.rules) {
      if (!r.activeOn(d)) continue;
      if (!includePaused && r.pausedOn(d)) continue;
      byKey[r.key] = r;
    }
    final list = byKey.values.toList()..sort((a, b) => a.key.compareTo(b.key));
    return list;
  }

  T? _ruleOfKind<T extends RuleConfig>(List<Rule> rules) {
    for (final r in rules) {
      if (r.config is T) return r.config as T;
    }
    return null;
  }

  /// سياق اليوم: الهجري، رمضان، العيد، الصيام، الوضع، العطلة.
  DayContext contextFor(Day d) => _ctxCache.putIfAbsent(
    d,
    () => dayContext(
      d,
      profile: _p,
      season: input.settings.season,
      modes: input.modes,
      holidays: input.holidays,
    ),
  );

  SeasonSettings get _season => input.settings.season;

  DayPrayers prayersFor(Day d) {
    if (!_p.islam) return DayPrayers.neutral;
    final pr = input.prayers(d);
    final ctx = contextFor(d);
    final method = ctx.mode?.calcMethod ?? _p.calcMethod;
    // أم القرى: العشاء بعد المغرب بـ 90 دقيقة، ونجعلها 120 في رمضان.
    if (ctx.ramadan && method == CalcMethod.ummAlQura) {
      return DayPrayers(
        fajr: pr.fajr,
        sunrise: pr.sunrise,
        dhuhr: pr.dhuhr,
        asr: pr.asr,
        maghrib: pr.maghrib,
        isha: pr.maghrib + 120,
      );
    }
    return pr;
  }

  int get bedtime {
    final s = _p.sleep;
    return s >= _p.wake ? s : s + minutesPerDay;
  }

  /// وقت النوم ليوم بعينه: لرمضان وقت نوم خاص.
  int bedtimeOn(Day d) {
    if (!contextFor(d).ramadan) return bedtime;
    final s = _season.ramadanSleep;
    return s >= _p.wake ? s : s + minutesPerDay;
  }

  /// فترات الدوام ليوم [d] بعد المواسم والأوضاع. فارغة = لا دوام.
  List<WorkPeriod> workPeriodsOn(Day d, WorkConfig work) {
    final ctx = contextFor(d);
    if (ctx.workOff) return const [];
    final periods = work.days[d.weekday] ?? const [];
    if (periods.isEmpty) return periods;
    if (ctx.ramadan && _season.ramadanWork) {
      // الوردية الليلية تبقى كما هي، والباقي يأخذ دوام رمضان.
      final night = periods.where((p) => p.crossesMidnight).toList();
      if (night.isNotEmpty) return night;
      return [WorkPeriod(_season.ramadanWorkStart, _season.ramadanWorkEnd)];
    }
    return periods;
  }

  /// نهاية وردية الأمس إن عبرت منتصف الليل.
  int? _nightTail(Day d) {
    final y = d.prev;
    if (_override(y, 'work')?.off == true) return null;
    final work = _ruleOfKind<WorkConfig>(rulesOn(y));
    if (work == null) return null;
    final periods = workPeriodsOn(y, work);
    for (final p in periods) {
      if (p.crossesMidnight && p.end > 0) return p.end;
    }
    return null;
  }

  DayOverride? _override(Day d, String key) =>
      input.overrides[recordKey(d, key)];
  ItemLog? _log(Day d, String key) => input.logs[recordKey(d, key)];

  // ---------------------------------------------------------------------------
  // التوليد
  // ---------------------------------------------------------------------------

  DayPlan _generate(Day d, {required bool withWeekly}) {
    if (!withWeekly) {
      final cached = _baseCache[d];
      if (cached != null) return cached;
    }
    final rules = rulesOn(d);
    final ctx = contextFor(d);
    final pr = prayersFor(d);
    // في الصيام ينتهي النوم قبل الفجر بساعة على الأقل (للسحور).
    final wake = ctx.fasting && pr.fajr - 60 < _p.wake
        ? (pr.fajr - 60).clamp(0, minutesPerDay)
        : _p.wake;
    final bed = bedtimeOn(d);
    final busy = <Busy>[];
    final fixed = <PlanItem>[];
    final items = <PlanItem>[];
    final lines = <ReminderLine>[];
    final unplaced = <Unplaced>[];

    // 1) النوم المحجوز.
    final tail = _nightTail(d);
    int dayWake = wake;
    if (tail != null) {
      final sleepStart = tail + 30;
      busy.add(
        Busy(
          Span(sleepStart, sleepStart + 7 * 60),
          BusyKind.sleep,
          'وقت النوم',
        ),
      );
      dayWake = sleepStart + 7 * 60;
      fixed.add(
        PlanItem(
          key: 'work#tail',
          ruleKey: 'work',
          kind: ItemKind.work,
          title: 'الدوام',
          subtitle: 'ذيل وردية أمس',
          icon: 'work',
          start: 0,
          end: tail,
          fixed: true,
          counted: false,
          track: TrackMode.auto,
          category: 'work',
        ),
      );
      busy.add(Busy(Span(0, tail), BusyKind.work, 'الدوام', key: 'work#tail'));
    } else {
      busy.add(Busy(Span(0, wake), BusyKind.sleep, 'وقت النوم'));
    }

    // 2) الدوام.
    final workOff = _override(d, 'work')?.off == true;
    final work = _ruleOfKind<WorkConfig>(rules);
    var nightShiftTonight = false;
    if (work != null && !workOff) {
      final periods = workPeriodsOn(d, work);
      for (var i = 0; i < periods.length; i++) {
        final p = periods[i];
        final end = p.crossesMidnight ? minutesPerDay : p.end;
        if (p.crossesMidnight) nightShiftTonight = true;
        final brk = p.hasBreak ? Span(p.breakStart!, p.breakEnd!) : null;
        fixed.add(
          PlanItem(
            key: 'work#$i',
            ruleKey: 'work',
            kind: ItemKind.work,
            title: work.title,
            subtitle: brk == null ? null : 'الاستراحة داخلها وقت متاح',
            icon: 'work',
            start: p.start,
            end: end,
            fixed: true,
            counted: false,
            track: TrackMode.auto,
            category: 'work',
            workBreak: brk,
          ),
        );
        if (brk != null) {
          busy.add(
            Busy(
              Span(p.start, brk.start),
              BusyKind.work,
              work.title,
              key: 'work#$i',
            ),
          );
          busy.add(
            Busy(Span(brk.end, end), BusyKind.work, work.title, key: 'work#$i'),
          );
        } else {
          busy.add(
            Busy(Span(p.start, end), BusyKind.work, work.title, key: 'work#$i'),
          );
        }
      }
    }
    if (!nightShiftTonight && bed + 15 < minutesPerDay) {
      busy.add(
        Busy(Span(bed + 15, minutesPerDay), BusyKind.sleep, 'وقت النوم'),
      );
    }

    bool inWork(int s, int e) =>
        busy.any((b) => b.kind == BusyKind.work && b.span.overlapsRange(s, e));

    // 3) الصلوات.
    final prayersRule = _p.islam ? _ruleOfKind<PrayersConfig>(rules) : null;
    if (prayersRule != null) {
      final friday = d.weekday == DateTime.friday;
      final list = <(String, int, int)>[
        ('fajr', pr.fajr, pr.fajr + 20),
        friday
            ? ('jumuah', pr.dhuhr - 20, pr.dhuhr + 25)
            : ('dhuhr', pr.dhuhr, pr.dhuhr + 15),
        ('asr', pr.asr, pr.asr + 12),
        ('maghrib', pr.maghrib, pr.maghrib + 15),
        ('isha', pr.isha, pr.isha + 15),
      ];
      final sun = prayersRule.sunnah.toSet();
      List<SubItem> subsFor(String name) {
        final ids = <(String, String, String)>[
          if (name == 'jumuah' && sun.contains('dhuhr'))
            ('jumuah', 'سنة الجمعة', 'ركعتان أو أربع بعد الصلاة'),
          if (sun.contains(name)) ...sunnahOf[name]!,
          if (name == 'isha' && sun.contains('witr')) ...sunnahOf['witr']!,
        ];
        return [
          for (final (id, t, dt) in ids)
            SubItem(
              key: 'sunnah:$id',
              title: t,
              detail: dt,
              done: _log(d, 'sunnah:$id')?.status == ItemStatus.done,
            ),
        ];
      }

      for (final (name, s, e) in list) {
        final atWork = name == 'dhuhr' && inWork(s, e);
        fixed.add(
          PlanItem(
            key: 'prayer:$name',
            ruleKey: 'prayers',
            kind: ItemKind.prayer,
            title: prayerTitles[name]!,
            subtitle: atWork
                ? 'مصلى العمل'
                : (prayersRule.place.isEmpty ? null : prayersRule.place),
            icon: 'prayer',
            start: s,
            end: e,
            fixed: true,
            counted: true,
            track: prayersRule.track,
            category: 'prayer',
            subs: subsFor(name),
          ),
        );
      }
      if (ctx.ramadan && _season.taraweeh) {
        fixed.add(
          PlanItem(
            key: 'prayer:taraweeh',
            ruleKey: 'prayers',
            kind: ItemKind.prayer,
            title: 'صلاة التراويح',
            subtitle: 'رمضان',
            icon: 'prayer',
            start: pr.isha + 20,
            end: pr.isha + 80,
            fixed: true,
            counted: true,
            track: prayersRule.track,
            category: 'prayer',
          ),
        );
      }
      final eid = ctx.eid;
      if (eid != null && eid.first) {
        fixed.add(
          PlanItem(
            key: 'prayer:eid',
            ruleKey: 'prayers',
            kind: ItemKind.prayer,
            title: 'صلاة العيد',
            subtitle: eid.kind.label,
            icon: 'prayer',
            start: pr.sunrise + 20,
            end: pr.sunrise + 60,
            fixed: true,
            counted: true,
            track: prayersRule.track,
            category: 'prayer',
          ),
        );
      }
    }

    // الإفطار مع أذان المغرب في أيام الصيام: تمر وماء، خارج النسبة.
    if (ctx.fasting) {
      fixed.add(
        PlanItem(
          key: 'iftar',
          kind: ItemKind.meal,
          title: 'الإفطار',
          subtitle: 'تمر وماء مع الأذان',
          icon: 'meal',
          start: pr.maghrib,
          end: pr.maghrib + 8,
          fixed: true,
          counted: false,
          track: TrackMode.auto,
          category: 'meals',
        ),
      );
    }

    // مواعيد التقويم المستوردة: ثابتة وخارج النسبة.
    final allDay = <String>[];
    for (final e in input.imported.where((e) => e.date == d)) {
      if (e.allDay) {
        allDay.add(e.title);
        continue;
      }
      fixed.add(
        PlanItem(
          key: e.itemKey,
          kind: ItemKind.event,
          title: e.title,
          subtitle: e.calendar == null || e.calendar!.isEmpty
              ? e.source
              : '${e.source} · ${e.calendar}',
          icon: 'event',
          start: e.start!,
          end: e.end! <= e.start! ? e.start! + 30 : e.end!,
          fixed: true,
          counted: false,
          track: TrackMode.auto,
          category: 'calendar',
          source: e.source,
        ),
      );
    }

    // 4) الأولاد والحصص. مشاوير الشريك للعلم فقط: لا تحجز وقتًا ولا تُحسب.
    final info = <PlanItem>[];
    for (final r in rules) {
      final c = r.config;
      if (c is KidConfig) {
        if (ctx.schoolOff) continue;
        final kd = c.days[d.weekday];
        if (kd == null) continue;
        for (final (what, label, at) in [
          ('drop', 'توصيل', kd.drop),
          ('pick', 'استلام', kd.pick),
        ]) {
          if (at == null) continue;
          final item = _kidItem(r, c, what, '$label ${c.child}', at);
          if (_partnerRun(d, item.key)) {
            info.add(_asPartner(item));
          } else {
            fixed.add(item);
          }
        }
      } else if (c is ClassConfig) {
        if (ctx.classesOff) continue;
        if (!c.weekdays.contains(d.weekday)) continue;
        fixed.add(
          PlanItem(
            key: r.key,
            ruleKey: r.key,
            kind: ItemKind.klass,
            title: c.title,
            subtitle: [
              if (c.who != 'أنا') c.who,
              if (c.place != null && c.place!.isNotEmpty) c.place!,
            ].join(' · '),
            icon: 'class',
            start: c.start,
            end: c.end,
            fixed: true,
            counted: true,
            track: TrackMode.confirm,
            category: 'fixed',
          ),
        );
      }
    }

    // 5) ما أضافه المستخدم بوقت.
    final todaysOneOffs = input.oneOffs.where((o) => o.date == d).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    for (final o in todaysOneOffs) {
      if (o.kind == OneOffKind.reminder) {
        lines.add(
          ReminderLine(
            key: o.itemKey,
            kind: LineKind.custom,
            minute: o.start ?? wake + 60,
            title: o.title,
            done: _log(d, o.itemKey)?.status == ItemStatus.done,
          ),
        );
        continue;
      }
      if (o.start == null) continue;
      fixed.add(_oneOffItem(o, o.start!));
    }

    // تعديل «اليوم فقط» على الثابت: إلغاء (off).
    fixed.removeWhere(
      (i) => i.kind != ItemKind.work && _override(d, i.key)?.off == true,
    );
    info.removeWhere((i) => _override(d, i.key)?.off == true);

    // 6) فحص الثابت.
    final conflicts = <Conflict>[];
    for (var i = 0; i < fixed.length; i++) {
      for (var j = i + 1; j < fixed.length; j++) {
        final a = fixed[i], b = fixed[j];
        if (!_conflictPair(a, b)) continue;
        if (_overlapsOutsideBreak(a, b)) conflicts.add(Conflict(a, b));
      }
    }
    for (final f in fixed) {
      if (f.kind == ItemKind.work) continue;
      busy.add(Busy(f.span, BusyKind.fixed, f.title, key: f.key));
    }
    items.addAll(fixed);
    items.addAll(info);

    // 7) المرن بالترتيب.
    final queue = <_Flex>[];
    final adhkar = _p.islam ? _ruleOfKind<AdhkarConfig>(rules) : null;
    if (adhkar != null && adhkar.morning) {
      queue.add(
        _Flex(
          key: 'adhkar:morning',
          ruleKey: 'adhkar',
          kind: ItemKind.adhkar,
          title: 'أذكار الصباح',
          icon: 'sun',
          duration: adhkar.minutes,
          window: Window.afterFajr,
          preferred: pr.fajr + 20,
          track: TrackMode.confirm,
          category: 'prayer',
          subtitle: '${adhkar.minutes} دقائق',
        ),
      );
    }
    // الورد ثم العادات حسب الترتيب في الوثيقة.
    final flexRules = rules.where((r) => r.config is FlexConfig).toList();
    for (final r in flexRules.where((r) => r.kind == RuleKind.quran)) {
      queue.addAll(_flexFromRule(d, r, r.config as FlexConfig, withWeekly));
    }
    if (adhkar != null && adhkar.evening) {
      queue.add(
        _Flex(
          key: 'adhkar:evening',
          ruleKey: 'adhkar',
          kind: ItemKind.adhkar,
          title: 'أذكار المساء',
          icon: 'moon',
          duration: adhkar.minutes,
          window: Window.afternoon,
          preferred: pr.maghrib + 15,
          track: TrackMode.confirm,
          category: 'prayer',
          subtitle: '${adhkar.minutes} دقائق',
        ),
      );
    }
    final meals = flexRules.where((r) => r.kind == RuleKind.meal).toList();
    if (ctx.fasting) {
      // السحور والإفطار بدل الوجبات.
      if (meals.isNotEmpty) {
        queue.add(
          _Flex(
            key: 'meal:suhoor',
            kind: ItemKind.meal,
            title: 'السحور',
            subtitle: 'قبل الفجر',
            icon: 'meal',
            duration: 25,
            window: Window.any,
            span: Span((pr.fajr - 60).clamp(0, minutesPerDay), pr.fajr - 5),
            preferred: pr.fajr - 45,
            track: TrackMode.confirm,
            category: 'meals',
          ),
        );
        queue.add(
          _Flex(
            key: 'meal:iftar',
            kind: ItemKind.meal,
            title: 'وجبة الإفطار',
            subtitle: 'بعد صلاة المغرب',
            icon: 'meal',
            duration: 30,
            window: Window.any,
            span: Span(
              pr.maghrib + 15,
              (pr.maghrib + 120).clamp(0, minutesPerDay),
            ),
            preferred: pr.maghrib + 20,
            track: TrackMode.confirm,
            category: 'meals',
          ),
        );
      }
    } else {
      for (final r in meals) {
        queue.addAll(_flexFromRule(d, r, r.config as FlexConfig, withWeekly));
      }
    }
    // العيد: معايدة الأهل في أول يوم، وزيارات العيد في باقي أيامه.
    final eid = ctx.eid;
    if (eid != null) {
      queue.add(
        _Flex(
          key: 'eid:visits',
          kind: ItemKind.contact,
          title: eid.first ? 'معايدة الأهل' : 'زيارات العيد',
          subtitle: '${eid.kind.label} · رسائل واتصالات وزيارات',
          icon: 'gift',
          duration: eid.first ? 120 : 90,
          window: Window.any,
          span: Span(pr.sunrise + 70, (22 * 60).clamp(0, bed)),
          preferred: eid.first ? pr.sunrise + 80 : 16 * 60,
          track: TrackMode.confirm,
          category: 'contacts',
        ),
      );
    }
    // زكاة الفطر من 27 رمضان حتى تُسجّل.
    if (ctx.ramadan && (ctx.hijri?.day ?? 0) >= 27 && !_zakatDoneBefore(d)) {
      queue.add(
        _Flex(
          key: 'zakat',
          kind: ItemKind.task,
          title: 'زكاة الفطر',
          subtitle: 'قبل صلاة العيد',
          icon: 'coin',
          duration: 10,
          window: Window.any,
          span: Span(10 * 60, 22 * 60),
          preferred: 20 * 60,
          track: TrackMode.confirm,
          category: 'tasks',
        ),
      );
    }
    for (final o in todaysOneOffs.where(
      (o) => o.start == null && o.kind != OneOffKind.reminder,
    )) {
      queue.add(
        _Flex(
          key: o.itemKey,
          kind: o.kind == OneOffKind.habitSession
              ? ItemKind.habit
              : ItemKind.task,
          ruleKey: o.habitKey,
          title: o.title,
          subtitle: o.note,
          icon:
              o.icon ?? (o.kind == OneOffKind.habitSession ? 'star' : 'check'),
          duration: o.duration,
          window: o.window,
          preferred: o.preferred,
          track: TrackMode.confirm,
          category: o.kind == OneOffKind.habitSession ? 'habits' : 'tasks',
          isExtra: o.kind == OneOffKind.habitSession,
          oneOffId: o.id,
        ),
      );
    }
    for (final c in input.carries.where((c) => c.toDate == d)) {
      queue.add(
        _Flex(
          key: c.newKey,
          kind: ItemKind.task,
          title: c.title,
          subtitle: 'مؤجلة من ${c.fromDate.day}/${c.fromDate.month}',
          icon: 'check',
          duration: c.duration,
          window: Window.any,
          preferred: c.start,
          lockedStart: c.start,
          track: TrackMode.confirm,
          category: 'tasks',
          counted: c.counted,
          carriedFrom: c.fromDate,
        ),
      );
    }
    for (final r in flexRules.where((r) => r.kind == RuleKind.habit)) {
      queue.addAll(_flexFromRule(d, r, r.config as FlexConfig, withWeekly));
    }
    if (withWeekly) queue.addAll(_contactFlex(d, pr, dayWake, bed));
    final savings = _ruleOfKind<SavingsConfig>(rules);
    if (savings != null && savings.isPayDay(d)) {
      queue.add(
        _Flex(
          key: 'savings',
          ruleKey: 'savings',
          kind: ItemKind.savings,
          title: 'ادّخر من راتبك',
          subtitle: 'يوم الراتب · المخطط ${savings.monthly} ${_p.currency}',
          icon: 'coin',
          duration: 5,
          window: Window.night,
          preferred: 20 * 60 + 30,
          track: TrackMode.confirm,
          category: 'money',
        ),
      );
    }

    // الإيقاف المؤقت: يبقى الثابت والوجبات فقط.
    if (ctx.paused) queue.removeWhere((f) => f.kind != ItemKind.meal);
    // في الصيام: الاقتراحات (والمشي والرياضة في رمضان) بعد الإفطار.
    if (ctx.fasting) {
      final after = Span(
        pr.maghrib + 30,
        bed.clamp(pr.maghrib + 30, minutesPerDay),
      );
      for (final f in queue) {
        final suggestion = f.isExtra && f.category == 'contacts';
        final active =
            ctx.ramadan &&
            _season.lateOutings &&
            (f.ruleKey == 'habit:walk' ||
                f.ruleKey == 'habit:sport' ||
                f.icon == 'walk' ||
                f.icon == 'sport');
        if (!suggestion && !active) continue;
        final base = f.span ?? windowSpan(f.window, pr, dayWake, bed);
        final s0 = base.start > after.start ? base.start : after.start;
        f.span = Span(s0, after.end > s0 ? after.end : s0);
        f.window = Window.any;
      }
    }

    // المقفل أولًا (تعديل اليوم، ثم الوقت المخطط المسجّل)، ثم الباقي بالترتيب.
    for (final f in queue) {
      final ov = _override(d, f.key);
      final log = _log(d, f.key);
      if (ov?.off == true) {
        f.dropped = true;
        continue;
      }
      f.lockedStart =
          ov?.start ??
          f.lockedStart ??
          log?.plannedStart ??
          (log?.isFinal == true ? log?.doneAt : null);
      f.manual = ov?.start != null;
    }
    var optionalUsed = 0;
    final placed = <_Flex, int>{};
    final windowMissed = <_Flex>{};
    for (final f in queue.where((f) => !f.dropped && f.lockedStart != null)) {
      final s = f.lockedStart!;
      placed[f] = s;
      busy.add(
        Busy(Span(s, s + f.duration), BusyKind.flex, f.title, key: f.key),
      );
      if (f.optional) optionalUsed += f.duration;
    }
    for (final f in queue.where((f) => !f.dropped && f.lockedStart == null)) {
      if (f.optional &&
          optionalUsed + f.duration > input.settings.optionalCapMinutes) {
        unplaced.add(
          Unplaced(
            f.key,
            f.title,
            UnplacedReason.cap,
            ruleKey: f.ruleKey,
            duration: f.duration,
          ),
        );
        continue;
      }
      final w = f.span ?? windowSpan(f.window, pr, dayWake, bed);
      var t = _search(busy, f.duration, w, f.preferred);
      // الاقتراح يسكت إن ما لقى وقت، فالأقل أفضل من الحشو.
      if (t == null && f.span != null && f.isExtra) continue;
      if (t == null && f.window != Window.any) {
        t = _search(
          busy,
          f.duration,
          windowSpan(Window.any, pr, dayWake, bed),
          f.preferred,
        );
        if (t != null) windowMissed.add(f);
      }
      if (t == null) {
        unplaced.add(
          Unplaced(
            f.key,
            f.title,
            UnplacedReason.noTime,
            ruleKey: f.ruleKey,
            duration: f.duration,
          ),
        );
        continue;
      }
      placed[f] = t;
      busy.add(
        Busy(Span(t, t + f.duration), BusyKind.flex, f.title, key: f.key),
      );
      if (f.optional) optionalUsed += f.duration;
    }
    for (final e in placed.entries) {
      final f = e.key;
      items.add(
        PlanItem(
          key: f.key,
          ruleKey: f.ruleKey,
          kind: f.kind,
          title: f.title,
          subtitle: f.subtitle,
          icon: f.icon,
          start: e.value,
          end: e.value + f.duration,
          fixed: false,
          counted: f.counted,
          optional: f.optional,
          track: f.track,
          category: f.category,
          isExtra: f.isExtra,
          manual: f.manual,
          outsideWindow: windowMissed.contains(f),
          pagesFrom: f.pagesFrom,
          pagesTo: f.pagesTo,
          book: f.book,
          carriedFrom: f.carriedFrom,
          oneOffId: f.oneOffId,
          window: f.window,
          personId: f.personId,
        ),
      );
    }

    // 8) الحالات.
    final withStatus = [for (final i in items) _withStatus(d, i)]
      ..sort(
        (a, b) => a.start != b.start
            ? a.start.compareTo(b.start)
            : a.key.compareTo(b.key),
      );

    // 9) الخطوط الخفيفة.
    final reminders = _ruleOfKind<RemindersConfig>(rules);
    if (reminders != null) {
      lines.addAll(
        _reminderLines(
          d,
          reminders,
          withStatus,
          busy,
          pr,
          dayWake,
          bed,
          fasting: ctx.fasting,
        ),
      );
    }
    if (bed < minutesPerDay && !nightShiftTonight) {
      lines.add(
        ReminderLine(
          key: 'sleep',
          kind: LineKind.sleep,
          minute: bed,
          title: 'وقت النوم',
        ),
      );
    }
    lines.sort((a, b) => a.minute.compareTo(b.minute));

    final plan = DayPlan(
      date: d,
      items: withStatus,
      lines: lines,
      conflicts: conflicts,
      unplaced: unplaced,
      busy: busy,
      prayers: pr,
      wake: dayWake,
      bedtime: bed,
      workOff: workOff,
      context: ctx,
      allDay: allDay,
    );
    if (!withWeekly) _baseCache[d] = plan;
    return plan;
  }

  bool _conflictPair(PlanItem a, PlanItem b) {
    // الصلاة داخل الدوام ليست تعارضًا: «مصلى العمل».
    final kinds = {a.kind, b.kind};
    if (kinds.contains(ItemKind.prayer) && kinds.contains(ItemKind.work)) {
      return false;
    }
    if (a.kind == ItemKind.work && b.kind == ItemKind.work) return false;
    // الإفطار مع الأذان قبل صلاة المغرب: ليس تعارضًا.
    if (a.key == 'iftar' || b.key == 'iftar') return false;
    return a.span.overlaps(b.span);
  }

  bool _overlapsOutsideBreak(PlanItem a, PlanItem b) {
    PlanItem? w;
    PlanItem? o;
    if (a.kind == ItemKind.work) {
      w = a;
      o = b;
    } else if (b.kind == ItemKind.work) {
      w = b;
      o = a;
    }
    if (w == null || w.workBreak == null) return true;
    final br = w.workBreak!;
    // داخل الاستراحة تمامًا = متاح.
    return !(o!.start >= br.start && o.end <= br.end);
  }

  PlanItem _kidItem(Rule r, KidConfig c, String what, String title, int at) =>
      PlanItem(
        key: '${r.key}:$what',
        ruleKey: r.key,
        kind: ItemKind.kid,
        title: title,
        subtitle: c.place,
        icon: 'kid',
        start: at,
        end: at + c.trip,
        fixed: true,
        counted: true,
        track: TrackMode.confirm,
        category: 'fixed',
      );

  /// هل المشوار على الشريك اليوم؟ تبديل اليوم يغلب الإعداد الدائم.
  bool _partnerRun(Day d, String key) {
    if (!input.partner.active) return false;
    final who = _override(d, key)?.who;
    if (who != null) return who == 'partner';
    return input.partner.partnerOn(key, d);
  }

  PlanItem _asPartner(PlanItem i) => PlanItem(
    key: i.key,
    ruleKey: i.ruleKey,
    kind: i.kind,
    title: i.title,
    subtitle: 'على ${input.partner.name} اليوم',
    icon: i.icon,
    start: i.start,
    end: i.end,
    fixed: true,
    counted: false,
    track: TrackMode.auto,
    category: i.category,
    partner: true,
  );

  bool _zakatDoneBefore(Day d) {
    for (var x = d.prev; d.difference(x) <= 4; x = x.prev) {
      if (_log(x, 'zakat')?.status == ItemStatus.done) return true;
    }
    return false;
  }

  PlanItem _oneOffItem(OneOff o, int start) {
    final kind = switch (o.kind) {
      OneOffKind.period => ItemKind.period,
      OneOffKind.event => ItemKind.event,
      OneOffKind.habitSession => ItemKind.habit,
      _ => ItemKind.task,
    };
    final counted =
        o.kind == OneOffKind.task || o.kind == OneOffKind.habitSession;
    return PlanItem(
      key: o.itemKey,
      ruleKey: o.habitKey,
      kind: kind,
      title: o.title,
      subtitle: o.note,
      icon:
          o.icon ??
          switch (kind) {
            ItemKind.event => 'event',
            ItemKind.period => 'period',
            _ => 'check',
          },
      start: start,
      end: start + o.duration,
      fixed: true,
      counted: counted,
      track: counted ? TrackMode.confirm : TrackMode.auto,
      category: o.kind == OneOffKind.habitSession ? 'habits' : 'tasks',
      isExtra: o.kind == OneOffKind.habitSession,
      oneOffId: o.id,
    );
  }

  /// الجلسات المطلوبة اليوم من قاعدة مرنة.
  List<_Flex> _flexFromRule(Day d, Rule r, FlexConfig c, bool withWeekly) {
    final rec = c.recurrence;
    final due = switch (rec) {
      Daily() => true,
      Weekdays(:final days) => days.contains(d.weekday),
      Once(:final date) => date == d,
      TimesPerWeek() =>
        withWeekly && (weekPlan(d)[r.key]?.contains(d) ?? false),
    };
    if (!due) return const [];
    final perDay = c.perDay.clamp(1, 3);
    final pages = c.isKhatma ? khatmaPagesOn(d, r) : c.pages;
    if (c.isKhatma && pages == 0) return const []; // تمّت الختمة.
    final pagesPerSession = pages == null ? null : (pages / perDay).ceil();
    final duration = c.isKhatma
        ? (((pagesPerSession! * 2.5) / 5).round() * 5).clamp(10, 120)
        : c.duration;
    final subtitle = c.isKhatma
        ? 'ختمة قبل ${c.khatmaBy!.day} ${arabicMonths[c.khatmaBy!.month - 1]}'
        : c.subtitle;
    return [
      for (var i = 0; i < perDay; i++)
        _Flex(
          key: perDay == 1 ? r.key : '${r.key}#${i + 1}',
          ruleKey: r.key,
          kind: switch (c.kind) {
            RuleKind.quran => ItemKind.quran,
            RuleKind.meal => ItemKind.meal,
            _ => ItemKind.habit,
          },
          title: c.title,
          subtitle: subtitle,
          icon: c.icon,
          duration: duration,
          window: c.windowFor(i),
          preferred: i == 0 ? c.preferred : null,
          track: c.track,
          optional: c.optional,
          counted: c.counted,
          category: c.category,
          pagesFrom: _pagesFrom(d, r, c, i, pagesPerSession),
          pagesTo: pagesPerSession == null
              ? null
              : _pagesFrom(d, r, c, i, pagesPerSession)! + pagesPerSession - 1,
          book: c.book,
        ),
    ];
  }

  /// آخر صفحة مسجّلة لقاعدة قبل يوم [d] (أو صفحة البداية - 1).
  int lastPageBefore(Day d, Rule r) {
    final c = r.config as FlexConfig;
    var last = (c.startPage ?? 1) - 1;
    for (final l in input.logs.values) {
      if (l.itemKey != r.key && !l.itemKey.startsWith('${r.key}#')) continue;
      if (!l.date.isBefore(d)) continue;
      if (l.value2 != null && l.value2! > last) last = l.value2!;
    }
    return last;
  }

  /// ختمة: صفحات يوم [d] = المتبقي ÷ أيام القراءة الباقية حتى موعد الختم.
  /// تتعدل تلقائيًا مع كل تسجيل، وتبقى ثابتة داخل اليوم نفسه.
  int khatmaPagesOn(Day d, Rule r) {
    final c = r.config as FlexConfig;
    final rem = mushafPages - lastPageBefore(d, r);
    if (rem <= 0) return 0;
    final by = c.khatmaBy!;
    var n = 0.0;
    for (var x = d; !x.isAfter(by) && n < 1000; x = x.next) {
      n += switch (c.recurrence) {
        Daily() => 1,
        Weekdays(:final days) => days.contains(x.weekday) ? 1 : 0,
        TimesPerWeek(n: final k) => k / 7,
        Once(:final date) => date == x ? 1 : 0,
      };
    }
    if (n < 1) n = 1;
    return (rem / n).ceil();
  }

  /// صفحة البداية: آخر صفحة مسجّلة + 1، أو صفحة البداية في القاعدة.
  int? _pagesFrom(Day d, Rule r, FlexConfig c, int session, int? perSession) {
    if (perSession == null) return null;
    var last = (c.startPage ?? 1) - 1;
    for (final l in input.logs.values) {
      if (l.itemKey != r.key && !l.itemKey.startsWith('${r.key}#')) continue;
      if (!l.date.isBefore(d) &&
          !(l.date == d && _sessionIndex(l.itemKey) < session)) {
        continue;
      }
      if (l.value2 != null && l.value2! > last) last = l.value2!;
    }
    return last + 1;
  }

  int _sessionIndex(String key) {
    final i = key.lastIndexOf('#');
    return i < 0 ? 0 : (int.tryParse(key.substring(i + 1)) ?? 1) - 1;
  }

  PlanItem _withStatus(Day d, PlanItem i) {
    final log = _log(d, i.key);
    ItemStatus status;
    if (log != null && log.status != ItemStatus.pending) {
      status = log.status;
    } else if (d.isBefore(_p.joinDay) ||
        (d == _p.joinDay && i.end <= _p.joinMinute)) {
      status = ItemStatus.preJoin;
    } else if (i.track == TrackMode.auto) {
      status = d.isBefore(input.today) ? ItemStatus.auto : ItemStatus.pending;
    } else if (d.isBefore(input.today)) {
      status = i.track == TrackMode.autocount
          ? ItemStatus.auto
          : ItemStatus.missed;
    } else {
      status = ItemStatus.pending;
    }
    return PlanItem(
      key: i.key,
      ruleKey: i.ruleKey,
      kind: i.kind,
      title: i.title,
      subtitle: i.subtitle,
      icon: i.icon,
      start: i.start,
      end: i.end,
      fixed: i.fixed,
      counted: i.counted,
      optional: i.optional,
      track: i.track,
      status: status,
      doneAt: log?.doneAt,
      category: i.category,
      isExtra: i.isExtra,
      manual: i.manual,
      outsideWindow: i.outsideWindow,
      workBreak: i.workBreak,
      pagesFrom: i.pagesFrom,
      pagesTo: i.pagesTo,
      book: i.book,
      carriedFrom: i.carriedFrom,
      oneOffId: i.oneOffId,
      window: i.window,
      log: log,
      subs: i.subs,
      personId: i.personId,
      partner: i.partner,
      source: i.source,
    );
  }

  // ---------------------------------------------------------------------------
  // النوافذ والبحث
  // ---------------------------------------------------------------------------

  static Span windowSpan(Window w, DayPrayers pr, int wake, int bed) {
    final end = bed.clamp(0, minutesPerDay);
    switch (w) {
      case Window.afterFajr:
        return Span(
          pr.fajr + 20,
          (pr.sunrise + 120 > wake + 120 ? pr.sunrise + 120 : wake + 120).clamp(
            0,
            end,
          ),
        );
      case Window.morning:
        return Span(wake, pr.dhuhr.clamp(wake, end));
      case Window.afternoon:
        return Span(pr.asr, pr.isha.clamp(pr.asr, end));
      case Window.night:
        return Span(pr.isha, end < pr.isha ? pr.isha : end);
      case Window.any:
        return Span(wake, end);
    }
  }

  static bool isFree(List<Busy> busy, int s, int e, {String? ignoreKey}) {
    if (s < 0 || e > minutesPerDay) return false;
    for (final b in busy) {
      if (ignoreKey != null && b.key == ignoreKey) continue;
      if (b.span.overlapsRange(s, e)) return false;
    }
    return true;
  }

  /// البحث بخطوة 5 دقائق: من الوقت المفضل داخل النافذة، ثم من أول النافذة.
  static int? _search(List<Busy> busy, int dur, Span w, int? preferred) {
    int align(int m) => ((m + _step - 1) ~/ _step) * _step;
    final ws = align(w.start);
    final pref = preferred == null
        ? ws
        : align(preferred.clamp(w.start, w.end));
    for (var t = pref; t + dur <= w.end; t += _step) {
      if (isFree(busy, t, t + dur)) return t;
    }
    for (var t = ws; t < pref && t + dur <= w.end; t += _step) {
      if (isFree(busy, t, t + dur)) return t;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // مخطط الأسبوع: أيام «عدد بالأسبوع»
  // ---------------------------------------------------------------------------

  /// لكل قاعدة «عدد بالأسبوع»: الأيام المختارة في أسبوع [d].
  Map<String, Set<Day>> weekPlan(Day d) {
    final ws = d.weekStart;
    final cached = _weekCache[ws];
    if (cached != null) return cached;
    final result = <String, Set<Day>>{};
    _weekCache[ws] = result; // يمنع التكرار أثناء الحساب.
    final keys = <String>{};
    for (var i = 0; i < 7; i++) {
      for (final r in rulesOn(ws.add(i))) {
        if (r.config is FlexConfig &&
            (r.config as FlexConfig).recurrence is TimesPerWeek) {
          keys.add(r.key);
        }
      }
    }
    for (final key in keys.toList()..sort()) {
      Rule? ruleOn(Day day) {
        for (final r in rulesOn(day)) {
          if (r.key == key) return r;
        }
        return null;
      }

      // نأخذ عدد الجلسات من أول نسخة سارية في الأسبوع.
      Rule? first;
      for (var i = 0; i < 7 && first == null; i++) {
        first = ruleOn(ws.add(i));
      }
      final c = first!.config as FlexConfig;
      final n = (c.recurrence as TimesPerWeek).n;
      final chosen = <Day>{};
      var prev = -1;
      for (final idx in spreadOverWeek(n)) {
        var startIdx = idx > prev ? idx : prev + 1;
        if (startIdx > 6) break;
        int? pick;
        for (var k = startIdx; k <= 6; k++) {
          final day = ws.add(k);
          final r = ruleOn(day);
          if (r == null) continue;
          final rc = r.config as FlexConfig;
          // الأيام المسجّلة كمنجزة تُحترم كما هي.
          final base = _generate(day, withWeekly: false);
          final w = windowSpan(
            rc.windowFor(0),
            base.prayers,
            base.wake,
            base.bedtime,
          );
          if (_search(base.busy, rc.duration, w, null) != null ||
              _search(
                    base.busy,
                    rc.duration,
                    windowSpan(
                      Window.any,
                      base.prayers,
                      base.wake,
                      base.bedtime,
                    ),
                    null,
                  ) !=
                  null) {
            pick = k;
            break;
          }
        }
        pick ??= startIdx;
        if (ruleOn(ws.add(pick)) == null) continue;
        chosen.add(ws.add(pick));
        prev = pick;
      }
      result[key] = chosen;
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // التواصل مع الناس
  // ---------------------------------------------------------------------------

  /// توزيع الأسبوع: من يُقترح في أي يوم. ثابت طوال الأسبوع لأنه لا يقرأ
  /// إلا السجلات التي قبل بدايته.
  Map<Day, List<Person>> contactWeek(Day anyDay) {
    final ws = anyDay.weekStart;
    final cached = _contactCache[ws];
    if (cached != null) return cached;
    final c = input.contacts;
    final out = <Day, List<Person>>{};
    _contactCache[ws] = out;
    if (!c.active || input.people.isEmpty || !(c.calls || c.messages)) {
      return out;
    }
    final last = <String, Day>{};
    for (final l in input.logs.values) {
      if (!l.itemKey.startsWith('contact:')) continue;
      if (l.status != ItemStatus.done || !l.date.isBefore(ws)) continue;
      final pid = l.itemKey.substring(8);
      final prev = last[pid];
      if (prev == null || l.date.isAfter(prev)) last[pid] = l.date;
    }
    Day lastOf(Person p) => last[p.id] ?? p.addedAt.add(-p.freq.days);
    bool due(Person p) => !lastOf(p).add(p.freq.days).isAfter(ws.add(6));
    int byStale(Person a, Person b) {
      final x = lastOf(a).compareTo(lastOf(b));
      return x != 0 ? x : a.name.compareTo(b.name);
    }

    final pinned = input.people.where((p) => p.pinned && due(p)).toList()
      ..sort(byStale);
    final others = input.people.where((p) => !p.pinned && due(p)).toList()
      ..sort(byStale);
    final all = [...pinned, ...others.take(c.level.perWeek)];
    // الزيارات في عطلة نهاية الأسبوع فقط (إذا الخيار مفعّل).
    bool weekendVisit(Person p) =>
        p.method == ContactMethod.visit && c.visitsWeekendOnly;
    final visits = all.where(weekendVisit).toList();
    final chosen = all.where((p) => !weekendVisit(p)).toList();
    final weekendDays = [
      for (var i = 0; i < 7; i++)
        if (_p.weekend.contains(ws.add(i).weekday)) ws.add(i),
    ];
    for (var k = 0; k < visits.length; k++) {
      final day = weekendDays.isEmpty
          ? ws.add(6)
          : weekendDays[k % weekendDays.length];
      out.putIfAbsent(day, () => []).add(visits[k]);
    }
    final n = chosen.length;
    for (var k = 0; k < n; k++) {
      // توزيع متساوٍ على الأيام السبعة، من منتصف كل حصة.
      final idx = ((k * 7 + 3) ~/ n).clamp(0, 6) % 7;
      out.putIfAbsent(ws.add(idx), () => []).add(chosen[k]);
    }
    return out;
  }

  List<_Flex> _contactFlex(Day d, DayPrayers pr, int wake, int bed) {
    final c = input.contacts;
    if (!c.enabled) return const [];
    final out = <_Flex>[];
    final win = Span(
      c.windowStart.clamp(wake, bed.clamp(0, minutesPerDay)),
      c.windowEnd.clamp(wake, bed.clamp(0, minutesPerDay)),
    );
    for (final p in contactWeek(d)[d] ?? const <Person>[]) {
      if (p.method == ContactMethod.visit) {
        final end = bed.clamp(0, minutesPerDay);
        out.add(
          _Flex(
            key: p.itemKey,
            kind: ItemKind.contact,
            title: 'زُر ${p.name}',
            subtitle: '${p.relation.label} · ${p.freq.label}',
            icon: 'visit',
            duration: 60,
            window: Window.afternoon,
            span: Span((16 * 60).clamp(wake, end), end),
            preferred: c.windowStart.clamp(wake, end),
            track: TrackMode.confirm,
            category: 'contacts',
            isExtra: true,
            personId: p.id,
          ),
        );
        continue;
      }
      final call = (p.method == ContactMethod.call && c.calls) || !c.messages;
      out.add(
        _Flex(
          key: p.itemKey,
          kind: ItemKind.contact,
          title: call ? 'اتصل ب${p.name}' : 'أرسل لـ${p.name}',
          subtitle: call
              ? '${p.relation.label} · ${p.freq.label}'
              : contactDraft(p, c.windowStart),
          icon: call ? 'call' : 'message',
          duration: call ? 15 : 5,
          window: Window.night,
          span: win,
          preferred: win.start,
          track: TrackMode.confirm,
          category: 'contacts',
          isExtra: true,
          personId: p.id,
        ),
      );
    }
    if (c.occasions) {
      for (final p in input.people) {
        for (final o in p.occasions.where((o) => o.on(d))) {
          final gift = c.gifts && p.giftBudget != null
              ? 'فكرة هدية ${p.giftBudget} ر.س · ${giftIdea(o.kind, p.giftBudget!)}'
              : o.kind.label;
          out.add(
            _Flex(
              key: 'occasion:${p.id}:${o.kind.name}',
              kind: ItemKind.contact,
              title: 'هنّئ ${p.name} ب${o.kind.phrase}',
              subtitle: gift,
              icon: 'gift',
              duration: 10,
              window: Window.morning,
              span: Span(wake, bed.clamp(0, minutesPerDay)),
              preferred: wake + 60 > 10 * 60 ? wake + 60 : 10 * 60,
              track: TrackMode.confirm,
              category: 'contacts',
              isExtra: true,
              personId: p.id,
            ),
          );
        }
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // التذكيرات القصيرة
  // ---------------------------------------------------------------------------

  List<ReminderLine> _reminderLines(
    Day d,
    RemindersConfig c,
    List<PlanItem> items,
    List<Busy> busy,
    DayPrayers pr,
    int wake,
    int bed, {
    bool fasting = false,
  }) {
    final out = <ReminderLine>[];
    final end = bed.clamp(0, minutesPerDay);
    if (c.water && c.cups > 0) {
      // في الصيام: الماء بعد الإفطار فقط.
      final from = fasting ? pr.maghrib : wake;
      // مرتبطة بالوجبات والاستراحة، ثم توزيع على الفراغات الكبيرة. لا «كوب كل ساعة».
      final anchors = <int>{fasting ? pr.maghrib + 20 : wake + 30};
      for (final i in items) {
        if (i.kind == ItemKind.meal) anchors.add(i.end + 10);
        if (i.workBreak != null && !fasting) {
          anchors.add(i.workBreak!.start + 5);
        }
      }
      var times = <int>[];
      for (final m
          in (anchors.where((m) => m >= from && m < end - 30).toList()
            ..sort())) {
        // مرسيان متقاربان يصيران تذكيرًا واحدًا.
        if (times.isEmpty || m - times.last >= 20) times.add(m);
      }
      while (times.length < c.cups && times.length < 16) {
        // أكبر فجوة بين المراسي.
        final pts = [from, ...times, end - 30];
        var bestGap = 0, bestAt = -1;
        for (var i = 1; i < pts.length; i++) {
          final g = pts[i] - pts[i - 1];
          if (g > bestGap) {
            bestGap = g;
            bestAt = pts[i - 1] + g ~/ 2;
          }
        }
        if (bestGap < (fasting ? 25 : 40)) break;
        times.add((bestAt ~/ 5) * 5);
        times.sort();
      }
      times = times.take(c.cups).toList();
      final drank = waterMl(_log(d, 'water')?.value);
      final per = (input.settings.waterGoalMl / c.cups).round().clamp(1, 5000);
      final cupsDone = drank ~/ per;
      for (var i = 0; i < times.length; i++) {
        out.add(
          ReminderLine(
            key: 'water#${i + 1}',
            kind: LineKind.water,
            minute: times[i],
            title: 'اشرب ماء',
            done: i < cupsDone,
          ),
        );
      }
    }
    if (c.stand) {
      var n = 0;
      for (final i in items.where((i) => i.kind == ItemKind.work)) {
        for (var t = i.start + 90; t < i.end - 30; t += 120) {
          if (i.workBreak != null && i.workBreak!.contains(t)) continue;
          n++;
          out.add(
            ReminderLine(
              key: 'stand#$n',
              kind: LineKind.stand,
              minute: t,
              title: 'قم وتحرّك دقيقتين',
            ),
          );
        }
      }
    }
    if (c.breathe) {
      final at = ((pr.asr + 45) ~/ 5) * 5;
      if (at > wake && at < end) {
        out.add(
          ReminderLine(
            key: 'breathe',
            kind: LineKind.breathe,
            minute: at,
            title: 'تنفّس بعمق دقيقة',
            done: _log(d, 'breathe')?.status == ItemStatus.done,
          ),
        );
      }
    }
    return out;
  }
}

/// كمية الماء بالمل. النسخ القديمة كانت تحفظ عدد الأكواب.
int waterMl(int? v) {
  if (v == null) return 0;
  return v <= 20 ? v * 250 : v;
}

extension on ItemLog {
  bool get isFinal => status == ItemStatus.done || status == ItemStatus.notDone;
}

class _Flex {
  _Flex({
    required this.key,
    this.ruleKey,
    required this.kind,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.duration,
    required this.window,
    this.preferred,
    this.lockedStart,
    required this.track,
    this.optional = false,
    this.counted = true,
    required this.category,
    this.isExtra = false,
    this.pagesFrom,
    this.pagesTo,
    this.book,
    this.carriedFrom,
    this.oneOffId,
    this.span,
    this.personId,
  });

  final String key;
  final String? ruleKey;
  final ItemKind kind;
  final String title;
  final String? subtitle;
  final String icon;
  final int duration;
  Window window;
  final int? preferred;
  int? lockedStart;
  final TrackMode track;
  final bool optional;
  final bool counted;
  final String category;
  final bool isExtra;
  final int? pagesFrom;
  final int? pagesTo;
  final String? book;
  final Day? carriedFrom;
  final String? oneOffId;

  /// نافذة مخصصة (اقتراحات التواصل). بدونها تُستخدم [window].
  Span? span;
  final String? personId;
  bool dropped = false;
  bool manual = false;
}
