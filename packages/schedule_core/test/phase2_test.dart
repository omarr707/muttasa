import 'package:schedule_core/schedule_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  const today = Day(2026, 11, 26);

  Rule khatma(Day by, {int startPage = 1}) => rule(
    'quran:wird',
    FlexConfig(
      kind: RuleKind.quran,
      title: 'ورد القرآن',
      icon: 'book',
      duration: 10,
      windows: const [Window.afterFajr],
      pages: 4,
      book: 'المصحف',
      startPage: startPage,
      category: 'quran',
      khatmaBy: by,
    ),
  );

  ItemLog pagesLog(Day d, String key, int from, int to) => ItemLog(
    date: d,
    itemKey: key,
    status: ItemStatus.done,
    value: from,
    value2: to,
  );

  group('الختمة', () {
    test('صفحات اليوم = المتبقي ÷ الأيام الباقية', () {
      // 34 يومًا من اليوم حتى 29 ديسمبر شاملة، 604 صفحة ← 18 صفحة.
      final e = ScheduleEngine(
        input(rules: [khatma(const Day(2026, 12, 29))], today: today),
      );
      final q = e.day(today).byKey('quran:wird')!;
      expect(q.pagesFrom, 1);
      expect(q.pagesTo! - q.pagesFrom! + 1, (604 / 34).ceil());
      expect(q.subtitle, contains('ختمة قبل 29'));
      expect(q.duration, greaterThanOrEqualTo(10));
    });

    test('تتعدل مع كل تسجيل وتبقى ثابتة داخل اليوم', () {
      final rules = [khatma(const Day(2026, 12, 29))];
      final logs = {
        recordKey(today.prev, 'quran:wird'): pagesLog(
          today.prev,
          'quran:wird',
          1,
          304,
        ),
      };
      final e = ScheduleEngine(input(rules: rules, logs: logs, today: today));
      final q = e.day(today).byKey('quran:wird')!;
      expect(q.pagesFrom, 305);
      expect(q.pagesTo! - q.pagesFrom! + 1, (300 / 34).ceil());
      // تسجيل اليوم لا يغيّر خطة اليوم نفسه.
      final logs2 = {
        ...logs,
        recordKey(today, 'quran:wird'): pagesLog(today, 'quran:wird', 305, 400),
      };
      final e2 = ScheduleEngine(input(rules: rules, logs: logs2, today: today));
      expect(e2.day(today).byKey('quran:wird')!.pagesFrom, 305);
      // وبكرة يُعاد التوزيع.
      final tmr = e2.day(today.next).byKey('quran:wird')!;
      expect(tmr.pagesFrom, 401);
      expect(tmr.pagesTo! - tmr.pagesFrom! + 1, (204 / 33).ceil());
    });

    test('بعد الختم ما يظهر ورد، والهدف المشتق «تحقق»', () {
      final rules = [khatma(const Day(2026, 12, 29))];
      final logs = {
        recordKey(today.prev, 'quran:wird'): pagesLog(
          today.prev,
          'quran:wird',
          1,
          604,
        ),
      };
      final e = ScheduleEngine(input(rules: rules, logs: logs, today: today));
      expect(e.day(today).byKey('quran:wird'), isNull);
      final g = e.derivedGoals(const []);
      expect(g.single.metric, GoalMetric.khatma);
      expect(e.goalStatus(g.single).state, GoalState.achieved);
    });
  });

  group('الادخار', () {
    final savings = rule(
      'savings',
      const SavingsConfig(payDay: 31, monthly: 500, target: 6000),
    );

    test('بطاقة يوم الراتب، والشهر الأقصر يأخذ آخر يوم', () {
      final e = ScheduleEngine(input(rules: [...basicRules, savings]));
      expect(e.day(const Day(2026, 11, 30)).byKey('savings'), isNotNull);
      expect(e.day(const Day(2026, 11, 29)).byKey('savings'), isNull);
      expect(e.day(const Day(2026, 12, 31)).byKey('savings'), isNotNull);
      expect(e.day(const Day(2027, 2, 28)).byKey('savings'), isNotNull);
      final s = e.day(const Day(2026, 11, 30)).byKey('savings')!;
      expect(s.kind, ItemKind.savings);
      expect(s.subtitle, contains('500'));
    });

    test('المبلغ المسجّل يغذي هدف الادخار المشتق', () {
      final logs = {
        recordKey(const Day(2026, 11, 20), 'savings'): const ItemLog(
          date: Day(2026, 11, 20),
          itemKey: 'savings',
          status: ItemStatus.done,
          value: 700,
        ),
        recordKey(const Day(2026, 11, 22), 'savings:manual:a'): const ItemLog(
          date: Day(2026, 11, 22),
          itemKey: 'savings:manual:a',
          status: ItemStatus.done,
          value: 300,
        ),
      };
      final e = ScheduleEngine(
        input(rules: [...basicRules, savings], logs: logs),
      );
      final g = e.derivedGoals(const []).single;
      expect(g.metric, GoalMetric.money);
      expect(e.goalValue(g), 1000);
      expect(e.goalStatus(g).state, GoalState.noDue);
      // هدف مال من المستخدم يلغي المشتق.
      final mine = Goal(
        id: 'g',
        title: 'سيارة',
        metric: GoalMetric.money,
        target: 1000,
        start: const Day(2026, 11, 1),
      );
      expect(e.derivedGoals([mine]), isEmpty);
      expect(e.goalStatus(mine).state, GoalState.achieved);
    });
  });

  group('الأهداف', () {
    test('عدد يدوي: على الخط، متأخر، انتهى الموعد', () {
      final e = ScheduleEngine(input(today: today));
      Goal g(int v, {Day? due}) => Goal(
        id: 'g',
        title: 'أحفظ 30 حديث',
        metric: GoalMetric.count,
        target: 30,
        unit: 'حديث',
        start: const Day(2026, 11, 1),
        due: due ?? const Day(2026, 12, 30),
        entries: [GoalEntry(const Day(2026, 11, 10), v)],
      );
      // مضى 25 يوم من 60 ← المتوقع 12.5
      expect(e.goalStatus(g(12)).state, GoalState.onTrack);
      final late = e.goalStatus(g(5));
      expect(late.state, GoalState.behind);
      expect(late.message, contains('المفروض توصل 12'));
      expect(late.expected, closeTo(12.5, .01));
      expect(
        e.goalStatus(g(5, due: const Day(2026, 11, 20))).state,
        GoalState.expired,
      );
      expect(e.goalStatus(g(30)).state, GoalState.achieved);
    });

    test('جلسات عادة: «ما يكفي» إذا التكرار لا يوصل للهدف', () {
      final logs = <String, ItemLog>{
        for (final d in [
          const Day(2026, 11, 21),
          const Day(2026, 11, 23),
          const Day(2026, 11, 25),
        ])
          recordKey(d, 'habit:walk'): ItemLog(
            date: d,
            itemKey: 'habit:walk',
            status: ItemStatus.done,
          ),
      };
      final e = ScheduleEngine(input(logs: logs, today: today));
      final g = Goal(
        id: 'g',
        title: 'أمشي 40 مرة',
        metric: GoalMetric.sessions,
        target: 40,
        start: const Day(2026, 11, 20),
        due: const Day(2027, 2, 17),
        linkKey: 'habit:walk',
      );
      expect(e.goalValue(g), 3);
      final s = e.goalStatus(g);
      // على الخط بالنسبة للوقت، لكن 3 بالأسبوع × 12 أسبوع + 3 = 39 < 40
      expect(s.state, GoalState.notEnough);
      expect(s.message, contains('زِد تكرار العادة'));
    });

    test('صفحات مرتبطة بعادة القراءة تُجمع من سجلاتها', () {
      final logs = {
        recordKey(today.prev, 'habit:read'): pagesLog(
          today.prev,
          'habit:read',
          1,
          20,
        ),
        recordKey(today, 'habit:read'): pagesLog(today, 'habit:read', 21, 45),
      };
      final e = ScheduleEngine(input(logs: logs, today: today));
      final g = Goal(
        id: 'g',
        title: 'صفحات',
        metric: GoalMetric.pages,
        target: 3000,
        start: const Day(2026, 11, 1),
        linkKey: 'habit:read',
      );
      expect(e.goalValue(g), 45);
    });

    test('JSON ذهابًا وإيابًا', () {
      final g = Goal(
        id: 'x',
        title: 'كتب',
        metric: GoalMetric.books,
        target: 12,
        start: const Day(2026, 1, 1),
        due: const Day(2026, 12, 31),
        linkKey: 'habit:read',
        entries: const [GoalEntry(Day(2026, 3, 1), 1)],
      );
      final back = Goal.fromJson(g.toJson());
      expect(back.toJson(), g.toJson());
      expect(fmtThousands(10000), '10,000');
    });
  });

  group('تقرير الالتزام', () {
    test('شهري: أيام من الانضمام حتى اليوم، والمجموعات، والسلسلة', () {
      final profile = riyadh(joinedAt: DateTime(2026, 11, 10));
      final logs = <String, ItemLog>{};
      // صلّى كل الفروض من 20 إلى 25.
      for (
        var d = const Day(2026, 11, 20);
        !d.isAfter(today.prev);
        d = d.next
      ) {
        for (final p in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
          logs[recordKey(d, 'prayer:$p')] = ItemLog(
            date: d,
            itemKey: 'prayer:$p',
            status: ItemStatus.done,
          );
        }
      }
      final e = ScheduleEngine(
        input(profile: profile, logs: logs, today: today),
      );
      final r = e.monthReport(2026, 11);
      expect(r.from, const Day(2026, 11, 10));
      expect(r.days.keys.last, today);
      expect(r.days.length, 17);
      // الجمعة 20 نوفمبر مفتاحها صلاة الجمعة بدل الظهر.
      expect(r.byGroup[ReportGroup.prayer]!.done, 29);
      expect(r.total.total, greaterThan(r.total.done));
      expect(r.bestWorstWeekday, isNotNull);
      // قبل الانضمام: فارغ.
      expect(e.monthReport(2026, 10).isEmpty, isTrue);
      final y = e.yearReport(2026);
      expect(y.total.done, r.total.done);
    });
  });

  group('الزيارات', () {
    test('زيارة الأهل تُقترح في عطلة نهاية الأسبوع فقط', () {
      const sat = Day(2026, 11, 21);
      final base = input();
      final e = ScheduleEngine(
        EngineInput(
          profile: base.profile,
          rules: base.rules,
          people: const [
            Person(
              id: 'v',
              name: 'جدتي',
              method: ContactMethod.visit,
              freq: ContactFreq.weekly,
              addedAt: Day(2026, 11, 1),
            ),
            Person(
              id: 'c',
              name: 'سعد',
              freq: ContactFreq.weekly,
              addedAt: Day(2026, 11, 1),
            ),
          ],
          contacts: const ContactsConfig(enabled: true),
          prayers: base.prayers,
          today: base.today,
          nowMinute: 0,
        ),
      );
      final week = e.contactWeek(sat);
      final visitDay = week.entries
          .firstWhere((x) => x.value.any((p) => p.id == 'v'))
          .key;
      expect(base.profile.weekend, contains(visitDay.weekday));
      final item = e.day(visitDay).byKey('contact:v')!;
      expect(item.title, 'زُر جدتي');
      expect(item.duration, 60);
    });
  });
}
