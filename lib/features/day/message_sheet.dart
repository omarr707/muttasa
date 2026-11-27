import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../services/contact_actions.dart';
import '../../state/providers.dart';

/// «اختر رسالة»: قوالب حسب العلاقة والمناسبة، تعدّلها بأسلوبك، ثم ترسلها
/// بنفسك من واتساب أو الرسائل أو تنسخها. لا نرسل شيئًا تلقائيًا.
Future<void> showMessageSheet(
  BuildContext context,
  WidgetRef ref,
  PlanItem item,
  Day date,
) {
  final person = ref
      .read(appDataProvider)
      .people
      .where((p) => p.id == item.personId)
      .firstOrNull;
  if (person == null) {
    toast(context, 'ما لقينا الشخص. أضفه من الإعدادات › التواصل');
    return Future.value();
  }
  final data = ref.read(appDataProvider);
  var occasion = person.occasions.where((o) => o.on(date)).firstOrNull?.kind;
  if (occasion == null && item.title.startsWith('هنّئ')) {
    // تهنئة مربوطة بمناسبة: نستنتج نوعها من عنوان المناسبة الأب.
    final parentKey = data.oneOffs
        .where((o) => o.itemKey == item.key)
        .firstOrNull
        ?.parent;
    final parent = data.oneOffs
        .where((o) => o.itemKey == parentKey)
        .firstOrNull
        ?.title;
    occasion = parent != null && RegExp('زواج|عرس|ملكة').hasMatch(parent)
        ? OccasionKind.wedding
        : OccasionKind.other;
  }
  return showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _MessageSheet(
        person: person,
        item: item,
        date: date,
        occasion: occasion,
      ),
    ),
  );
}

class _MessageSheet extends ConsumerStatefulWidget {
  const _MessageSheet({
    required this.person,
    required this.item,
    required this.date,
    this.occasion,
  });
  final Person person;
  final PlanItem item;
  final Day date;
  final OccasionKind? occasion;
  @override
  ConsumerState<_MessageSheet> createState() => _MessageSheetState();
}

class _MessageSheetState extends ConsumerState<_MessageSheet> {
  late final List<String> _templates = messageTemplates(
    widget.person,
    widget.item.start,
    occasion: widget.occasion,
  );
  late int _picked = 0;
  late final _text = TextEditingController(text: _templates.first);
  bool _sent = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _open({required bool whatsapp}) async {
    final ok = await openContact(
      widget.person,
      call: false,
      draft: _text.text.trim(),
      whatsapp: whatsapp,
    );
    if (!mounted) return;
    if (!ok) {
      toast(context, 'أضف رقم ${widget.person.name} من الإعدادات');
      return;
    }
    setState(() => _sent = true);
  }

  Future<void> _done() async {
    await ref.read(appDataProvider.notifier).markDone(widget.date, widget.item);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = widget.person;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              widget.occasion == null ? 'رسالة لـ${p.name}' : 'هنّئ ${p.name}',
            ),
            Text(
              'اختر رسالة وعدّلها بأسلوبك. التطبيق ما يرسل شي بنفسه.',
              style: T.meta.copyWith(color: c.muted),
            ),
            const SizedBox(height: 10),
            for (var k = 0; k < _templates.length; k++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: _picked == k ? c.accentSoft : c.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(R.md),
                    side: BorderSide(color: _picked == k ? c.accent : c.line),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(R.md),
                    onTap: () => setState(() {
                      _picked = k;
                      _text.text = _templates[k];
                    }),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_templates[k], style: T.body),
                    ),
                  ),
                ),
              ),
            const FieldLabel('رسالتك'),
            TextField(controller: _text, minLines: 2, maxLines: 4),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: 'واتساب',
                    icon: Icons.chat_outlined,
                    soft: true,
                    onPressed: () => _open(whatsapp: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PillButton(
                    label: 'الرسائل',
                    icon: Icons.sms_outlined,
                    soft: true,
                    onPressed: () => _open(whatsapp: false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PillButton(
                    label: 'انسخ',
                    icon: Icons.copy,
                    soft: true,
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: _text.text.trim()),
                      );
                      if (!mounted) return;
                      setState(() => _sent = true);
                      toast(this.context, 'نسخنا الرسالة. أرسلها من أي تطبيق');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: _sent ? 'أرسلتها، سجّل «تمّ»' : 'تمّ',
              onPressed: _done,
            ),
          ],
        ),
      ),
    );
  }
}
