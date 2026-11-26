import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:schedule_core/schedule_core.dart';
import 'package:share_plus/share_plus.dart';

import '../data/repository.dart';

/// النسخ الاحتياطي: تصدير واستيراد ملف JSON برقم إصدار للمخطط عبر share_plus.
class BackupService {
  static Future<void> export(Map<String, Object?> json, Day today) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'muttasa-${today.key}.json'));
    await file.writeAsString(const JsonEncoder.withIndent(' ').convert(json));
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'نسخة مُتَّسَع ${today.key}',
      ),
    );
  }

  /// يقرأ الملف ويتحقق منه، ولا يكتب شيئًا. null عند الإلغاء.
  static Future<AppData?> pick() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (files.isEmpty) return null;
    final raw = await files.first.xFile.readAsString();
    return Repository.parseBackup(
      (jsonDecode(raw) as Map).cast<String, Object?>(),
    );
  }

  /// ملخص يُعرض قبل الاستبدال.
  static String summary(AppData d) {
    final days = d.logs.values.map((l) => l.date).toSet();
    final sorted = days.toList()..sort();
    final span = sorted.isEmpty
        ? 'بدون سجلات'
        : 'سجلات ${sorted.length} يوم، من ${sorted.first.key} إلى ${sorted.last.key}';
    return [
      if (d.profile != null)
        'الاسم: ${d.profile!.name.isEmpty ? '—' : d.profile!.name} · ${d.profile!.city}',
      'القواعد: ${d.rules.length}',
      'الإضافات: ${d.oneOffs.length}',
      span,
    ].join('\n');
  }
}
