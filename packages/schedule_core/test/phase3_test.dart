import 'package:schedule_core/schedule_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  // 1 رمضان 1448 = الاثنين 8 فبراير 2027 (أم القرى). العيد الثلاثاء 9 مارس.
  const ram1 = Day(2027, 2, 8);
  const ram27 = Day(2027, 3, 6);
  const eidFitr = Day(2027, 3, 9);
  const eidAdha = Day(2027, 5, 16);
  const sha27 = Day(2027, 2, 4);

  final rules = [...basicRules, rule('work', morningWork())];
  const accepted = AppSettings(
    season: SeasonSettings(ramadanYears: {1448: true}),
  );

  ScheduleEngine engine({
    Day today = ram1,
    AppSettings settings = accepted,
    List<LifeMode> modes = const [],
    List<Holiday> holidays = const [],
    PartnerShare partner = const PartnerShare(),
    List<ImportedEvent> imported = const [],
    Map<String, DayOverride> overrides = const {},
    Map<String, ItemLog> logs = const {},
    List<Rule>? withRules,
    UserProfile? profile,
  }) => ScheduleEngine(
    input(
      rules: withRules ?? rules,
      today: today,
      settings: settings,
      modes: modes,
      holidays: holidays,
      partner: partner,
      imported: imported,
      overrides: overrides,
      logs: logs,
      profile: profile,
    ),
  );

  group('السياق الهجري', () {
    test('رمضان والعيد بتقويم أم القرى', () {
      final e = engine();
      expect(e.contextFor(ram1).hijri, const HijriDay(1448, 9, 1));
      expect(e.contextFor(ram1).ramadan, isTrue);
      expect(e.contextFor(eidFitr).eid?.kind, EidKind.fitr);
      expect(e.contextFor(eidFitr).eid?.first, isTrue);
      expect(e.contextFor(eidAdha).eid?.kind, EidKind.adha);
      expect(e.contextFor(eidFitr).fasting, isFalse);
    });

    test('بطاقة «نبدأ جدول رمضان؟» من 27 شعبان حتى يجيب المستخدم', () {
      final e = engine(settings: const AppSettings());
      expect(e.contextFor(sha27).ramadanPending, isTrue);
      expect(e.contextFor(sha27.prev).ramadanPending, isFalse);
      expect(e.contextFor(ram1).ramadanPending, isTrue);
      // بدون موافقة لا يتغير الجدول.
      expect(e.contextFor(ram1).ramadan, isFalse);
      expect(daysToRamadan(sha27), 4);
      final declined = engine(
        settings: const AppSettings(
          season: SeasonSettings(ramadanYears: {1448: false}),
        ),
      );
      expect(declined.contextFor(ram1).ramadanPending, isFalse);
      expect(declined.contextFor(ram1).ramadan, isFalse);
    });

    test('«بدون» دين: لا هجري ولا رمضان ولا عيد', () {
      final e = engine(profile: riyadh().copyWith(religion: Religion.none));
      expect(e.contextFor(ram1).hijri, isNull);
      expect(e.contextFor(eidFitr).eid, isNull);
      expect(e.day(ram1).byKey('iftar'), isNull);
    });
  });

  group('رمضان', () {
    test('أول أيام رمضان بموافقة: سحور، إفطار، تراويح، دوام 10 إلى 3', () {
      final e = engine();
      final plan = e.day(ram1);
      final pr = plan.prayers;
      // العشاء بعد المغرب بـ 120 دقيقة في السعودية.
      expect(pr.isha - pr.maghrib, 120);
      final suhoor = plan.byKey('meal:suhoor')!;
      expect(suhoor.start, inInclusiveRange(pr.fajr - 60, pr.fajr - 30));
      expect(suhoor.end, lessThanOrEqualTo(pr.fajr - 5));
      final iftar = plan.byKey('iftar')!;
      expect(iftar.start, pr.maghrib);
      expect(iftar.counted, isFalse);
      final meal = plan.byKey('meal:iftar')!;
      expect(meal.start, greaterThanOrEqualTo(pr.maghrib + 15));
      expect(plan.byKey('meal:breakfast'), isNull);
      final tar = plan.byKey('prayer:taraweeh')!;
      expect(tar.start, pr.isha + 20);
      expect(tar.duration, 60);
      final work = plan.items.where((i) => i.kind == ItemKind.work).toList();
      expect(work, hasLength(1));
      expect((work.single.start, work.single.end), (600, 900));
      // النوم ينتهي قبل الفجر بساعة على الأقل.
      expect(plan.wake, lessThanOrEqualTo(pr.fajr - 60));
      expect(plan.bedtime, 23 * 60 + 30);
      // الإفطار مع الأذان ليس تعارضًا مع صلاة المغرب.
      expect(plan.conflicts, isEmpty);
    });

    test('المشي بعد الإفطار، والماء بعد الإفطار فقط', () {
      final e = engine();
      // أسبوع رمضان كامل: كل جلسة مشي بعد المغرب.
      for (var i = 0; i < 7; i++) {
        final plan = e.day(ram1.add(i));
        final walk = plan.byKey('habit:walk');
        if (walk != null) {
          expect(walk.start, greaterThanOrEqualTo(plan.prayers.maghrib + 30));
        }
        for (final l in plan.lines.where((l) => l.kind == LineKind.water)) {
          expect(l.minute, greaterThanOrEqualTo(plan.prayers.maghrib));
        }
      }
    });

    test('زكاة الفطر من 27 رمضان حتى تُسجّل', () {
      expect(engine().day(ram27.prev).byKey('zakat'), isNull);
      expect(engine().day(ram27).byKey('zakat'), isNotNull);
      final done = {
        recordKey(ram27, 'zakat'): const ItemLog(
          date: ram27,
          itemKey: 'zakat',
          status: ItemStatus.done,
        ),
      };
      expect(engine(logs: done).day(ram27.next).byKey('zakat'), isNull);
    });

    test('دوام رمضان مغلق: الدوام العادي يبقى', () {
      final e = engine(
        settings: const AppSettings(
          season: SeasonSettings(
            ramadanYears: {1448: true},
            ramadanWork: false,
            taraweeh: false,
          ),
        ),
      );
      final plan = e.day(ram1);
      final work = plan.items.firstWhere((i) => i.kind == ItemKind.work);
      expect(work.start, 450);
      expect(plan.byKey('prayer:taraweeh'), isNull);
    });

    test('الوردية الليلية تبقى في رمضان', () {
      final night = WorkConfig(
        pattern: WorkPattern.night,
        days: {
          for (var d = 1; d <= 7; d++) d: [const WorkPeriod(22 * 60, 6 * 60)],
        },
      );
      final e = engine(withRules: [...basicRules, rule('work', night)]);
      final work = e
          .day(ram1)
          .items
          .where((i) => i.kind == ItemKind.work && i.key != 'work#tail');
      expect(work.single.start, 22 * 60);
    });
  });

  group('صيام الاثنين والخميس', () {
    test('يغيّر الوجبات والماء فقط، ولا يغيّر الدوام', () {
      const monday = Day(2026, 11, 30);
      final e = engine(
        today: monday,
        settings: const AppSettings(
          season: SeasonSettings(fasting: FastingMode.ramadanMonThu),
        ),
      );
      final plan = e.day(monday);
      expect(plan.context!.fasting, isTrue);
      expect(plan.byKey('meal:suhoor'), isNotNull);
      expect(plan.byKey('meal:breakfast'), isNull);
      final work = plan.items.firstWhere((i) => i.kind == ItemKind.work);
      expect(work.start, 450);
      expect(plan.byKey('prayer:taraweeh'), isNull);
      expect(e.day(monday.next).context!.fasting, isFalse);
    });
  });

  group('العيد', () {
    test('أول أيام الفطر: صلاة العيد بعد الشروق، معايدة، ولا دوام', () {
      final plan = engine().day(eidFitr);
      final pr = plan.prayers;
      final eid = plan.byKey('prayer:eid')!;
      expect(eid.start, pr.sunrise + 20);
      expect(plan.byKey('eid:visits')!.title, 'معايدة الأهل');
      expect(plan.items.where((i) => i.kind == ItemKind.work), isEmpty);
      expect(plan.byKey('meal:breakfast'), isNotNull);
    });

    test('ثاني أيام الأضحى: زيارات العيد بدون صلاة', () {
      final plan = engine().day(eidAdha.next);
      expect(plan.byKey('prayer:eid'), isNull);
      expect(plan.byKey('eid:visits')!.title, 'زيارات العيد');
    });

    test('وضع العيد مغلق', () {
      final plan = engine(
        settings: const AppSettings(season: SeasonSettings(eid: false)),
      ).day(eidFitr);
      expect(plan.byKey('prayer:eid'), isNull);
      expect(plan.items.where((i) => i.kind == ItemKind.work), isNotEmpty);
    });
  });

  group('الأوضاع', () {
    const sun = Day(2026, 11, 29);
    final kids = rule(
      'kid:salma',
      const KidConfig(
        child: 'سلمى',
        days: {DateTime.sunday: KidDay(drop: 6 * 60 + 40, pick: 13 * 60 + 30)},
      ),
    );

    test('الإجازة: لا دوام، ومشاوير المدرسة تتوقف إذا اخترت', () {
      final vac = LifeMode(
        id: 'v',
        kind: ModeKind.vacation,
        from: sun,
        to: sun.add(6),
      );
      final plan = engine(
        today: sun,
        modes: [vac],
        withRules: [...rules, kids],
      ).day(sun);
      expect(plan.items.where((i) => i.kind == ItemKind.work), isEmpty);
      expect(plan.items.where((i) => i.kind == ItemKind.kid), isEmpty);
      final keepKids = engine(
        today: sun,
        modes: [vac.copyWith(kidsOff: false)],
        withRules: [...rules, kids],
      ).day(sun);
      expect(keepKids.items.where((i) => i.kind == ItemKind.kid), hasLength(2));
      // اليوم بعد الإجازة يرجع عاديًا.
      final after = engine(today: sun, modes: [vac]).day(sun.add(7));
      expect(after.items.where((i) => i.kind == ItemKind.work), isNotEmpty);
    });

    test('سفر من الرياض إلى القاهرة: الصلاة بمواقيت القاهرة', () {
      final trip = LifeMode(
        id: 't',
        kind: ModeKind.travel,
        from: sun,
        to: sun.add(3),
        workOff: false,
        country: 'EG',
        city: 'القاهرة',
        lat: 30.0444,
        lng: 31.2357,
        timezone: 'Africa/Cairo',
        calcMethod: CalcMethod.egyptian,
      );
      final away = engine(today: sun, modes: [trip]).day(sun);
      initTz();
      final cairoPr = PrayerCalculator.forProfile(cairo()).forDay(sun);
      expect(away.prayers.fajr, cairoPr.fajr);
      expect(away.prayers.maghrib, cairoPr.maghrib);
      expect(away.context!.travel, isTrue);
      // «إجازة من الدوام» مغلقة: الدوام يبقى.
      expect(away.items.where((i) => i.kind == ItemKind.work), isNotEmpty);
      final home = engine(today: sun, modes: [trip]).day(sun.add(4));
      final riyadhPr = PrayerCalculator.forProfile(riyadh()).forDay(sun.add(4));
      expect(home.prayers.fajr, riyadhPr.fajr);
    });

    test('سفر في رمضان: رمضان يحدد الجدول والوجهة تحدد المواقيت', () {
      final trip = LifeMode(
        id: 't',
        kind: ModeKind.travel,
        from: ram1,
        to: ram1.add(2),
        lat: 30.0444,
        lng: 31.2357,
        timezone: 'Africa/Cairo',
        calcMethod: CalcMethod.egyptian,
      );
      final plan = engine(modes: [trip]).day(ram1);
      initTz();
      final cairoPr = PrayerCalculator.forProfile(cairo()).forDay(ram1);
      expect(plan.byKey('iftar')!.start, cairoPr.maghrib);
      expect(plan.byKey('prayer:taraweeh'), isNotNull);
      // طريقة الهيئة المصرية: لا تمديد للعشاء.
      expect(plan.prayers.isha, cairoPr.isha);
    });

    test('الإيقاف المؤقت: يبقى الثابت والوجبات، ويختفي المرن', () {
      final pause = LifeMode(
        id: 'p',
        kind: ModeKind.pause,
        from: sun,
        to: sun.add(2),
      );
      final plan = engine(today: sun, modes: [pause]).day(sun);
      expect(plan.byKey('prayer:fajr'), isNotNull);
      expect(plan.byKey('meal:breakfast'), isNotNull);
      expect(plan.byKey('quran:wird'), isNull);
      expect(plan.byKey('adhkar:morning'), isNull);
      expect(plan.items.where((i) => i.kind == ItemKind.habit), isEmpty);
    });

    test('الإيقاف يغلب الإجازة إذا تداخلا', () {
      final ctx = dayContext(
        sun,
        profile: riyadh(),
        season: const SeasonSettings(),
        modes: [
          LifeMode(id: 'v', kind: ModeKind.vacation, from: sun, to: sun),
          LifeMode(id: 'p', kind: ModeKind.pause, from: sun, to: sun),
        ],
      );
      expect(ctx.paused, isTrue);
    });
  });

  group('العطل الرسمية', () {
    const national = Holiday(name: 'اليوم الوطني', month: 9, day: 23);
    const day = Day(2027, 9, 23); // الخميس

    test('العطلة تلغي الدوام ومشاوير المدرسة', () {
      final plan = engine(today: day, holidays: [national]).day(day);
      expect(plan.context!.holiday?.name, 'اليوم الوطني');
      expect(plan.items.where((i) => i.kind == ItemKind.work), isEmpty);
    });

    test('إيقاف العطل من الإعدادات', () {
      final plan = engine(
        today: day,
        holidays: [national],
        settings: const AppSettings(season: SeasonSettings(holidays: false)),
      ).day(day);
      expect(plan.context!.holiday, isNull);
      expect(plan.items.where((i) => i.kind == ItemKind.work), isNotEmpty);
    });

    test('عطلة بأكثر من يوم وبالهجري', () {
      const two = Holiday(name: 'عيد الاتحاد', month: 12, day: 2, days: 2);
      expect(two.on(const Day(2026, 12, 3)), isTrue);
      expect(two.on(const Day(2026, 12, 4)), isFalse);
      const hijri = Holiday(name: 'رأس السنة', month: 1, day: 1, hijri: true);
      expect(hijri.on(const Day(2026, 6, 16)), isTrue);
    });
  });

  group('مواعيد التقويم', () {
    const d = Day(2026, 11, 26);
    test('ثابتة وخارج النسبة، والمحرك يتجنبها', () {
      final ev = ImportedEvent(
        id: 'g1',
        date: d,
        title: 'موعد الأسنان',
        start: 17 * 60,
        end: 18 * 60,
        source: 'Google',
        calendar: 'شخصي',
      );
      final allDay = ImportedEvent(id: 'g2', date: d, title: 'إجازة زميل');
      final plan = engine(today: d, imported: [ev, allDay]).day(d);
      final item = plan.byKey('cal:g1')!;
      expect(item.fixed, isTrue);
      expect(item.counted, isFalse);
      expect(item.subtitle, 'Google · شخصي');
      expect(plan.allDay, ['إجازة زميل']);
      for (final i in plan.items.where((i) => !i.fixed)) {
        expect(i.span.overlaps(item.span), isFalse, reason: i.key);
      }
    });
  });

  group('مشاوير الأولاد مع الشريك', () {
    const sun = Day(2026, 11, 29);
    final kids = rule(
      'kid:salma',
      const KidConfig(
        child: 'سلمى',
        days: {
          DateTime.sunday: KidDay(drop: 6 * 60 + 40, pick: 13 * 60 + 30),
          DateTime.monday: KidDay(drop: 6 * 60 + 40),
        },
      ),
    );
    const share = PartnerShare(
      name: 'أم عيسى',
      phone: '0500000000',
      runs: {
        'kid:salma:pick': RunAssign(RunWho.partner),
        'kid:salma:drop': RunAssign(
          RunWho.byDays,
          partnerDays: {DateTime.monday},
        ),
      },
    );

    test('مشوار الشريك للعلم: لا يحجز وقتًا ولا يُحسب ولا ينبّه', () {
      final e = engine(today: sun, partner: share, withRules: [kids, ...rules]);
      final plan = e.day(sun);
      final pick = plan.byKey('kid:salma:pick')!;
      expect(pick.partner, isTrue);
      expect(pick.counted, isFalse);
      expect(pick.subtitle, 'على أم عيسى اليوم');
      expect(plan.busy.any((b) => b.key == pick.key), isFalse);
      expect(plan.byKey('kid:salma:drop')!.partner, isFalse);
      expect(e.day(sun.next).byKey('kid:salma:drop')!.partner, isTrue);
      final n = planNotifications(
        plan,
        const AppSettings(),
        today: sun.prev,
        now: 0,
      );
      expect(n.send.any((x) => x.itemKey == pick.key), isFalse);
    });

    test('تبديل يوم واحد من البطاقة', () {
      final ov = {
        recordKey(sun, 'kid:salma:pick'): const DayOverride(
          date: sun,
          itemKey: 'kid:salma:pick',
          who: 'me',
        ),
      };
      final e = engine(
        today: sun,
        partner: share,
        overrides: ov,
        withRules: [kids, ...rules],
      );
      expect(e.day(sun).byKey('kid:salma:pick')!.partner, isFalse);
      expect(e.day(sun.add(7)).byKey('kid:salma:pick')!.partner, isTrue);
    });

    test('بدون اسم شريك: كل المشاوير عليك', () {
      final e = engine(
        today: sun,
        partner: const PartnerShare(
          runs: {'kid:salma:pick': RunAssign(RunWho.partner)},
        ),
        withRules: [kids, ...rules],
      );
      expect(e.day(sun).byKey('kid:salma:pick')!.partner, isFalse);
    });
  });

  group('الحفظ', () {
    test('الإعدادات والأوضاع والمشاركة تمر عبر JSON', () {
      const s = SeasonSettings(
        fasting: FastingMode.ramadanMonThu,
        ramadanWorkStart: 9 * 60,
        ramadanYears: {1448: true, 1449: false},
      );
      final back = SeasonSettings.fromJson(s.toJson());
      expect(back.fasting, FastingMode.ramadanMonThu);
      expect(back.ramadanWorkStart, 540);
      expect(back.ramadanYears, {1448: true, 1449: false});
      final a = AppSettings.fromJson(const AppSettings(season: s).toJson());
      expect(a.season.ramadanYears[1448], isTrue);
      final m = LifeMode(
        id: 't',
        kind: ModeKind.travel,
        from: const Day(2026, 12, 1),
        to: const Day(2026, 12, 5),
        lat: 30,
        lng: 31,
        timezone: 'Africa/Cairo',
        calcMethod: CalcMethod.egyptian,
      );
      final m2 = LifeMode.fromJson(m.toJson());
      expect(m2.hasPlace, isTrue);
      expect(m2.days, 5);
      const share = PartnerShare(
        name: 'س',
        runs: {
          'k': RunAssign(RunWho.byDays, partnerDays: {1, 3}),
        },
      );
      expect(PartnerShare.fromJson(share.toJson()).runs['k']!.partnerDays, {
        1,
        3,
      });
      const ov = DayOverride(date: Day(2026, 1, 1), itemKey: 'x', who: 'me');
      expect(DayOverride.fromJson(ov.toJson()).who, 'me');
    });
  });
}
