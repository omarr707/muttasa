import 'package:schedule_core/schedule_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  const fri = Day(2026, 11, 27); // إجازة
  const tue = Day(2026, 12, 1); // دوام
  final withWork = [...basicRules, rule('work', morningWork())];

  test('الحركة تظهر يوم الإجازة أيضًا، والماء والتنفّس كل يوم', () {
    final e = ScheduleEngine(input(rules: withWork, today: fri));
    for (final d in [fri, tue]) {
      final lines = e.day(d).lines;
      expect(lines.where((l) => l.kind == LineKind.stand), isNotEmpty);
      expect(lines.where((l) => l.kind == LineKind.water), isNotEmpty);
      expect(lines.where((l) => l.kind == LineKind.breathe), isNotEmpty);
    }
  });

  test('عدد تذكيرات الماء منفصل عن الهدف، والتنفّس أكثر من جلسة', () {
    final rules = [
      ...basicRules.where((r) => r.key != 'reminders'),
      rule(
        'reminders',
        const RemindersConfig(
          cups: 8,
          waterAlerts: 3,
          breatheSlots: {BreatheSlot.morning, BreatheSlot.night},
          standDays: {DateTime.sunday},
        ),
      ),
    ];
    final e = ScheduleEngine(input(rules: rules, today: fri));
    final lines = e.day(fri).lines;
    expect(lines.where((l) => l.kind == LineKind.water).length, 3);
    expect(
      lines.where((l) => l.kind == LineKind.breathe).map((l) => l.key).toSet(),
      {'breathe#am', 'breathe#pm'},
    );
    // الحركة مقصورة على الأحد هنا.
    expect(lines.where((l) => l.kind == LineKind.stand), isEmpty);
  });

  test('التزام بأكثر من فترة في اليوم يظهر ثابتًا بكل فتراته', () {
    final rules = [
      ...basicRules,
      rule(
        'class:uni',
        const ClassConfig(
          title: 'محاضرة',
          type: CommitmentType.university,
          weekdays: {DateTime.tuesday},
          start: 480,
          end: 600,
          slots: {
            DateTime.tuesday: [Slot(480, 600), Slot(780, 870)],
          },
        ),
      ),
    ];
    final plan = ScheduleEngine(input(rules: rules, today: tue)).day(tue);
    final uni = plan.items.where((i) => i.ruleKey == 'class:uni').toList();
    expect(uni.map((i) => i.start), [480, 780]);
    expect(uni.every((i) => i.fixed), isTrue);
  });

  test('صحتي: قياس السكر في أوقات المستخدم، وما يتحرك مع الزحزحة', () {
    final rules = [
      ...basicRules,
      rule(
        'health',
        const HealthConfig(
          checks: [
            HealthCheck(
              id: 'g',
              kind: HealthCheckKind.glucose,
              title: 'قياس السكر',
              times: [7 * 60, 21 * 60],
            ),
          ],
        ),
      ),
    ];
    final plan = ScheduleEngine(input(rules: rules, today: fri)).day(fri);
    final g = plan.items.where((i) => i.category == 'health').toList();
    expect(g.map((i) => i.start), [7 * 60, 21 * 60]);
    expect(g.any(isMovable), isFalse);
  });

  test('الرضيع: خطوط الرضعات من الصحيان للنوم', () {
    final rules = [
      ...basicRules,
      rule(
        'mother',
        const MotherConfig(stage: MotherStage.infant, feedEvery: 180),
      ),
    ];
    final plan = ScheduleEngine(input(rules: rules, today: fri)).day(fri);
    final feeds = plan.lines.where((l) => l.key.startsWith('feed#')).toList();
    expect(feeds.length, greaterThanOrEqualTo(5));
  });

  test('يوم خفيف: الثابت يبقى والمرن يتأجل', () {
    final e = ScheduleEngine(input(rules: withWork, today: tue, now: 6 * 60));
    final plan = e.day(tue);
    final props = lightDay(plan, now: 6 * 60, isToday: true);
    expect(props, isNotEmpty);
    for (final p in props) {
      expect(p.item.fixed, isFalse);
      expect(p.item.kind, isNot(ItemKind.prayer));
      expect(p.item.kind, isNot(ItemKind.meal));
    }
    final kept = lightDay(
      plan,
      now: 6 * 60,
      isToday: true,
      priorities: {props.first.item.key},
    );
    expect(kept.first.action, LightAction.keep);
  });

  test(
    'تغيير وردية الثلاثاء لهذا اليوم فقط: الصلاة والحصة ثابتة والمرن يتحرك والسجل باقٍ',
    () {
      final rules = [
        ...withWork,
        rule(
          'class:c',
          const ClassConfig(
            title: 'دورة',
            weekdays: {DateTime.tuesday},
            start: 17 * 60,
            end: 18 * 60,
          ),
        ),
      ];
      final logs = {
        recordKey(tue, 'quran:wird'): ItemLog(
          date: tue,
          itemKey: 'quran:wird',
          status: ItemStatus.done,
          doneAt: 300,
        ),
      };
      final before = ScheduleEngine(
        input(rules: rules, today: tue, logs: logs),
      ).day(tue);
      // الوردية الجديدة لهذا اليوم: مسائية بدل الصباحية.
      final shifted = [
        ...rules.where((r) => r.key != 'work'),
        rule('work', morningWork(), to: tue.prev),
        rule(
          'work',
          WorkConfig(
            days: {
              DateTime.tuesday: [const WorkPeriod(12 * 60, 20 * 60)],
            },
          ),
          from: tue,
          to: tue,
        ),
        rule('work', morningWork(), from: tue.next),
      ];
      final after = ScheduleEngine(
        input(rules: shifted, today: tue, logs: logs),
      ).day(tue);
      int startOf(DayPlan p, String k) => p.byKey(k)!.start;
      for (final k in [
        'prayer:fajr',
        'prayer:dhuhr',
        'prayer:asr',
        'class:c',
      ]) {
        expect(startOf(after, k), startOf(before, k), reason: k);
      }
      // المنجز يبقى منجزًا.
      expect(after.byKey('quran:wird')!.status, ItemStatus.done);
      // المشي (مرن) ما يتداخل مع الدوام الجديد.
      final walk = after.byKey('habit:walk');
      if (walk != null) {
        expect(walk.end <= 12 * 60 || walk.start >= 20 * 60, isTrue);
      }
      // تنبيهات الأيام الأخرى ما تتأثر.
      final wed = ScheduleEngine(
        input(rules: shifted, today: tue),
      ).day(tue.next);
      expect(
        wed.items.any((i) => i.kind == ItemKind.work && i.start == 450),
        isTrue,
      );
    },
  );
}
