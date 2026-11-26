import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

/// كل جدول جاهز للمزامنة من اليوم الأول: id، updatedAt، deletedAt (حذف ناعم)، deviceId.
mixin SyncColumns on Table {
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  TextColumn get deviceId => text()();
}

/// قيم مفردة: الملف الشخصي، الإعدادات، وبيانات التشغيل.
class KvEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// القواعد بنسخ مؤرّخة تُضاف ولا تُعدّل.
class RuleRows extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get ruleKey => text()();
  TextColumn get validFrom => text()();
  TextColumn get validTo => text().nullable()();
  TextColumn get json => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class OneOffRows extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get date => text()();
  TextColumn get json => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// «هذه المرة فقط»، بمفتاح (date, itemKey).
class OverrideRows extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get date => text()();
  TextColumn get itemKey => text()();
  TextColumn get json => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CarryRows extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get toDate => text()();
  TextColumn get json => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Occurrence: سجل ما تم، بمفتاح (date, itemKey). مصدر التقارير.
class LogRows extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get date => text()();
  TextColumn get itemKey => text()();
  TextColumn get status => text()();
  TextColumn get category => text().nullable()();
  TextColumn get json => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [KvEntries, RuleRows, OneOffRows, OverrideRows, CarryRows, LogRows],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await m.createIndex(
        Index('log_rows_date', 'CREATE INDEX log_rows_date ON log_rows (date)'),
      );
    },
  );

  /// يفتح القاعدة المشفّرة بمفتاح من Keychain أو Keystore.
  static Future<AppDatabase> openEncrypted(String key) async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'muttasa.sqlite'));
    return AppDatabase(
      NativeDatabase.createInBackground(
        file,
        setup: (db) {
          // SQLite3MultipleCiphers: المفتاح نص سداسي عشوائي.
          db.execute("PRAGMA key = '$key';");
          db.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
  }

  /// للاختبارات ووضع العرض: قاعدة في الذاكرة لا تلمس قاعدة المستخدم.
  static AppDatabase memory() => AppDatabase(NativeDatabase.memory());
}
