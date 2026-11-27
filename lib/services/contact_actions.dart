import 'package:schedule_core/schedule_core.dart';
import 'package:url_launcher/url_launcher.dart';

/// يفتح الاتصال أو الرسالة. لا يرسل شيئًا: المستخدم يضغط إرسال بنفسه.
Future<bool> openContact(
  Person p, {
  required bool call,
  String? draft,
  bool? whatsapp,
}) async {
  final phone = (p.phone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
  if (phone.isEmpty) return false;
  final Uri uri;
  if (call) {
    uri = Uri(scheme: 'tel', path: phone);
  } else if (whatsapp ?? p.method == ContactMethod.whatsapp) {
    final digits = phone.replaceAll('+', '');
    uri = Uri.https('wa.me', '/$digits', {'text': ?draft});
  } else {
    uri = Uri.parse(
      'sms:$phone${draft == null ? '' : '?body=${Uri.encodeComponent(draft)}'}',
    );
  }
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
