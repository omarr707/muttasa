import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import 'app.dart';
import 'data/database.dart';
import 'data/defaults.dart';
import 'data/repository.dart';
import 'services/notifications.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  try {
    final local = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(local.identifier));
  } catch (_) {
    // نبقى على UTC إن تعذّر، والجدول نفسه يعتمد على ساعة الجهاز.
  }

  final defaults = await Defaults.load();
  final db = await AppDatabase.openEncrypted(await _databaseKey());
  final deviceId = await _deviceId(db);
  final repo = Repository(db, deviceId);
  final data = await repo.loadAll();
  await NotificationService.instance.init();

  runApp(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        defaultsProvider.overrideWithValue(defaults),
        initialDataProvider.overrideWithValue(data),
      ],
      child: const MuttasaApp(),
    ),
  );
}

/// المفتاح يُولّد عشوائيًا ويُحفظ في Keychain أو Keystore.
Future<String> _databaseKey() async {
  const storage = FlutterSecureStorage();
  const name = 'muttasa.db.key';
  final existing = await storage.read(key: name);
  if (existing != null) return existing;
  final r = Random.secure();
  final key = List.generate(
    32,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  await storage.write(key: name, value: key);
  return key;
}

Future<String> _deviceId(AppDatabase db) async {
  final row = await (db.select(
    db.kvEntries,
  )..where((t) => t.key.equals('meta.deviceId'))).getSingleOrNull();
  if (row != null) return row.value;
  final id = const Uuid().v4();
  await db
      .into(db.kvEntries)
      .insert(
        KvEntriesCompanion.insert(
          key: 'meta.deviceId',
          value: id,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
  return id;
}
