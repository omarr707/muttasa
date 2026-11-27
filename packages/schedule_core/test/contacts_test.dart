import 'package:schedule_core/schedule_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  const sat = Day(2026, 11, 21); // بداية الأسبوع
  final people = [
    for (var i = 0; i < 6; i++)
      Person(
        id: 'p$i',
        name: 'شخص $i',
        addedAt: const Day(2026, 11, 1),
        freq: ContactFreq.weekly,
        method: i.isEven ? ContactMethod.call : ContactMethod.whatsapp,
      ),
    const Person(
      id: 'pin',
      name: 'أمي',
      pinned: true,
      addedAt: Day(2026, 11, 1),
      freq: ContactFreq.weekly,
    ),
  ];
  const cfg = ContactsConfig(enabled: true, level: ContactLevel.mid);

  EngineInput withContacts({Map<String, ItemLog> logs = const {}}) {
    final base = input(logs: logs);
    return EngineInput(
      profile: base.profile,
      settings: base.settings,
      rules: base.rules,
      logs: logs,
      people: people,
      contacts: cfg,
      prayers: base.prayers,
      today: base.today,
      nowMinute: 0,
    );
  }

  test('٣ اقتراحات بالأسبوع + المثبّت، موزعة على أيام مختلفة', () {
    final e = ScheduleEngine(withContacts());
    final week = e.contactWeek(sat);
    final all = week.values.expand((l) => l).toList();
    expect(all.length, 4);
    expect(all.first.id, 'pin');
    expect(week.keys.toSet().length, 4);
    // كل اقتراح يظهر في خطة يومه داخل نافذة المساء.
    for (final entry in week.entries) {
      final plan = e.day(entry.key);
      for (final p in entry.value) {
        final item = plan.byKey(p.itemKey);
        expect(item, isNotNull);
        expect(item!.kind, ItemKind.contact);
        expect(item.start, greaterThanOrEqualTo(19 * 60));
        expect(item.end, lessThanOrEqualTo(21 * 60));
        expect(item.isExtra, isTrue);
      }
    }
  });

  test('من تواصلت معه الأسبوع الماضي لا يُقترح هذا الأسبوع', () {
    final logs = {
      for (final id in ['p0', 'p1', 'p2'])
        recordKey(const Day(2026, 11, 19), 'contact:$id'): ItemLog(
          date: const Day(2026, 11, 19),
          itemKey: 'contact:$id',
          status: ItemStatus.done,
        ),
    };
    final ids = ScheduleEngine(
      withContacts(logs: logs),
    ).contactWeek(sat).values.expand((l) => l).map((p) => p.id).toSet();
    expect(ids, containsAll(['p3', 'p4', 'p5', 'pin']));
    expect(ids.intersection({'p0', 'p1', 'p2'}), isEmpty);
  });

  test('المناسبة تظهر في يومها مع فكرة هدية', () {
    final base = input();
    final e = ScheduleEngine(
      EngineInput(
        profile: base.profile,
        rules: base.rules,
        people: [
          const Person(
            id: 's',
            name: 'سعد',
            addedAt: Day(2026, 1, 1),
            giftBudget: 200,
            occasions: [
              Occasion(kind: OccasionKind.wedding, month: 11, day: 26),
            ],
          ),
        ],
        contacts: cfg,
        prayers: base.prayers,
        today: base.today,
        nowMinute: 0,
      ),
    );
    final item = e.day(const Day(2026, 11, 26)).byKey('occasion:s:wedding')!;
    expect(item.title, 'هنّئ سعد بالزواج');
    expect(item.subtitle, contains('200'));
  });

  test('صيغة الوقت: الفترة تُكتب مرة واحدة، والأرقام حسب الإعداد', () {
    expect(fmtRange(5 * 60 + 19, 5 * 60 + 39), '5:19 – 5:39 ص');
    expect(fmtRange(11 * 60 + 48, 12 * 60 + 33), '11:48 ص – 12:33 م');
    useArabicDigits = true;
    expect(fmtRange(5 * 60 + 19, 5 * 60 + 39), '٥:١٩ – ٥:٣٩ ص');
    expect(fmtCount(2, 8), '٢ من ٨');
    useArabicDigits = false;
  });

  EngineInput withCfg(ContactsConfig c) {
    final base = withContacts();
    return EngineInput(
      profile: base.profile,
      settings: base.settings,
      rules: base.rules,
      logs: const {},
      people: people,
      contacts: c,
      prayers: base.prayers,
      today: base.today,
      nowMinute: 0,
    );
  }

  test('أيام بدون اقتراحات ما ينحط فيها تواصل', () {
    final e = ScheduleEngine(
      withCfg(
        const ContactsConfig(
          enabled: true,
          level: ContactLevel.high,
          excludedDays: {DateTime.thursday, DateTime.friday},
        ),
      ),
    );
    final week = e.contactWeek(sat);
    expect(week, isNotEmpty);
    for (final d in week.keys) {
      expect(d.weekday, isNot(anyOf(DateTime.thursday, DateTime.friday)));
    }
  });

  test('طلعة العائلة تنحجز يوم الجمعة داخل فترتها', () {
    final c = cfg.withOuting(
      cfg.outing(OutingKind.family).copyWith(enabled: true, everyWeeks: 1),
    );
    final e = ScheduleEngine(withCfg(c));
    for (var k = 0; k < 7; k++) {
      final d = sat.add(k);
      final item = e.day(d).byKey('outing:family');
      if (d.weekday == DateTime.friday) {
        expect(item, isNotNull);
        expect(item!.start, greaterThanOrEqualTo(16 * 60 + 30));
        expect(item.end, lessThanOrEqualTo(21 * 60));
      } else {
        expect(item, isNull);
      }
    }
  });

  test('نزحزح اللي بعده: العناصر المرنة اللاحقة تنزاح بدون تداخل', () {
    final e = ScheduleEngine(withContacts());
    final plan = e.day(const Day(2026, 11, 27));
    final movable = plan.items.where(isMovable).toList();
    expect(movable, isNotEmpty);
    final first = movable.first;
    final to = first.start + 45;
    final r = reflowAfter(plan, first, to);
    for (final entry in r.moves.entries) {
      final it = plan.byKey(entry.key)!;
      expect(entry.value, greaterThanOrEqualTo(it.start));
      // ما يتداخل مع العنصر بعد نقله.
      final end = entry.value + it.duration;
      expect(end <= to || entry.value >= to + first.duration, isTrue);
    }
  });
}
