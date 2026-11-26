import 'dart:math';

import 'package:schedule_core/schedule_core.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

/// خصائص تُفحص على آلاف الأيام العشوائية.
void main() {
  final rnd = Random(1448);

  List<Rule> randomRules() {
    final rules = <Rule>[...basicRules.where((_) => rnd.nextBool() || true)];
    if (rnd.nextBool()) {
      final start = 360 + rnd.nextInt(8) * 30;
      final end = start + 240 + rnd.nextInt(8) * 30;
      final hasBreak = rnd.nextBool();
      rules.add(rule(
        'work',
        WorkConfig(days: {
          for (final d in [7, 1, 2, 3, 4])
            if (rnd.nextInt(5) > 0)
              d: [WorkPeriod(start, end, breakStart: hasBreak ? start + 180 : null, breakEnd: hasBreak ? start + 210 : null)],
        }),
      ));
    }
    if (rnd.nextBool()) {
      rules.add(rule(
        'work',
        WorkConfig(days: {DateTime.wednesday: [const WorkPeriod(22 * 60, 6 * 60)]}),
      ));
    }
    for (var i = 0; i < rnd.nextInt(6); i++) {
      rules.add(rule(
        'habit:r$i',
        FlexConfig(
          kind: RuleKind.habit,
          title: 'عادة $i',
          duration: 10 + rnd.nextInt(10) * 10,
          windows: [Window.values[rnd.nextInt(Window.values.length)]],
          recurrence: rnd.nextBool() ? const Daily() : TimesPerWeek(1 + rnd.nextInt(6)),
          perDay: 1 + rnd.nextInt(2),
          optional: rnd.nextBool(),
          preferred: rnd.nextBool() ? 300 + rnd.nextInt(200) * 5 : null,
        ),
      ));
    }
    if (rnd.nextBool()) {
      rules.add(rule(
        'kid:k',
        KidConfig(child: 'ولد', days: {for (final d in [7, 1, 2, 3, 4]) d: KidDay(drop: 400 + rnd.nextInt(10) * 5, pick: 760 + rnd.nextInt(20) * 5)}),
      ));
    }
    return rules;
  }

  test('خصائص المحرك على أيام عشوائية', () {
    var days = 0;
    for (var trial = 0; trial < 60; trial++) {
      final rules = randomRules();
      final wake = 240 + rnd.nextInt(12) * 15;
      final sleep = 1260 + rnd.nextInt(10) * 15;
      final inp = input(profile: riyadh(wake: wake, sleep: sleep), rules: rules);
      final engine = ScheduleEngine(inp);
      final engine2 = ScheduleEngine(inp);
      final start = Day(2026, 1 + rnd.nextInt(12), 1 + rnd.nextInt(27));
      for (var k = 0; k < 20; k++) {
        final d = start.add(k);
        final plan = engine.day(d);
        days++;
        final flex = plan.items.where((i) => !i.fixed).toList();

        // لا يتداخل عنصران موضوعان من المحرك.
        for (var i = 0; i < flex.length; i++) {
          for (var j = i + 1; j < flex.length; j++) {
            expect(flex[i].span.overlaps(flex[j].span), isFalse, reason: '$d ${flex[i]} ${flex[j]}');
          }
        }
        // لا شيء مرن داخل النوم المحجوز أو الدوام خارج الاستراحة أو على ثابت.
        for (final f in flex) {
          for (final b in plan.busy.where((b) => b.kind != BusyKind.flex)) {
            expect(f.span.overlaps(b.span), isFalse, reason: '$d $f vs ${b.label} ${b.span}');
          }
        }
        // مجموع الوقت الاختياري لا يتجاوز الحد اليومي.
        final optional = flex.where((i) => i.optional).fold<int>(0, (a, i) => a + i.duration);
        expect(optional, lessThanOrEqualTo(180));

        // الثابت في وقته المحدد دائمًا.
        final pr = plan.prayers;
        final fajr = plan.byKey('prayer:fajr');
        if (fajr != null) expect(fajr.start, pr.fajr);

        // التوليد مرتين بنفس المدخلات يعطي نفس النتيجة.
        final again = engine2.day(d);
        expect(again.items.map((i) => '${i.key}@${i.start}').toList(), plan.items.map((i) => '${i.key}@${i.start}').toList());
      }
    }
    expect(days, 1200);
  });

  test('كل تعديل يدوي باقٍ بعد تغيير أي قاعدة أخرى', () {
    for (var trial = 0; trial < 40; trial++) {
      final rules = randomRules();
      final d = Day(2026, 1 + rnd.nextInt(12), 1 + rnd.nextInt(27));
      final engine = ScheduleEngine(input(rules: rules));
      final plan = engine.day(d);
      final flex = plan.items.where((i) => !i.fixed).toList();
      if (flex.isEmpty) continue;
      final target = flex[rnd.nextInt(flex.length)];
      final newStart = nearestFree(plan, target, 600 + rnd.nextInt(60) * 5) ?? target.start;
      final ov = {recordKey(d, target.key): DayOverride(date: d, itemKey: target.key, start: newStart)};
      // تغيير قاعدة أخرى: إضافة عادة جديدة طويلة.
      final changed = [
        ...rules,
        rule('habit:new', const FlexConfig(kind: RuleKind.habit, title: 'جديدة', duration: 90, windows: [Window.any])),
      ];
      final after = ScheduleEngine(input(rules: changed, overrides: ov)).day(d);
      expect(after.byKey(target.key)!.start, newStart, reason: target.key);
    }
  });
}
