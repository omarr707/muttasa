import 'package:schedule_core/schedule_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  const thu = Day(2026, 11, 26); // خميس
  const sun = Day(2026, 11, 22);

  group('الصلوات', () {
    test('مواقيت الرياض قريبة من أم القرى', () {
      final plan = ScheduleEngine(input()).day(thu);
      final fajr = plan.byKey('prayer:fajr')!;
      // الفجر في الرياض أواخر نوفمبر قرابة 4:55 ص.
      expect(fajr.start, inInclusiveRange(4 * 60 + 45, 5 * 60 + 5));
      expect(plan.byKey('prayer:isha')!.start - plan.byKey('prayer:maghrib')!.start, 90);
    });

    test('الجمعة بدل الظهر، من 20 دقيقة قبل الأذان إلى 25 بعده', () {
      final engine = ScheduleEngine(input());
      final fri = engine.day(const Day(2026, 11, 27));
      expect(fri.hasKey('prayer:dhuhr'), isFalse);
      final j = fri.byKey('prayer:jumuah')!;
      expect(j.duration, 45);
      expect(j.start, fri.prayers.dhuhr - 20);
    });

    test('الظهر داخل الدوام = مصلى العمل، وليس تعارضًا', () {
      final rules = [...basicRules, rule('work', morningWork(bs: null, be: null))];
      final plan = ScheduleEngine(input(rules: rules)).day(sun);
      expect(plan.byKey('prayer:dhuhr')!.subtitle, 'مصلى العمل');
      expect(plan.conflicts, isEmpty);
    });

    test('مع «بدون» تختفي الصلوات والأذكار', () {
      final p = riyadh().copyWith(religion: Religion.none);
      final plan = ScheduleEngine(input(profile: p)).day(thu);
      expect(plan.items.where((i) => i.kind == ItemKind.prayer || i.kind == ItemKind.adhkar), isEmpty);
    });
  });

  group('الوضع والترتيب', () {
    test('أذكار الصباح بعد الفجر والورد بعدها', () {
      final plan = ScheduleEngine(input()).day(thu);
      final fajr = plan.byKey('prayer:fajr')!;
      final adhkar = plan.byKey('adhkar:morning')!;
      final wird = plan.byKey('quran:wird')!;
      expect(adhkar.start, greaterThanOrEqualTo(fajr.end));
      expect(adhkar.start - fajr.end, lessThan(10));
      expect(wird.start, greaterThanOrEqualTo(adhkar.end));
      expect(wird.pagesFrom, 1);
      expect(wird.pagesTo, 4);
    });

    test('الفطور في وقته المفضل', () {
      final plan = ScheduleEngine(input()).day(thu);
      expect(plan.byKey('meal:breakfast')!.start, 6 * 60 + 30);
    });

    test('الورد يكمل من آخر صفحة مسجّلة', () {
      final logs = {
        recordKey(thu.prev, 'quran:wird'): ItemLog(
          date: thu.prev,
          itemKey: 'quran:wird',
          status: ItemStatus.done,
          value: 37,
          value2: 40,
        ),
      };
      final plan = ScheduleEngine(input(logs: logs)).day(thu);
      expect(plan.byKey('quran:wird')!.pagesFrom, 41);
      expect(plan.byKey('quran:wird')!.pagesTo, 44);
    });

    test('عادة 3 مرات بالأسبوع: اليوم الثاني والرابع والسابع', () {
      final engine = ScheduleEngine(input());
      final plan = engine.weekPlan(thu)['habit:walk']!;
      final ws = thu.weekStart; // السبت
      expect(plan, {ws.add(1), ws.add(3), ws.add(6)});
    });

    test('المرن لا يدخل الدوام خارج الاستراحة، والاستراحة متاحة', () {
      final rules = [
        ...basicRules,
        rule('work', morningWork()),
        rule(
          'habit:quick',
          const FlexConfig(kind: RuleKind.habit, title: 'مراجعة', duration: 20, windows: [Window.morning], preferred: 600),
        ),
      ];
      final plan = ScheduleEngine(input(rules: rules)).day(sun);
      final q = plan.byKey('habit:quick')!;
      // الصباح بعد 7:30 كله دوام إلا الاستراحة 12:00 إلى 12:30، والظهر داخلها؟
      final inWorkOutsideBreak = q.start < 960 && q.end > 450 && !(q.start >= 720 && q.end <= 750);
      expect(inWorkOutsideBreak, isFalse);
    });
  });

  group('سيناريوهات الوثيقة', () {
    test('وردية 10 م إلى 6 ص: ذيل الوردية في اليوم التالي، ونوم 7 ساعات بعده بنصف ساعة', () {
      final work = WorkConfig(
        pattern: WorkPattern.night,
        days: {DateTime.sunday: [const WorkPeriod(22 * 60, 6 * 60)]},
      );
      final engine = ScheduleEngine(input(rules: [...basicRules, rule('work', work)]));
      final mon = engine.day(sun.next);
      final tail = mon.byKey('work#tail')!;
      expect(tail.start, 0);
      expect(tail.end, 360);
      final sleep = mon.busy.firstWhere((b) => b.kind == BusyKind.sleep && b.span.start > 0);
      expect(sleep.span, const Span(390, 390 + 420));
      // لا شيء مرن داخل النوم.
      for (final i in mon.items.where((i) => !i.fixed)) {
        expect(i.span.overlaps(sleep.span), isFalse, reason: i.key);
      }
      final sunPlan = engine.day(sun);
      expect(sunPlan.byKey('work#0')!.end, minutesPerDay);
    });

    test('موعد أولاد في وقت الدوام: شريط تعارض، ولا يتحرك أي منهما', () {
      final kid = KidConfig(child: 'سلمى', days: {DateTime.sunday: const KidDay(pick: 13 * 60)});
      final rules = [...basicRules, rule('work', morningWork()), rule('kid:salma', kid)];
      final plan = ScheduleEngine(input(rules: rules)).day(sun);
      expect(plan.conflicts, hasLength(1));
      expect(plan.byKey('kid:salma:pick')!.start, 13 * 60);
      expect(plan.byKey('work#0')!.start, 450);
    });

    test('موعد داخل الاستراحة ليس تعارضًا', () {
      final kid = KidConfig(child: 'سلمى', trip: 20, days: {DateTime.sunday: const KidDay(pick: 725)});
      final rules = [...basicRules, rule('work', morningWork()), rule('kid:salma', kid)];
      final plan = ScheduleEngine(input(rules: rules)).day(sun);
      expect(plan.conflicts, isEmpty);
    });

    test('يوم تغيير التوقيت الصيفي في مصر: لا عنصر مكرر أو مفقود', () {
      final rules = basicRules;
      for (final d in [const Day(2026, 4, 23), const Day(2026, 4, 24), const Day(2026, 4, 25), const Day(2026, 10, 29), const Day(2026, 10, 30)]) {
        final plan = ScheduleEngine(input(profile: cairo(), rules: rules, today: d)).day(d);
        final keys = plan.items.map((i) => i.key).toList();
        expect(keys.toSet().length, keys.length, reason: '$d');
        expect(plan.items.where((i) => i.kind == ItemKind.prayer).length, 5, reason: '$d');
        final ps = [plan.prayers.fajr, plan.prayers.dhuhr, plan.prayers.asr, plan.prayers.maghrib, plan.prayers.isha];
        for (var i = 1; i < ps.length; i++) {
          expect(ps[i], greaterThan(ps[i - 1]));
        }
      }
    });

    test('عادة 4 مرات بالأسبوع وأيام ممتلئة: تنتقل لأيام فيها مكان، وما لا يجد يظهر «ما لقت وقت»', () {
      // ممتلئ بالكامل من السبت إلى الثلاثاء بفترات طويلة.
      final busyWork = WorkConfig(days: {
        for (final d in [DateTime.saturday, DateTime.sunday, DateTime.monday, DateTime.tuesday]) d: [const WorkPeriod(270, 1350)],
      });
      final habit = rule(
        'habit:gym',
        const FlexConfig(kind: RuleKind.habit, title: 'النادي', duration: 60, recurrence: TimesPerWeek(4), windows: [Window.any]),
      );
      final engine = ScheduleEngine(input(rules: [rule('work', busyWork), habit]));
      final chosen = engine.weekPlan(thu)['habit:gym']!;
      final ws = thu.weekStart;
      // الأيام الممتلئة لا تُختار، فتنتقل إلى الأربعاء والخميس والجمعة.
      for (final d in chosen) {
        expect(d.difference(ws), greaterThanOrEqualTo(4));
      }
      final week = habitWeek(engine, habit, thu);
      expect(week.target, 4);
      expect(week.plannedDays.length, 3);
    });

    test('تأجيل عنصر إلى بكرة وهو موجود بكرة: لا يتكرر', () {
      final engine = ScheduleEngine(input());
      final plan = engine.day(thu);
      expect(needsCarry(engine, plan.byKey('meal:breakfast')!, thu), isFalse);
    });

    test('سحب مشي إلى وقت الدوام: السبب + أقرب وقت فاضٍ', () {
      final walk = rule(
        'habit:walk',
        const FlexConfig(kind: RuleKind.habit, title: 'المشي', duration: 30, windows: [Window.afternoon], track: TrackMode.start),
      );
      final rules = [...basicRules.where((r) => r.key != 'habit:walk'), rule('work', morningWork()), walk];
      final plan = ScheduleEngine(input(rules: rules)).day(sun);
      final item = plan.byKey('habit:walk')!;
      final check = checkMove(plan, item, 10 * 60);
      expect(check.ok, isFalse);
      expect(check.reason, 'داخل الدوام خارج الاستراحة');
      expect(check.suggestion, isNotNull);
      expect(checkMove(plan, item, check.suggestion!).ok, isTrue);
    });

    test('تغيير التشكيلة بعد نقل يدوي بكرة: المعاينة تذكر اليوم المعدّل والنقل باقٍ', () {
      final tomorrow = thu.next;
      final overrides = {
        recordKey(tomorrow, 'meal:breakfast'): DayOverride(date: tomorrow, itemKey: 'meal:breakfast', start: 8 * 60),
      };
      final before = ScheduleEngine(input(overrides: overrides));
      final newRules = [
        for (final r in basicRules)
          if (r.key == 'quran:wird')
            r.copyWith(config: (r.config as FlexConfig).copyWith(duration: 20))
          else
            r,
      ];
      final after = ScheduleEngine(before.input.copyWith(rules: newRules));
      final diff = previewChanges(before, after, thu, days: 3);
      expect(diff[1].hasManualEdits, isTrue);
      expect(after.day(tomorrow).byKey('meal:breakfast')!.start, 8 * 60);
      expect(after.day(tomorrow).byKey('meal:breakfast')!.manual, isTrue);
    });

    test('«من اليوم فصاعدًا» لا يغيّر الأيام السابقة', () {
      final base = basicRules.firstWhere((r) => r.key == 'meal:breakfast');
      final closed = base.copyWith(validTo: thu.prev);
      final next = Rule(
        id: 'b2',
        key: base.key,
        validFrom: thu,
        config: (base.config as FlexConfig).copyWith(preferred: 7 * 60),
      );
      final rules = [...basicRules.where((r) => r.key != base.key), closed, next];
      final engine = ScheduleEngine(input(rules: rules));
      expect(engine.day(thu.prev).byKey('meal:breakfast')!.start, 6 * 60 + 30);
      expect(engine.day(thu).byKey('meal:breakfast')!.start, 7 * 60);
    });
  });

  group('الحالات والإنجاز', () {
    test('ما قبل دقيقة الانضمام في أول يوم خارج النسبة', () {
      final p = riyadh(joinedAt: DateTime(2026, 11, 26, 9, 0));
      final plan = ScheduleEngine(input(profile: p, now: 9 * 60 + 5)).day(thu);
      expect(plan.byKey('prayer:fajr')!.status, ItemStatus.preJoin);
      expect(plan.byKey('prayer:asr')!.status, ItemStatus.pending);
      expect(dayProgress(plan).total, lessThan(dayProgress(ScheduleEngine(input()).day(thu)).total));
    });

    test('أمس بدون تسجيل = فاتت، والمحسوب تلقائيًا = auto', () {
      final plan = ScheduleEngine(input()).day(thu.prev);
      expect(plan.byKey('prayer:fajr')!.status, ItemStatus.missed);
      expect(unloggedItems(plan), isNotEmpty);
    });

    test('الإنجاز: تمت في البسط، المؤجل والمستثنى خارج المقام', () {
      final logs = {
        recordKey(thu, 'prayer:fajr'): ItemLog(date: thu, itemKey: 'prayer:fajr', status: ItemStatus.done),
        recordKey(thu, 'meal:breakfast'): ItemLog(date: thu, itemKey: 'meal:breakfast', status: ItemStatus.skipped),
        recordKey(thu, 'quran:wird'): ItemLog(date: thu, itemKey: 'quran:wird', status: ItemStatus.postponed),
      };
      final base = dayProgress(ScheduleEngine(input()).day(thu));
      final p = dayProgress(ScheduleEngine(input(logs: logs)).day(thu));
      expect(p.done, 1);
      expect(p.total, base.total - 2);
    });

    test('الجلسة الإضافية تدخل العدّ فقط عندما تتم', () {
      final extra = OneOff(
        id: 'x1',
        kind: OneOffKind.habitSession,
        title: 'جلسة إضافية: المشي',
        date: thu,
        duration: 30,
        habitKey: 'habit:walk',
      );
      final p0 = dayProgress(ScheduleEngine(input()).day(thu));
      final p1 = dayProgress(ScheduleEngine(input(oneOffs: [extra])).day(thu));
      expect(p1.total, p0.total);
      final logs = {recordKey(thu, extra.itemKey): ItemLog(date: thu, itemKey: extra.itemKey, status: ItemStatus.done)};
      final p2 = dayProgress(ScheduleEngine(input(oneOffs: [extra], logs: logs)).day(thu));
      expect(p2.total, p0.total + 1);
      expect(p2.done, 1);
    });

    test('الدوام والتذكيرات القصيرة خارج النسبة', () {
      final rules = [...basicRules, rule('work', morningWork())];
      final plan = ScheduleEngine(input(rules: rules)).day(sun);
      expect(plan.byKey('work#0')!.inDenominator, isFalse);
      expect(plan.lines.where((l) => l.kind == LineKind.water), isNotEmpty);
    });
  });

  group('الإجراءات', () {
    test('«أعد ترتيب يومي» ينقل المتأخر غير المسجّل بعد الآن', () {
      final plan = ScheduleEngine(input(now: 10 * 60)).day(thu);
      final r = rearrangeDay(plan, 10 * 60);
      expect(r.moves.keys, containsAll(['adhkar:morning', 'quran:wird', 'meal:breakfast']));
      for (final m in r.moves.values) {
        expect(m, greaterThanOrEqualTo(10 * 60 + 5));
      }
      // لا تداخل بين المنقولات.
      final spans = r.moves.entries.map((e) => Span(e.value, e.value + plan.byKey(e.key)!.duration)).toList();
      for (var i = 0; i < spans.length; i++) {
        for (var j = i + 1; j < spans.length; j++) {
          expect(spans[i].overlaps(spans[j]), isFalse);
        }
      }
    });

    test('الحد اليومي للوقت الاختياري', () {
      final many = [
        for (var i = 0; i < 6; i++)
          rule('habit:h$i', FlexConfig(kind: RuleKind.habit, title: 'عادة $i', duration: 45, optional: true)),
      ];
      final plan = ScheduleEngine(input(rules: many)).day(thu);
      final used = plan.items.where((i) => i.optional).fold<int>(0, (a, i) => a + i.duration);
      expect(used, lessThanOrEqualTo(180));
      expect(plan.unplaced.where((u) => u.reason == UnplacedReason.cap), isNotEmpty);
    });

    test('التنبيهات: الصلاة فوق الحد وأوقات الهدوء', () {
      final settings = const AppSettings(dailyCap: 2, quietStart: 0, quietEnd: 12 * 60);
      final plan = ScheduleEngine(input(now: 0, settings: settings)).day(thu);
      final n = planNotifications(plan, settings, today: thu, now: 0);
      final prayers = n.send.where((x) => x.kind == NotifyKind.prayer).length;
      expect(prayers, 5);
      expect(n.send.length - prayers, lessThanOrEqualTo(2));
      expect(n.dropped.any((d) => d.reason == 'في أوقات الهدوء'), isTrue);
      final ids = n.send.map((x) => x.id).toSet();
      expect(ids.length, n.send.length);
    });
  });
}
