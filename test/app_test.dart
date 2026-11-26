import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muttasa/app.dart';
import 'package:muttasa/data/database.dart';
import 'package:muttasa/data/defaults.dart';
import 'package:muttasa/data/repository.dart';
import 'package:muttasa/state/providers.dart';
import 'package:schedule_core/schedule_core.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

Defaults loadDefaults() =>
    Defaults.parse(File('assets/defaults/config.json').readAsStringSync());

UserProfile riyadh() => UserProfile(
  name: 'عمر',
  country: 'SA',
  city: 'الرياض',
  lat: 24.7136,
  lng: 46.6753,
  timezone: 'Asia/Riyadh',
  joinedAt: DateTime(2026, 1, 1),
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(tzdata.initializeTimeZones);

  group('Repository', () {
    test('حفظ وتحميل، والكتابة idempotent على (date, itemKey)', () async {
      final repo = Repository(AppDatabase.memory(), 'test');
      await repo.saveProfile(riyadh());
      final r = const Rule(
        id: 'r1',
        key: 'habit:walk',
        validFrom: Day(2026, 1, 1),
        config: FlexConfig(kind: RuleKind.habit, title: 'المشي', duration: 30),
      );
      await repo.upsertRule(r);
      const d = Day(2026, 11, 26);
      await repo.upsertLog(
        const ItemLog(
          date: d,
          itemKey: 'habit:walk',
          status: ItemStatus.pending,
        ),
      );
      await repo.upsertLog(
        const ItemLog(
          date: d,
          itemKey: 'habit:walk',
          status: ItemStatus.done,
          doneAt: 600,
        ),
      );
      final data = await repo.loadAll();
      expect(data.profile!.city, 'الرياض');
      expect(data.rules.single.key, 'habit:walk');
      expect(data.logs.length, 1);
      expect(data.logs.values.single.status, ItemStatus.done);
      await repo.deleteRule('r1');
      expect((await repo.loadAll()).rules, isEmpty);
    });

    test('النسخ الاحتياطي: تصدير ثم استيراد يعيد كل شيء', () async {
      final repo = Repository(AppDatabase.memory(), 'test');
      final data = AppData(
        profile: riyadh(),
        rules: [
          const Rule(
            id: 'r1',
            key: 'prayers',
            validFrom: Day(2026, 1, 1),
            config: PrayersConfig(),
          ),
        ],
        logs: {
          recordKey(const Day(2026, 11, 25), 'prayer:fajr'): const ItemLog(
            date: Day(2026, 11, 25),
            itemKey: 'prayer:fajr',
            status: ItemStatus.done,
          ),
        },
      );
      final json = repo.exportJson(data);
      final parsed = Repository.parseBackup(json);
      await repo.replaceAll(parsed);
      final back = await repo.loadAll();
      expect(back.profile!.name, 'عمر');
      expect(back.rules.single.config, isA<PrayersConfig>());
      expect(back.logs.length, 1);
      expect(
        () => Repository.parseBackup({'app': 'other'}),
        throwsFormatException,
      );
    });
  });

  testWidgets('التهيئة ثم «يومي» يعرض الصلوات والإنجاز', (tester) async {
    final repo = Repository(AppDatabase.memory(), 'test');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          defaultsProvider.overrideWithValue(loadDefaults()),
          initialDataProvider.overrideWithValue(const AppData()),
        ],
        child: const MuttasaApp(notifications: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('مُتَّسَع'), findsOneWidget);
    await tester.tap(find.text('ابدأ'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'عمر');
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('السعودية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('الإسلام'), findsOneWidget);
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('تشكيلتي'), findsOneWidget);
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('جهّز جدولي'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    // نافذة إذن التنبيهات تظهر قبل الانتقال.
    await tester.tap(find.text('لاحقًا'));
    await tester.pumpAndSettle();

    expect(find.text('إنجاز اليوم'), findsOneWidget);
    expect(find.text('يومي'), findsOneWidget);
    final data = await repo.loadAll();
    expect(data.profile!.city, 'الرياض');
    expect(
      data.rules.map((r) => r.key),
      containsAll(['prayers', 'adhkar', 'quran:wird', 'reminders']),
    );

    // «روتيني» و«أهدافي» تفتح.
    await tester.tap(find.text('روتيني'));
    await tester.pumpAndSettle();
    expect(find.text('مواعيدك الثابتة'), findsOneWidget);
    await tester.tap(find.text('أهدافي'));
    await tester.pumpAndSettle();
    expect(find.text('العادات'), findsOneWidget);
    expect(find.text('المشي'), findsOneWidget);
  });
}
