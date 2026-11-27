@Tags(['screens'])
library;

import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muttasa/app.dart';
import 'package:muttasa/data/database.dart';
import 'package:muttasa/data/defaults.dart';
import 'package:muttasa/data/library.dart';
import 'package:muttasa/data/repository.dart';
import 'package:muttasa/state/providers.dart';
import 'package:schedule_core/schedule_core.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

class FixedClock extends Clock {
  @override
  DateTime build() => DateTime(2026, 11, 26, 9, 40);

  @override
  void refresh() {}
}

class FridayClock extends FixedClock {
  @override
  DateTime build() => DateTime(2026, 11, 27, 9, 48);
}

/// 29 شعبان 1448: بطاقة «نبدأ جدول رمضان؟».
class RamadanEveClock extends FixedClock {
  @override
  DateTime build() => DateTime(2027, 2, 6, 10, 0);
}

/// ثاني أيام رمضان قبيل الإفطار.
class RamadanClock extends FixedClock {
  @override
  DateTime build() => DateTime(2027, 2, 9, 17, 20);
}

/// أول أيام عيد الفطر 1448.
class EidClock extends FixedClock {
  @override
  DateTime build() => DateTime(2027, 3, 9, 8, 0);
}

Future<void> loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(
        Future.value(ByteData.view(File(f).readAsBytesSync().buffer)),
      );
    }
    await loader.load();
  }

  await load('IBMPlexSansArabic', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/IBMPlexSansArabic-$w.ttf',
  ]);
  await load('ReadexPro', ['assets/fonts/ReadexPro.ttf']);
  // أيقونات Material من حزمة Flutter.
  final sdk = File(
    Platform.resolvedExecutable,
  ).parent.parent.parent.parent.parent.parent.path;
  final icons = File(
    '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) await load('MaterialIcons', [icons.path]);
}

AppData sample() {
  const from = Day(2026, 11, 1);
  Rule lib(String key) => Rule(
    id: key,
    key: key,
    validFrom: from,
    config: libraryEntries.firstWhere((e) => e.key == key).build(),
  );
  const d = Day(2026, 11, 26);
  return AppData(
    profile: UserProfile(
      name: 'عمر',
      country: 'SA',
      city: 'الرياض',
      lat: 24.7136,
      lng: 46.6753,
      timezone: 'Asia/Riyadh',
      joinedAt: DateTime(2026, 11, 1),
    ),
    rules: [
      const Rule(
        id: 'prayers',
        key: 'prayers',
        validFrom: from,
        config: PrayersConfig(sunnah: ['fajr', 'dhuhr', 'maghrib', 'isha']),
      ),
      Rule(
        id: 'quran:wird',
        key: 'quran:wird',
        validFrom: from,
        config:
            (libraryEntries.firstWhere((e) => e.key == 'quran:wird').build()
                    as FlexConfig)
                .copyWith(khatmaBy: const Day(2027, 1, 31)),
      ),
      const Rule(
        id: 'savings',
        key: 'savings',
        validFrom: from,
        config: SavingsConfig(payDay: 27, monthly: 1000, target: 12000),
      ),
      for (final k in [
        'adhkar',
        'meal:breakfast',
        'meal:dinner',
        'habit:walk',
        'habit:read',
        'reminders',
      ])
        lib(k),
      Rule(
        id: 'work',
        key: 'work',
        validFrom: from,
        config: WorkConfig(
          days: {
            for (final wd in [7, 1, 2, 3, 4])
              wd: [const WorkPeriod(450, 960, breakStart: 720, breakEnd: 750)],
          },
        ),
      ),
      const Rule(
        id: 'kid',
        key: 'kid:salma',
        validFrom: from,
        config: KidConfig(
          child: 'سلمى',
          place: 'المدرسة',
          days: {
            7: KidDay(drop: 400),
            1: KidDay(drop: 400),
            2: KidDay(drop: 400),
            3: KidDay(drop: 400),
            4: KidDay(drop: 400),
          },
        ),
      ),
    ],
    logs: {
      ...pastLogs(),
      recordKey(d, 'prayer:fajr'): const ItemLog(
        date: d,
        itemKey: 'prayer:fajr',
        status: ItemStatus.done,
        plannedStart: 293,
        doneAt: 295,
      ),
      recordKey(d, 'adhkar:morning'): const ItemLog(
        date: d,
        itemKey: 'adhkar:morning',
        status: ItemStatus.done,
        plannedStart: 315,
        doneAt: 320,
      ),
      recordKey(d, 'water'): const ItemLog(
        date: d,
        itemKey: 'water',
        status: ItemStatus.pending,
        value: 500,
      ),
    },
    meta: const {
      'lastClosed': '2026-11-25',
      'water.2026-11-26': '330:250,550:250',
    },
    people: const [
      Person(
        id: 'mom',
        name: 'أمي',
        phone: '+966500000000',
        pinned: true,
        freq: ContactFreq.weekly,
        addedAt: Day(2026, 11, 1),
      ),
      Person(
        id: 'khalid',
        name: 'خالد',
        relation: Relation.friend,
        method: ContactMethod.whatsapp,
        addedAt: Day(2026, 11, 1),
      ),
      Person(
        id: 'saad',
        name: 'سعد',
        relation: Relation.friend,
        giftBudget: 200,
        occasions: [Occasion(kind: OccasionKind.wedding, month: 11, day: 26)],
        addedAt: Day(2026, 11, 1),
      ),
      Person(
        id: 'uncle',
        name: 'عمي أبو فهد',
        freq: ContactFreq.monthly,
        addedAt: Day(2026, 11, 1),
      ),
    ],
    contacts: const ContactsConfig(enabled: true),
    goals: const [
      Goal(
        id: 'books',
        title: 'أقرأ 12 كتاب هالسنة',
        metric: GoalMetric.books,
        target: 12,
        start: Day(2026, 11, 1),
        due: Day(2027, 10, 31),
        linkKey: 'habit:read',
        entries: [GoalEntry(Day(2026, 11, 15), 1)],
      ),
      Goal(
        id: 'walk',
        title: 'أمشي 40 مرة',
        metric: GoalMetric.sessions,
        target: 40,
        start: Day(2026, 11, 1),
        due: Day(2027, 1, 31),
        linkKey: 'habit:walk',
      ),
    ],
  );
}

/// سجل أيام نوفمبر الماضية: صلوات بنسب متفاوتة، صفحات، مشي، وادخار.
Map<String, ItemLog> pastLogs() {
  final out = <String, ItemLog>{};
  void put(Day d, String key, {int? v, int? v2}) =>
      out[recordKey(d, key)] = ItemLog(
        date: d,
        itemKey: key,
        status: ItemStatus.done,
        value: v,
        value2: v2,
      );
  var page = 0;
  for (
    var d = const Day(2026, 11, 1);
    d.isBefore(const Day(2026, 11, 26));
    d = d.next
  ) {
    final n = d.day % 5; // تفاوت بين الأيام
    final prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    for (
      var i = 0;
      i <
          5 -
              (n == 0
                  ? 3
                  : n == 3
                  ? 1
                  : 0);
      i++
    ) {
      put(
        d,
        'prayer:${d.weekday == DateTime.friday && prayers[i] == 'dhuhr' ? 'jumuah' : prayers[i]}',
      );
    }
    if (n != 0) {
      put(d, 'adhkar:morning');
      put(d, 'quran:wird', v: page + 1, v2: page + 8);
      page += 8;
    }
    if (d.weekday == DateTime.saturday || d.weekday == DateTime.tuesday) {
      put(d, 'habit:walk');
    }
  }
  out[recordKey(const Day(2026, 11, 1), 'savings:manual:a')] = const ItemLog(
    date: Day(2026, 11, 1),
    itemKey: 'savings:manual:a',
    status: ItemStatus.done,
    value: 1500,
  );
  return out;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() async {
    tzdata.initializeTimeZones();
    await loadFonts();
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    bool friday = false,
    AppData? data,
    FixedClock Function()? clock,
  }) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.view.reset);
    final repo = Repository(AppDatabase.memory(), 'test');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          defaultsProvider.overrideWithValue(
            Defaults.parse(
              File('assets/defaults/config.json').readAsStringSync(),
            ),
          ),
          initialDataProvider.overrideWithValue(data ?? sample()),
          clockProvider.overrideWith(
            clock ?? (friday ? FridayClock.new : FixedClock.new),
          ),
        ],
        child: const MuttasaApp(notifications: false),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('يومي', (tester) async {
    await pumpApp(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/day_top.png'),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -620));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/day_timeline.png'),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/day_timeline2.png'),
    );
  });

  testWidgets('يومي داكن', (tester) async {
    await pumpApp(tester, brightness: Brightness.dark);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -620));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/day_dark.png'),
    );
  });

  testWidgets('روتيني وأهدافي والإضافة', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('إضافة'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/add_sheet.png'),
    );
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();
    await tester.tap(find.text('روتيني'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/routine.png'),
    );
    await tester.tap(find.text('الصلوات'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/routine_tap.png'),
    );
    final edit = find.text('عدّل');
    if (edit.evaluate().isNotEmpty) {
      await tester.tap(edit.first);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/prayers_editor.png'),
      );
    }
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أهدافي'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/goals.png'),
    );
    await tester.tap(find.text('يومي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الإحصائيات'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/stats.png'),
    );
  });

  Future<void> shot(WidgetTester tester, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  testWidgets('الأهداف والتقرير والادخار', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('أهدافي'));
    await tester.pumpAndSettle();
    expect(find.text('ختمة القرآن'), findsOneWidget);
    expect(find.text('الادخار'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pumpAndSettle();
    await shot(tester, 'goals_targets');
    await tester.tap(find.text('+ هدف جديد'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('أدّخر'));
    await tester.pumpAndSettle();
    await shot(tester, 'goal_editor');
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('يومي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الإحصائيات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('شهري'));
    await tester.pumpAndSettle();
    await shot(tester, 'report_month');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await shot(tester, 'report_month2');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('سنوي'));
    await tester.pumpAndSettle();
    await shot(tester, 'report_year');
  });

  testWidgets('بطاقة يوم الراتب', (tester) async {
    await pumpApp(tester);
    // بكرة 27: يوم الراتب.
    final ctx = tester.element(find.byType(CustomScrollView));
    final container = ProviderScope.containerOf(ctx);
    container.read(selectedDayProvider.notifier).set(const Day(2026, 11, 27));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('ادّخر من راتبك'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await shot(tester, 'savings_card');
  });

  testWidgets('فاتت، الماء، البطاقة', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('راجعها').first);
    await tester.pumpAndSettle();
    await shot(tester, 'missed_sheet');
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp(r'^. من .')).first);
    await tester.pumpAndSettle();
    await shot(tester, 'water_sheet');
  });

  testWidgets('الجمعة', (tester) async {
    await pumpApp(tester, friday: true);
    await shot(tester, 'friday_sheet');
    await tester.tap(find.text('أضفها إلى يومي'));
    await tester.pumpAndSettle();
    await shot(tester, 'friday_day');
  });

  testWidgets('الإعدادات والتواصل', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();
    await shot(tester, 'settings');
    await tester.ensureVisible(find.text('المظهر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المظهر'));
    await tester.pumpAndSettle();
    await shot(tester, 'appearance');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('التواصل مع الناس'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('التواصل مع الناس'));
    await tester.pumpAndSettle();
    await shot(tester, 'contacts_settings');
    await tester.tap(find.text('الأشخاص'));
    await tester.pumpAndSettle();
    await shot(tester, 'contacts_people');
    await tester.tap(find.text('خالد'));
    await tester.pumpAndSettle();
    await shot(tester, 'contacts_edit');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('جدول الأسبوع'));
    await tester.pumpAndSettle();
    await shot(tester, 'contacts_week');
  });

  testWidgets('رمضان: البطاقة ثم الجدول', (tester) async {
    await pumpApp(tester, clock: RamadanEveClock.new);
    expect(find.text('رمضان بعد يومين. نجهّز جدول رمضان؟'), findsOneWidget);
    await shot(tester, 'ramadan_prompt');
    await tester.tap(find.text('ابدأ جدول رمضان'));
    await tester.pumpAndSettle();
    expect(find.text('ابدأ جدول رمضان'), findsNothing);
  });

  testWidgets('يوم في رمضان', (tester) async {
    final d = sample();
    await pumpApp(
      tester,
      clock: RamadanClock.new,
      data: d.copyWith(
        settings: d.settings.copyWith(
          season: const SeasonSettings(ramadanYears: {1448: true}),
        ),
      ),
    );
    expect(find.text('رمضان · اليوم ٢'), findsOneWidget);
    await shot(tester, 'ramadan_day');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('صلاة التراويح'), findsOneWidget);
    await shot(tester, 'ramadan_evening');
  });

  testWidgets('العيد', (tester) async {
    await pumpApp(tester, clock: EidClock.new);
    expect(find.text('عيد الفطر مبارك'), findsOneWidget);
    await shot(tester, 'eid_day');
  });

  testWidgets('الأوضاع ورمضان في الإعدادات', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('رمضان والعيد'));
    await tester.pumpAndSettle();
    await shot(tester, 'season_settings');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الإجازة والسفر والإيقاف'));
    await tester.pumpAndSettle();
    await shot(tester, 'modes');
    await tester.tap(find.text('سفر'));
    await tester.pumpAndSettle();
    await shot(tester, 'mode_travel');
  });

  testWidgets('وضع الإجازة في يومي', (tester) async {
    final d = sample();
    await pumpApp(
      tester,
      data: d.copyWith(
        modes: const [
          LifeMode(
            id: 'v',
            kind: ModeKind.vacation,
            from: Day(2026, 11, 25),
            to: Day(2026, 11, 30),
          ),
        ],
      ),
    );
    expect(find.text('إجازة حتى ٣٠ نوفمبر'), findsOneWidget);
    await shot(tester, 'vacation_day');
  });

  testWidgets('مشاركة مشاوير الأولاد', (tester) async {
    final d = sample();
    await pumpApp(
      tester,
      data: d.copyWith(
        partner: const PartnerShare(
          name: 'أم عيسى',
          runs: {'kid:salma:drop': RunAssign(RunWho.partner)},
        ),
      ),
    );
    await tester.tap(find.text('روتيني'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مشاركة مع الزوج/الزوجة'));
    await tester.pumpAndSettle();
    await shot(tester, 'partner');
  });

  testWidgets('التهيئة', (tester) async {
    await pumpApp(tester, data: const AppData());
    await shot(tester, 'onboard_welcome');
    await tester.tap(find.text('ابدأ'));
    await tester.pumpAndSettle();
    await shot(tester, 'onboard_city');
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    await shot(tester, 'onboard_day');
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    await shot(tester, 'onboard_interests');
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    await shot(tester, 'onboard_summary');
  });
}
