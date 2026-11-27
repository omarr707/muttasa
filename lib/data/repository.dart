import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:schedule_core/schedule_core.dart';

import 'database.dart';

/// كل بيانات المستخدم في الذاكرة. صغيرة في المرحلة الأولى (قواعد + سجلات).
class AppData {
  const AppData({
    this.profile,
    this.settings = const AppSettings(),
    this.rules = const [],
    this.oneOffs = const [],
    this.overrides = const {},
    this.carries = const [],
    this.logs = const {},
    this.meta = const {},
    this.people = const [],
    this.contacts = const ContactsConfig(),
  });

  final UserProfile? profile;
  final AppSettings settings;
  final List<Rule> rules;
  final List<OneOff> oneOffs;
  final Map<String, DayOverride> overrides;
  final List<CarryOver> carries;
  final Map<String, ItemLog> logs;
  final Map<String, String> meta;
  final List<Person> people;
  final ContactsConfig contacts;

  bool get onboarded => profile != null;

  AppData copyWith({
    UserProfile? profile,
    AppSettings? settings,
    List<Rule>? rules,
    List<OneOff>? oneOffs,
    Map<String, DayOverride>? overrides,
    List<CarryOver>? carries,
    Map<String, ItemLog>? logs,
    Map<String, String>? meta,
    List<Person>? people,
    ContactsConfig? contacts,
  }) => AppData(
    profile: profile ?? this.profile,
    settings: settings ?? this.settings,
    rules: rules ?? this.rules,
    oneOffs: oneOffs ?? this.oneOffs,
    overrides: overrides ?? this.overrides,
    carries: carries ?? this.carries,
    logs: logs ?? this.logs,
    meta: meta ?? this.meta,
    people: people ?? this.people,
    contacts: contacts ?? this.contacts,
  );
}

/// رقم إصدار مخطط النسخة الاحتياطية.
const backupSchemaVersion = 1;

/// طبقة البيانات: جداول Drift، والتحويل إلى كيانات المحرك.
class Repository {
  Repository(this.db, this.deviceId);

  final AppDatabase db;
  final String deviceId;

  int get _now => DateTime.now().millisecondsSinceEpoch;

  Map<String, Object?> _decode(String s) =>
      (jsonDecode(s) as Map).cast<String, Object?>();

  Future<AppData> loadAll() async {
    final kv = {
      for (final r in await db.select(db.kvEntries).get()) r.key: r.value,
    };
    final rules =
        (await (db.select(
              db.ruleRows,
            )..where((t) => t.deletedAt.isNull())).get())
            .map((r) => Rule.fromJson(_decode(r.json)))
            .toList();
    final oneOffs =
        (await (db.select(
              db.oneOffRows,
            )..where((t) => t.deletedAt.isNull())).get())
            .map((r) => OneOff.fromJson(_decode(r.json)))
            .toList();
    final overrides = {
      for (final r in await (db.select(
        db.overrideRows,
      )..where((t) => t.deletedAt.isNull())).get())
        r.id: DayOverride.fromJson(_decode(r.json)),
    };
    final carries =
        (await (db.select(
              db.carryRows,
            )..where((t) => t.deletedAt.isNull())).get())
            .map((r) => CarryOver.fromJson(_decode(r.json)))
            .toList();
    final logs = {
      for (final r in await (db.select(
        db.logRows,
      )..where((t) => t.deletedAt.isNull())).get())
        r.id: ItemLog.fromJson(_decode(r.json)),
    };
    return AppData(
      profile: kv['profile'] == null
          ? null
          : UserProfile.fromJson(_decode(kv['profile']!)),
      settings: kv['settings'] == null
          ? const AppSettings()
          : AppSettings.fromJson(_decode(kv['settings']!)),
      rules: rules,
      oneOffs: oneOffs,
      overrides: overrides,
      carries: carries,
      logs: logs,
      meta: {
        for (final e in kv.entries)
          if (e.key.startsWith('meta.')) e.key.substring(5): e.value,
      },
      people: kv['people'] == null
          ? const []
          : _people(jsonDecode(kv['people']!) as List),
      contacts: kv['contacts'] == null
          ? const ContactsConfig()
          : ContactsConfig.fromJson(_decode(kv['contacts']!)),
    );
  }

  static List<Person> _people(List l) => l
      .map((e) => Person.fromJson((e as Map).cast<String, Object?>()))
      .toList();

  Future<void> savePeople(List<Person> p) =>
      setKv('people', jsonEncode(p.map((e) => e.toJson()).toList()));
  Future<void> saveContacts(ContactsConfig c) =>
      setKv('contacts', jsonEncode(c.toJson()));

  Future<void> setKv(String key, String value) => db
      .into(db.kvEntries)
      .insertOnConflictUpdate(
        KvEntriesCompanion.insert(key: key, value: value, updatedAt: _now),
      );

  Future<void> saveProfile(UserProfile p) =>
      setKv('profile', jsonEncode(p.toJson()));
  Future<void> saveSettings(AppSettings s) =>
      setKv('settings', jsonEncode(s.toJson()));
  Future<void> setMeta(String key, String value) => setKv('meta.$key', value);

  Future<void> upsertRule(Rule r) => db
      .into(db.ruleRows)
      .insertOnConflictUpdate(
        RuleRowsCompanion.insert(
          id: r.id,
          ruleKey: r.key,
          validFrom: r.validFrom.key,
          validTo: Value(r.validTo?.key),
          json: jsonEncode(r.toJson()),
          updatedAt: _now,
          deviceId: deviceId,
        ),
      );

  Future<void> deleteRule(String id) =>
      (db.update(db.ruleRows)..where((t) => t.id.equals(id))).write(
        RuleRowsCompanion(deletedAt: Value(_now), updatedAt: Value(_now)),
      );

  Future<void> upsertOneOff(OneOff o) => db
      .into(db.oneOffRows)
      .insertOnConflictUpdate(
        OneOffRowsCompanion.insert(
          id: o.id,
          date: o.date.key,
          json: jsonEncode(o.toJson()),
          updatedAt: _now,
          deviceId: deviceId,
        ),
      );

  Future<void> deleteOneOff(String id) =>
      (db.update(db.oneOffRows)..where((t) => t.id.equals(id))).write(
        OneOffRowsCompanion(deletedAt: Value(_now), updatedAt: Value(_now)),
      );

  Future<void> upsertOverride(DayOverride o) => db
      .into(db.overrideRows)
      .insertOnConflictUpdate(
        OverrideRowsCompanion.insert(
          id: recordKey(o.date, o.itemKey),
          date: o.date.key,
          itemKey: o.itemKey,
          json: jsonEncode(o.toJson()),
          updatedAt: _now,
          deletedAt: const Value(null),
          deviceId: deviceId,
        ),
      );

  Future<void> deleteOverride(Day date, String itemKey) =>
      (db.update(
        db.overrideRows,
      )..where((t) => t.id.equals(recordKey(date, itemKey)))).write(
        OverrideRowsCompanion(deletedAt: Value(_now), updatedAt: Value(_now)),
      );

  Future<void> upsertCarry(CarryOver c) => db
      .into(db.carryRows)
      .insertOnConflictUpdate(
        CarryRowsCompanion.insert(
          id: c.id,
          toDate: c.toDate.key,
          json: jsonEncode(c.toJson()),
          updatedAt: _now,
          deviceId: deviceId,
        ),
      );

  Future<void> deleteCarry(String id) =>
      (db.update(db.carryRows)..where((t) => t.id.equals(id))).write(
        CarryRowsCompanion(deletedAt: Value(_now), updatedAt: Value(_now)),
      );

  /// الكتابة idempotent على (date, itemKey): لا تسجيل مزدوج.
  Future<void> upsertLog(ItemLog l) => db
      .into(db.logRows)
      .insertOnConflictUpdate(
        LogRowsCompanion.insert(
          id: recordKey(l.date, l.itemKey),
          date: l.date.key,
          itemKey: l.itemKey,
          status: l.status.name,
          category: Value(l.category),
          json: jsonEncode(l.toJson()),
          updatedAt: _now,
          deletedAt: const Value(null),
          deviceId: deviceId,
        ),
      );

  Future<void> deleteLog(Day date, String itemKey) =>
      (db.update(
        db.logRows,
      )..where((t) => t.id.equals(recordKey(date, itemKey)))).write(
        LogRowsCompanion(deletedAt: Value(_now), updatedAt: Value(_now)),
      );

  Future<void> batchLogs(Iterable<ItemLog> logs) async {
    await db.transaction(() async {
      for (final l in logs) {
        await upsertLog(l);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // النسخ الاحتياطي: ملف JSON برقم إصدار للمخطط، يشمل كل الجداول.
  // ---------------------------------------------------------------------------

  Map<String, Object?> exportJson(AppData d) => {
    'app': 'muttasa',
    'schemaVersion': backupSchemaVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'profile': d.profile?.toJson(),
    'settings': d.settings.toJson(),
    'rules': d.rules.map((r) => r.toJson()).toList(),
    'oneOffs': d.oneOffs.map((o) => o.toJson()).toList(),
    'overrides': d.overrides.values.map((o) => o.toJson()).toList(),
    'carries': d.carries.map((c) => c.toJson()).toList(),
    'logs': d.logs.values.map((l) => l.toJson()).toList(),
    'meta': d.meta,
    'people': d.people.map((p) => p.toJson()).toList(),
    'contacts': d.contacts.toJson(),
  };

  /// يقرأ النسخة ويتحقق منها دون أن يكتب شيئًا.
  static AppData parseBackup(Map<String, Object?> j) {
    if (j['app'] != 'muttasa') {
      throw const FormatException('الملف ليس نسخة من مُتَّسَع');
    }
    final v = j['schemaVersion'] as int? ?? 0;
    if (v > backupSchemaVersion) {
      throw const FormatException('النسخة من إصدار أحدث من التطبيق');
    }
    List<Map<String, Object?>> list(String k) => ((j[k] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, Object?>())
        .toList();
    final overrides = list('overrides').map(DayOverride.fromJson);
    final logs = list('logs').map(ItemLog.fromJson);
    return AppData(
      profile: j['profile'] == null
          ? null
          : UserProfile.fromJson(
              (j['profile']! as Map).cast<String, Object?>(),
            ),
      settings: j['settings'] == null
          ? const AppSettings()
          : AppSettings.fromJson(
              (j['settings']! as Map).cast<String, Object?>(),
            ),
      rules: list('rules').map(Rule.fromJson).toList(),
      oneOffs: list('oneOffs').map(OneOff.fromJson).toList(),
      overrides: {for (final o in overrides) recordKey(o.date, o.itemKey): o},
      carries: list('carries').map(CarryOver.fromJson).toList(),
      logs: {for (final l in logs) recordKey(l.date, l.itemKey): l},
      meta: ((j['meta'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k as String, v as String),
      ),
      people: _people((j['people'] as List?) ?? const []),
      contacts: j['contacts'] == null
          ? const ContactsConfig()
          : ContactsConfig.fromJson(
              (j['contacts']! as Map).cast<String, Object?>(),
            ),
    );
  }

  /// يستبدل كل شيء بمحتوى النسخة.
  Future<void> replaceAll(AppData d) async {
    await db.transaction(() async {
      await wipe();
      if (d.profile != null) await saveProfile(d.profile!);
      await saveSettings(d.settings);
      await savePeople(d.people);
      await saveContacts(d.contacts);
      for (final e in d.meta.entries) {
        await setMeta(e.key, e.value);
      }
      for (final r in d.rules) {
        await upsertRule(r);
      }
      for (final o in d.oneOffs) {
        await upsertOneOff(o);
      }
      for (final o in d.overrides.values) {
        await upsertOverride(o);
      }
      for (final c in d.carries) {
        await upsertCarry(c);
      }
      for (final l in d.logs.values) {
        await upsertLog(l);
      }
    });
  }

  Future<void> wipe() async {
    await db.transaction(() async {
      for (final t in db.allTables) {
        if (t.actualTableName == 'kv_entries') {
          await (db.delete(
            db.kvEntries,
          )..where((k) => k.key.equals('meta.deviceId').not())).go();
        } else {
          await db.delete(t).go();
        }
      }
    });
  }
}
