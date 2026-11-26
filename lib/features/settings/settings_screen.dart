import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/defaults.dart';
import '../../services/backup.dart';
import '../../services/notifications.dart';
import '../../state/providers.dart';

/// «الإعدادات»: كيف يشتغل التطبيق. لا شيء يُضبط في مكانين.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final data = ref.watch(appDataProvider);
    final p = data.profile;
    if (p == null) return const SizedBox.shrink();
    final s = data.settings;
    final ctrl = ref.read(appDataProvider.notifier);
    final defaults = ref.watch(defaultsProvider);
    final country = defaults.country(p.country);

    Widget group(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title),
          MCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: children),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          children: [
            group('حسابي', [
              ListTile(
                title: const Text('الاسم'),
                subtitle: Text(p.name.isEmpty ? 'بدون اسم' : p.name),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () async {
                  final name = await _askText(context, 'الاسم', p.name);
                  if (name != null) {
                    await ctrl.updateProfile(p.copyWith(name: name));
                  }
                },
              ),
              ListTile(
                title: const Text('الدولة والمدينة'),
                subtitle: Text('${country.name} · ${p.city}'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => _pickCity(context, ref, defaults, p),
              ),
              ListTile(
                title: const Text('الصحيان والنوم'),
                subtitle: Text('${fmtTime(p.wake)} · ${fmtTime(p.sleep)}'),
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  final w = await pickTime(
                    context,
                    initial: p.wake,
                    title: 'وقت الصحيان',
                  );
                  if (w == null || !context.mounted) return;
                  final sl = await pickTime(
                    context,
                    initial: p.sleep,
                    title: 'وقت النوم',
                  );
                  if (sl != null) {
                    await ctrl.updateProfile(p.copyWith(wake: w, sleep: sl));
                  }
                },
              ),
            ]),
            group('الإسلام', [
              SwitchListTile(
                title: const Text('المحتوى الديني'),
                subtitle: const Text('الصلوات والأذكار والورد والتاريخ الهجري'),
                value: p.islam,
                onChanged: (v) => ctrl.updateProfile(
                  p.copyWith(religion: v ? Religion.islam : Religion.none),
                ),
              ),
              if (p.islam) ...[
                ListTile(
                  title: const Text('طريقة حساب المواقيت'),
                  subtitle: Text(p.calcMethod.label),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () async {
                    final m = await showModalBottomSheet<CalcMethod>(
                      useRootNavigator: true,
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final m in CalcMethod.values)
                              ListTile(
                                title: Text(m.label),
                                trailing: m == p.calcMethod
                                    ? const Icon(Icons.check)
                                    : null,
                                onTap: () => Navigator.pop(ctx, m),
                              ),
                          ],
                        ),
                      ),
                    );
                    if (m != null) {
                      await ctrl.updateProfile(p.copyWith(calcMethod: m));
                    }
                  },
                ),
                ListTile(
                  title: const Text('إزاحة التاريخ الهجري'),
                  subtitle: const Text('بداية الشهر تعتمد على الرؤية'),
                  trailing: Segmented<int>(
                    small: true,
                    values: const [-1, 0, 1],
                    labels: const ['-1', '0', '+1'],
                    selected: p.hijriOffset,
                    onChanged: (v) =>
                        ctrl.updateProfile(p.copyWith(hijriOffset: v)),
                  ),
                ),
              ],
            ]),
            group('التنبيهات', [
              for (final k in NotifyKind.values)
                SwitchListTile(
                  title: Text(k.label),
                  subtitle: Text(switch (k) {
                    NotifyKind.prayer =>
                      'في وقتها، ولا تتأثر بأوقات الهدوء ولا بالحد',
                    NotifyKind.water => 'في وقتها',
                    _ => 'قبلها بـ ${s.leadMinutes} دقائق',
                  }),
                  value: s.notifyEnabled.contains(k),
                  onChanged: (v) => ctrl.updateSettings(
                    s.copyWith(
                      notifyEnabled: v
                          ? {...s.notifyEnabled, k}
                          : ({...s.notifyEnabled}..remove(k)),
                    ),
                  ),
                ),
              ListTile(
                title: const Text('قبل الموعد بـ'),
                trailing: DropdownButton<int>(
                  value: s.leadMinutes,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final v in const [0, 5, 10, 15, 30])
                      DropdownMenuItem(
                        value: v,
                        child: Text(v == 0 ? 'في وقته' : '$v دقائق'),
                      ),
                  ],
                  onChanged: (v) =>
                      ctrl.updateSettings(s.copyWith(leadMinutes: v)),
                ),
              ),
              ListTile(
                title: const Text('أوقات الهدوء'),
                subtitle: Text(
                  'من ${fmtTime(s.quietStart)} إلى ${fmtTime(s.quietEnd)}',
                ),
                trailing: const Icon(Icons.nights_stay_outlined),
                onTap: () async {
                  final a = await pickTime(
                    context,
                    initial: s.quietStart,
                    title: 'بداية الهدوء',
                  );
                  if (a == null || !context.mounted) return;
                  final b = await pickTime(
                    context,
                    initial: s.quietEnd,
                    title: 'نهاية الهدوء',
                  );
                  if (b != null) {
                    await ctrl.updateSettings(
                      s.copyWith(quietStart: a, quietEnd: b),
                    );
                  }
                },
              ),
              ListTile(
                title: const Text('الحد اليومي'),
                subtitle: const Text('الزائد يُسقط بحسب الأولوية ثم الوقت'),
                trailing: DropdownButton<int>(
                  value: s.dailyCap,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final v in const [6, 8, 12, 16, 24])
                      DropdownMenuItem(value: v, child: Text('$v')),
                  ],
                  onChanged: (v) =>
                      ctrl.updateSettings(s.copyWith(dailyCap: v)),
                ),
              ),
              SwitchListTile(
                title: const Text('«راجع يومك» قبل النوم'),
                value: s.eveningReview,
                onChanged: (v) =>
                    ctrl.updateSettings(s.copyWith(eveningReview: v)),
              ),
              ListTile(
                title: const Text('تنبيهات اليوم'),
                subtitle: const Text('معاينة ما يُرسل وما أُسقط مع السبب'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => _previewNotifications(context, ref),
              ),
              ListTile(
                title: const Text('إذن التنبيهات'),
                trailing: const Icon(Icons.notifications_active_outlined),
                onTap: () async {
                  final ok = await NotificationService.instance
                      .requestPermissions();
                  if (context.mounted) {
                    toast(
                      context,
                      ok
                          ? 'التنبيهات مفعّلة'
                          : 'الإذن مرفوض. فعّله من إعدادات الجهاز.',
                    );
                  }
                },
              ),
            ]),
            group('الوقت الاختياري', [
              ListTile(
                title: const Text('الحد اليومي للعادات الاختيارية'),
                subtitle: const Text('حتى لا يزدحم يومك. الأقل أفضل من الحشو.'),
                trailing: DropdownButton<int>(
                  value: s.optionalCapMinutes,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final v in const [60, 120, 180, 240, 300])
                      DropdownMenuItem(value: v, child: Text(fmtDuration(v))),
                  ],
                  onChanged: (v) =>
                      ctrl.updateSettings(s.copyWith(optionalCapMinutes: v)),
                ),
              ),
            ]),
            group('النسخ الاحتياطي', [
              ListTile(
                leading: const Icon(Icons.ios_share),
                title: const Text('صدّر نسخة'),
                subtitle: const Text(
                  'ملف JSON فيه كل بياناتك. احفظه في مكان آمن.',
                ),
                onTap: () => BackupService.export(
                  ctrl.exportBackup(),
                  ref.read(todayProvider),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('استرجع من نسخة'),
                subtitle: const Text('نعرض ملخصها قبل الاستبدال'),
                onTap: () => _import(context, ref),
              ),
            ]),
            group('عن التطبيق', [
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('الخصوصية'),
                subtitle: Text(
                  'بياناتك على جهازك فقط، في قاعدة مشفّرة. لا حساب ولا خادم في هذه المرحلة.',
                  style: TextStyle(color: c.ink2),
                ),
              ),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('مُتَّسَع'),
                subtitle: Text('الإصدار 0.1.0 · المرحلة الأولى'),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: Colors.red.shade400,
                ),
                title: Text(
                  'ابدأ من جديد',
                  style: TextStyle(color: Colors.red.shade400),
                ),
                subtitle: const Text('يحذف كل البيانات من هذا الجهاز'),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('نحذف كل شيء؟'),
                      content: const Text(
                        'روتينك وسجلاتك تنحذف من هذا الجهاز. صدّر نسخة قبل إذا تبغى.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('إلغاء'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('احذف'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ctrl.resetAll();
                    if (context.mounted) context.go('/onboarding');
                  }
                },
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<String?> _askText(BuildContext context, String title, String initial) {
    final ctl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: const Text('احفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCity(
    BuildContext context,
    WidgetRef ref,
    Defaults defaults,
    UserProfile p,
  ) async {
    final picked = await showModalBottomSheet<(Country, City)>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * .8,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final co in defaults.countries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    co.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                for (final ci in co.cities)
                  ListTile(
                    title: Text(ci.name),
                    trailing: ci.name == p.city
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(ctx, (co, ci)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    final (co, ci) = picked;
    await ref
        .read(appDataProvider.notifier)
        .updateProfile(
          p.copyWith(
            country: co.code,
            city: ci.name,
            lat: ci.lat,
            lng: ci.lng,
            timezone: ci.tz,
            calcMethod: co.method,
            weekend: co.weekend,
            currency: co.currency,
          ),
        );
  }

  Future<void> _previewNotifications(BuildContext context, WidgetRef ref) {
    final engine = ref.read(engineProvider);
    final today = ref.read(todayProvider);
    final now = ref.read(nowMinuteProvider);
    final s = ref.read(appDataProvider).settings;
    final plan = planNotifications(
      engine.day(today),
      s,
      today: today,
      now: now,
    );
    return showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final c = ctx.c;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * .8,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                const Text(
                  'تنبيهات اليوم',
                  style: TextStyle(
                    fontFamily: fontDisplay,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                FieldLabel('تُرسل (${plan.send.length})'),
                if (plan.send.isEmpty)
                  Text('ما بقى شي اليوم.', style: TextStyle(color: c.muted)),
                for (final n in plan.send)
                  ListTile(
                    dense: true,
                    leading: Text(fmtTime(n.minute)),
                    title: Text(n.title),
                    subtitle: Text(n.kind.label),
                  ),
                FieldLabel('أُسقطت (${plan.dropped.length})'),
                if (plan.dropped.isEmpty)
                  Text('ولا شي.', style: TextStyle(color: c.muted)),
                for (final d in plan.dropped)
                  ListTile(
                    dense: true,
                    leading: Text(fmtTime(d.minute)),
                    title: Text(d.title),
                    subtitle: Text(d.reason),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    try {
      final d = await BackupService.pick();
      if (d == null || !context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('نستبدل بياناتك بهذه النسخة؟'),
          content: Text(BackupService.summary(d)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('استبدل'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await ref.read(appDataProvider.notifier).importBackup(d);
      if (context.mounted) toast(context, 'استرجعنا النسخة');
    } on FormatException catch (e) {
      if (context.mounted) toast(context, e.message);
    } catch (_) {
      if (context.mounted) toast(context, 'تعذّر قراءة الملف');
    }
  }
}
