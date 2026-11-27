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
import '../routine/labels.dart';
import '../routine/preview.dart';
import '../routine/rule_editors.dart';
import 'contacts_screens.dart';

void pushPage(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

/// صفحة فرعية بعنوان وقائمة.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: children,
      ),
    ),
  );
}

/// تبويب «الإعدادات»: أربع مجموعات بدل قائمة طويلة.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final p = data.profile;
    if (p == null) return const SizedBox.shrink();
    final s = data.settings;
    final ctrl = ref.read(appDataProvider.notifier);
    final defaults = ref.watch(defaultsProvider);
    final work = ref
        .watch(engineProvider)
        .rulesOn(ref.watch(todayProvider))
        .where((r) => r.config is WorkConfig)
        .firstOrNull;
    final contacts = data.contacts;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const Text('الإعدادات', style: T.brand),
            SettingsGroup(
              title: 'يومك',
              children: [
                SettingsRow(
                  icon: Icons.location_on_outlined,
                  title: 'المدينة',
                  value: p.city,
                  onTap: () => pickCity(context, ref, defaults, p),
                ),
                SettingsRow(
                  icon: Icons.schedule,
                  title: 'النوم والدوام',
                  value: work == null
                      ? fmtRange(p.wake, p.sleep)
                      : '${fmtRange(p.wake, p.sleep)} · دوام',
                  onTap: () => pushPage(context, const SleepWorkPage()),
                ),
                if (p.islam)
                  SettingsRow(
                    icon: Icons.mosque_outlined,
                    title: 'أوقات الصلاة',
                    value: p.calcMethod.label,
                    onTap: () => pushPage(context, const PrayerTimesPage()),
                  ),
              ],
            ),
            SettingsGroup(
              title: 'الأقسام',
              children: [
                SettingsRow(
                  icon: Icons.forum_outlined,
                  title: 'التواصل مع الناس',
                  subtitle: contacts.enabled
                      ? 'مفعّل · ${nums(data.people.length)} ${data.people.length > 2 && data.people.length <= 10 ? 'أشخاص' : 'شخص'} · ${nums(contacts.level.perWeek)} في الأسبوع'
                      : 'متوقف',
                  onTap: () => pushPage(context, const ContactsSettingsPage()),
                ),
                SettingsRow(
                  icon: Icons.auto_stories_outlined,
                  title: 'المحتوى الديني',
                  subtitle: 'الأذكار، القرآن، الجمعة',
                  toggle: p.islam,
                  onToggle: (v) => ctrl.updateProfile(
                    p.copyWith(religion: v ? Religion.islam : Religion.none),
                  ),
                ),
                SettingsRow(
                  icon: Icons.track_changes,
                  title: 'الأهداف',
                  toggle: s.goalsEnabled,
                  onToggle: (v) =>
                      ctrl.updateSettings(s.copyWith(goalsEnabled: v)),
                ),
                const SettingsRow(
                  icon: Icons.savings_outlined,
                  title: 'المال',
                  subtitle: 'قريبًا',
                ),
              ],
            ),
            SettingsGroup(
              title: 'التنبيهات والمظهر',
              children: [
                SettingsRow(
                  icon: Icons.notifications_none,
                  title: 'التنبيهات',
                  value: s.leadMinutes == 0
                      ? 'في الوقت'
                      : 'قبل المهمة بـ ${nums(s.leadMinutes)} د',
                  onTap: () => pushPage(context, const NotificationsPage()),
                ),
                SettingsRow(
                  icon: Icons.palette_outlined,
                  title: 'المظهر',
                  value: '${s.theme.label} · خط ${s.fontSize.label}',
                  onTap: () => pushPage(context, const AppearancePage()),
                ),
              ],
            ),
            SettingsGroup(
              title: 'بياناتك',
              children: [
                SettingsRow(
                  icon: Icons.person_outline,
                  title: 'الاسم',
                  value: p.name.isEmpty ? 'بدون اسم' : p.name,
                  onTap: () async {
                    final name = await askText(context, 'الاسم', p.name);
                    if (name != null) {
                      await ctrl.updateProfile(p.copyWith(name: name));
                    }
                  },
                ),
                SettingsRow(
                  icon: Icons.cloud_upload_outlined,
                  title: 'النسخ الاحتياطي',
                  subtitle: 'تصدير واسترجاع بملف',
                  onTap: () => pushPage(context, const DataPage()),
                ),
                SettingsRow(
                  icon: Icons.lock_outline,
                  title: 'الخصوصية',
                  subtitle: 'بياناتك على جهازك فقط، في قاعدة مشفّرة',
                  onTap: () => pushPage(context, const DataPage()),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'مُتَّسَع ${nums('0.2.0')}',
                style: T.micro.copyWith(color: context.c.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// النوم والدوام.
class SleepWorkPage extends ConsumerWidget {
  const SleepWorkPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(appDataProvider.select((d) => d.profile))!;
    final ctrl = ref.read(appDataProvider.notifier);
    final today = ref.watch(todayProvider);
    final work = ref
        .watch(engineProvider)
        .rulesOn(today, includePaused: true)
        .where((r) => r.config is WorkConfig)
        .firstOrNull;
    return SettingsPage(
      title: 'النوم والدوام',
      children: [
        SettingsGroup(
          title: 'النوم',
          children: [
            SettingsRow(
              icon: Icons.alarm,
              title: 'أصحى',
              value: fmtTime(p.wake),
              onTap: () async {
                final t = await pickTime(
                  context,
                  initial: p.wake,
                  title: 'أصحى',
                );
                if (t != null) await ctrl.updateProfile(p.copyWith(wake: t));
              },
            ),
            SettingsRow(
              icon: Icons.bedtime_outlined,
              title: 'أنام',
              value: fmtTime(p.sleep),
              onTap: () async {
                final t = await pickTime(
                  context,
                  initial: p.sleep,
                  title: 'أنام',
                );
                if (t != null) await ctrl.updateProfile(p.copyWith(sleep: t));
              },
            ),
          ],
        ),
        SettingsGroup(
          title: 'الدوام',
          children: [
            SettingsRow(
              icon: Icons.work_outline,
              title: work == null ? 'أضف دوامك' : 'الدوام',
              subtitle: work == null
                  ? 'ثابت أو ورديات، مع الاستراحة'
                  : ruleSummary(work.config),
              onTap: () async {
                final initial =
                    work?.config ??
                    WorkConfig(
                      days: {
                        for (final d in workdays(p.weekend))
                          d: [
                            const WorkPeriod(
                              450,
                              930,
                              breakStart: 720,
                              breakEnd: 750,
                            ),
                          ],
                      },
                    );
                final cfg = await editRuleConfig(
                  context,
                  initial,
                  weekend: p.weekend,
                );
                if (cfg == null || !context.mounted) return;
                await saveWithPreview(context, ref, work, cfg, key: 'work');
              },
            ),
            if (work != null)
              SettingsRow(
                icon: Icons.delete_outline,
                title: 'بدون دوام',
                danger: true,
                onTap: () => ctrl.removeRule('work', from: today),
              ),
          ],
        ),
      ],
    );
  }
}

/// أوقات الصلاة: طريقة الحساب، الإزاحة الهجرية، والسنن.
class PrayerTimesPage extends ConsumerWidget {
  const PrayerTimesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(appDataProvider.select((d) => d.profile))!;
    final ctrl = ref.read(appDataProvider.notifier);
    final today = ref.watch(todayProvider);
    final plan = ref.watch(dayPlanProvider(today));
    final rule = ref
        .watch(engineProvider)
        .rulesOn(today, includePaused: true)
        .where((r) => r.config is PrayersConfig)
        .firstOrNull;
    final pr = plan.prayers;
    return SettingsPage(
      title: 'أوقات الصلاة',
      children: [
        SettingsGroup(
          title: 'اليوم في ${p.city}',
          children: [
            for (final (n, m) in [
              ('الفجر', pr.fajr),
              ('الشروق', pr.sunrise),
              (today.weekday == DateTime.friday ? 'الجمعة' : 'الظهر', pr.dhuhr),
              ('العصر', pr.asr),
              ('المغرب', pr.maghrib),
              ('العشاء', pr.isha),
            ])
              SettingsRow(title: n, value: fmtTime(m)),
          ],
        ),
        SettingsGroup(
          title: 'الحساب',
          children: [
            SettingsRow(
              title: 'طريقة الحساب',
              value: p.calcMethod.label,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'إزاحة التاريخ الهجري',
                      style: T.body.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Segmented<int>(
                    small: true,
                    values: const [-1, 0, 1],
                    labels: [nums('-1'), nums('0'), nums('+1')],
                    selected: p.hijriOffset,
                    onChanged: (v) =>
                        ctrl.updateProfile(p.copyWith(hijriOffset: v)),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (rule != null)
          SettingsGroup(
            title: 'الصلوات في جدولك',
            children: [
              SettingsRow(
                title: 'المكان والسنن والتتبع',
                subtitle: ruleSummary(rule.config, city: p.city),
                onTap: () async {
                  final cfg = await editRuleConfig(
                    context,
                    rule.config,
                    weekend: p.weekend,
                  );
                  if (cfg == null || !context.mounted) return;
                  await saveWithPreview(context, ref, rule, cfg);
                },
              ),
            ],
          ),
      ],
    );
  }
}

/// التنبيهات.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appDataProvider.select((d) => d.settings));
    final ctrl = ref.read(appDataProvider.notifier);
    Future<int?> choose(
      String title,
      List<int> values,
      String Function(int) label,
      int current,
    ) => showModalBottomSheet<int>(
      useRootNavigator: true,
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SheetHeader(title),
            ),
            for (final v in values)
              ListTile(
                title: Text(label(v)),
                trailing: v == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, v),
              ),
          ],
        ),
      ),
    );
    return SettingsPage(
      title: 'التنبيهات',
      children: [
        SettingsGroup(
          title: 'ما ينبّهك',
          children: [
            for (final k in NotifyKind.values)
              SettingsRow(
                title: k.label,
                subtitle: switch (k) {
                  NotifyKind.prayer => 'في وقتها، ولا تتأثر بأوقات الهدوء',
                  NotifyKind.water => 'في وقتها',
                  _ => 'قبلها بـ ${nums(s.leadMinutes)} دقائق',
                },
                toggle: s.notifyEnabled.contains(k),
                onToggle: (v) => ctrl.updateSettings(
                  s.copyWith(
                    notifyEnabled: v
                        ? {...s.notifyEnabled, k}
                        : ({...s.notifyEnabled}..remove(k)),
                  ),
                ),
              ),
          ],
        ),
        SettingsGroup(
          title: 'التوقيت',
          children: [
            SettingsRow(
              title: 'قبل الموعد بـ',
              value: s.leadMinutes == 0
                  ? 'في وقته'
                  : '${nums(s.leadMinutes)} دقائق',
              onTap: () async {
                final v = await choose(
                  'قبل الموعد بـ',
                  const [0, 5, 10, 15, 30],
                  (v) => v == 0 ? 'في وقته' : '${nums(v)} دقائق',
                  s.leadMinutes,
                );
                if (v != null) {
                  await ctrl.updateSettings(s.copyWith(leadMinutes: v));
                }
              },
            ),
            SettingsRow(
              title: 'أوقات الهدوء',
              value: fmtRange(s.quietStart, s.quietEnd),
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
            SettingsRow(
              title: 'الحد اليومي',
              value: '${nums(s.dailyCap)} تنبيه',
              onTap: () async {
                final v = await choose(
                  'الحد اليومي',
                  const [6, 8, 12, 16, 24],
                  (v) => nums(v),
                  s.dailyCap,
                );
                if (v != null) {
                  await ctrl.updateSettings(s.copyWith(dailyCap: v));
                }
              },
            ),
            SettingsRow(
              title: '«راجع يومك» قبل النوم',
              toggle: s.eveningReview,
              onToggle: (v) =>
                  ctrl.updateSettings(s.copyWith(eveningReview: v)),
            ),
            SettingsRow(
              title: 'الحد اليومي للوقت الاختياري',
              value: fmtDuration(s.optionalCapMinutes),
              onTap: () async {
                final v = await choose(
                  'الوقت الاختياري',
                  const [60, 120, 180, 240, 300],
                  fmtDuration,
                  s.optionalCapMinutes,
                );
                if (v != null) {
                  await ctrl.updateSettings(s.copyWith(optionalCapMinutes: v));
                }
              },
            ),
          ],
        ),
        SettingsGroup(
          children: [
            SettingsRow(
              title: 'تنبيهات اليوم',
              subtitle: 'ما يُرسل وما أُسقط مع السبب',
              onTap: () => previewNotifications(context, ref),
            ),
            SettingsRow(
              title: 'إذن التنبيهات',
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
          ],
        ),
      ],
    );
  }
}

/// المظهر: الثيم وحجم الخط والأرقام.
class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final s = ref.watch(appDataProvider.select((d) => d.settings));
    final ctrl = ref.read(appDataProvider.notifier);
    Widget label(String t) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 20, 4, 8),
      child: Text(t, style: T.label.copyWith(color: c.muted)),
    );
    final scale = s.fontSize.factor;
    return SettingsPage(
      title: 'المظهر',
      children: [
        label('الثيم'),
        Segmented<ThemePref>(
          values: ThemePref.values,
          labels: [for (final t in ThemePref.values) t.label],
          selected: s.theme,
          onChanged: (v) => ctrl.updateSettings(s.copyWith(theme: v)),
        ),
        label('حجم الخط'),
        Segmented<FontSize>(
          values: FontSize.values,
          labels: [for (final f in FontSize.values) f.label],
          selected: s.fontSize,
          onChanged: (v) => ctrl.updateSettings(s.copyWith(fontSize: v)),
        ),
        const SizedBox(height: 12),
        // معاينة حيّة لبطاقة بنفس الحجم المختار.
        MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(R.md),
              border: Border.all(color: c.line),
            ),
            child: Row(
              children: [
                const IconSquare(Icons.mosque_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('صلاة العصر', maxLines: 1, style: T.cardTitle),
                      Text(
                        '${fmtRange(15 * 60 + 15, 15 * 60 + 27)} · معاينة',
                        maxLines: 1,
                        style: T.meta.copyWith(color: c.muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  margin: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.lineStrong, width: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        label('الأرقام'),
        Segmented<bool>(
          values: const [true, false],
          labels: const ['١٢٣', '123'],
          selected: s.arabicDigits,
          onChanged: (v) => ctrl.updateSettings(s.copyWith(arabicDigits: v)),
        ),
        label('التاريخ في الرأس'),
        Segmented<HeaderDate>(
          values: HeaderDate.values,
          labels: [for (final h in HeaderDate.values) h.label],
          selected: s.headerDate,
          onChanged: (v) => ctrl.updateSettings(s.copyWith(headerDate: v)),
        ),
        SettingsGroup(
          title: 'الجدول',
          children: [
            SettingsRow(
              icon: Icons.water_drop_outlined,
              title: 'عرض التذكيرات القصيرة في الجدول',
              toggle: s.showLines,
              onToggle: (v) => ctrl.updateSettings(s.copyWith(showLines: v)),
            ),
            SettingsRow(
              icon: Icons.density_small,
              title: 'عرض مضغوط',
              subtitle: 'بطاقات أقصر',
              toggle: s.compact,
              onToggle: (v) => ctrl.updateSettings(s.copyWith(compact: v)),
            ),
          ],
        ),
      ],
    );
  }
}

/// بياناتك: النسخ الاحتياطي، الخصوصية، البدء من جديد.
class DataPage extends ConsumerWidget {
  const DataPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(appDataProvider.notifier);
    return SettingsPage(
      title: 'بياناتك',
      children: [
        SettingsGroup(
          title: 'النسخ الاحتياطي',
          children: [
            SettingsRow(
              icon: Icons.ios_share,
              title: 'صدّر نسخة',
              subtitle: 'ملف فيه كل بياناتك. احفظه في مكان آمن.',
              onTap: () => BackupService.export(
                ctrl.exportBackup(),
                ref.read(todayProvider),
              ),
            ),
            SettingsRow(
              icon: Icons.restore,
              title: 'استرجع من نسخة',
              subtitle: 'نعرض ملخصها قبل الاستبدال',
              onTap: () => importBackup(context, ref),
            ),
          ],
        ),
        const SettingsGroup(
          title: 'الخصوصية',
          children: [
            SettingsRow(
              icon: Icons.lock_outline,
              title: 'على جهازك فقط',
              subtitle:
                  'قاعدة مشفّرة. لا حساب ولا خادم في هذه المرحلة. أرقام جهات الاتصال لا تُرفع لأي مكان.',
            ),
          ],
        ),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.delete_forever_outlined,
              title: 'ابدأ من جديد',
              subtitle: 'يحذف كل البيانات من هذا الجهاز',
              danger: true,
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
          ],
        ),
      ],
    );
  }
}

Future<String?> askText(BuildContext context, String title, String initial) {
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

Future<void> pickCity(
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
                  style: T.label.copyWith(color: ctx.c.muted),
                ),
              ),
              for (final ci in co.cities)
                ListTile(
                  title: Text(ci.name),
                  trailing: ci.name == p.city ? const Icon(Icons.check) : null,
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

Future<void> previewNotifications(BuildContext context, WidgetRef ref) {
  final engine = ref.read(engineProvider);
  final today = ref.read(todayProvider);
  final now = ref.read(nowMinuteProvider);
  final s = ref.read(appDataProvider).settings;
  final plan = planNotifications(engine.day(today), s, today: today, now: now);
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
              const SheetHeader('تنبيهات اليوم'),
              FieldLabel('تُرسل (${nums(plan.send.length)})'),
              if (plan.send.isEmpty)
                Text('ما بقى شي اليوم.', style: TextStyle(color: c.muted)),
              for (final n in plan.send)
                ListTile(
                  dense: true,
                  leading: Text(fmtTime(n.minute)),
                  title: Text(n.title),
                  subtitle: Text(n.kind.label),
                ),
              FieldLabel('أُسقطت (${nums(plan.dropped.length)})'),
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

Future<void> importBackup(BuildContext context, WidgetRef ref) async {
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
