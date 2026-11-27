import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/library.dart';
import '../../state/providers.dart';
import 'labels.dart';
import 'preview.dart';
import 'rule_editors.dart';

enum _Tab { mine, library }

/// «روتيني»: تضبط فيه ما تسويه. كل تعديل مسودة تنتهي بمعاينة التغييرات.
class RoutineScreen extends ConsumerStatefulWidget {
  const RoutineScreen({super.key});
  @override
  ConsumerState<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends ConsumerState<RoutineScreen> {
  _Tab _tab = _Tab.mine;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            const Text(
              'روتيني',
              style: TextStyle(
                fontFamily: fontDisplay,
                fontWeight: FontWeight.w600,
                fontSize: 19,
              ),
            ),
            Text(
              'تبني روتينك مرة، والتطبيق يحوّله لجدول كل يوم.',
              style: TextStyle(color: c.ink2),
            ),
            const SizedBox(height: 14),
            Segmented<_Tab>(
              values: _Tab.values,
              labels: const ['تشكيلتي', 'المكتبة'],
              selected: _tab,
              onChanged: (t) => setState(() => _tab = t),
            ),
            if (_tab == _Tab.mine) ..._mine(context) else ..._library(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _mine(BuildContext context) {
    final engine = ref.watch(engineProvider);
    final today = ref.watch(todayProvider);
    final profile = ref.watch(appDataProvider.select((d) => d.profile))!;
    final rules = engine.rulesOn(today, includePaused: true);
    // القواعد التي تبدأ لاحقًا (مثل «ابدأ من بكرة»).
    final upcoming = ref
        .watch(appDataProvider.select((d) => d.rules))
        .where(
          (r) =>
              r.validFrom.isAfter(today) && !rules.any((x) => x.key == r.key),
        )
        .toList();
    final all = [...rules, ...upcoming];
    final fixedRules = all
        .where(
          (r) =>
              r.kind == RuleKind.work ||
              r.kind == RuleKind.kid ||
              r.kind == RuleKind.klass,
        )
        .toList();
    final habitRules = all.where((r) => !fixedRules.contains(r)).toList()
      ..sort((a, b) => _order(a).compareTo(_order(b)));

    return [
      const SectionTitle('مواعيدك الثابتة'),
      for (final r in fixedRules)
        _RuleTile(rule: r, today: today, city: profile.city),
      if (fixedRules.isEmpty)
        MCard(
          dashed: true,
          color: context.c.bg,
          border: context.c.accent,
          child: Text(
            'الدوام، توصيل الأولاد، الحصص والدورات. ما يتحركون أبدًا، والباقي يترتب حولهم.',
            style: TextStyle(color: context.c.ink2),
          ),
        ),
      const SizedBox(height: 10),
      PillButton(
        label: '+ أضف إلى تشكيلتي',
        expand: true,
        onPressed: () => _addFixed(context, all),
      ),
      const SectionTitle('عاداتك وروتينك'),
      for (final r in habitRules)
        _RuleTile(rule: r, today: today, city: profile.city),
      _SleepTile(profile: profile),
      const SizedBox(height: 10),
      PillButton(
        label: '+ أضف من المكتبة',
        soft: true,
        expand: true,
        onPressed: () => setState(() => _tab = _Tab.library),
      ),
    ];
  }

  int _order(Rule r) => switch (r.kind) {
    RuleKind.prayers => 0,
    RuleKind.adhkar => 1,
    RuleKind.quran => 2,
    RuleKind.meal => 3,
    RuleKind.habit => 4,
    RuleKind.reminders => 5,
    _ => 6,
  };

  Future<void> _addFixed(BuildContext context, List<Rule> all) async {
    final weekend = ref.read(appDataProvider).profile!.weekend;
    final hasWork = all.any((r) => r.kind == RuleKind.work);
    final choice = await showModalBottomSheet<String>(
      useRootNavigator: true,
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!hasWork)
              ListTile(
                leading: Icon(iconFor('work')),
                title: const Text('الدوام'),
                subtitle: const Text('صباحي، مسائي، ليلي أو مخصص، والاستراحة'),
                onTap: () => Navigator.pop(ctx, 'work'),
              ),
            ListTile(
              leading: Icon(iconFor('kid')),
              title: const Text('توصيل واستلام'),
              subtitle: const Text(
                'اختر الطفل، وفعّل التوصيل أو الاستلام أو الاثنين',
              ),
              onTap: () => Navigator.pop(ctx, 'kid'),
            ),
            ListTile(
              leading: Icon(iconFor('class')),
              title: const Text('حصة أو دورة'),
              subtitle: const Text(
                'حصة موسيقى، نادي، جامعة أو دورة بموعد أسبوعي',
              ),
              onTap: () => Navigator.pop(ctx, 'class'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final RuleConfig initial = switch (choice) {
      'work' => WorkConfig(
        days: {
          for (final d in workdays(weekend))
            d: [const WorkPeriod(450, 960, breakStart: 720, breakEnd: 750)],
        },
      ),
      'kid' => const KidConfig(child: '', days: {}),
      _ => const ClassConfig(
        title: '',
        weekdays: {DateTime.tuesday},
        start: 17 * 60,
        end: 18 * 60,
      ),
    };
    final cfg = await editRuleConfig(context, initial, weekend: weekend);
    if (cfg == null || !context.mounted) return;
    final key = switch (choice) {
      'work' => 'work',
      'kid' => 'kid:${newId().substring(0, 8)}',
      _ => 'class:${newId().substring(0, 8)}',
    };
    await saveWithPreview(context, ref, null, cfg, key: key);
  }

  List<Widget> _library(BuildContext context) {
    final c = context.c;
    final today = ref.watch(todayProvider);
    final engine = ref.watch(engineProvider);
    final profile = ref.watch(appDataProvider.select((d) => d.profile))!;
    final active = engine
        .rulesOn(today, includePaused: true)
        .map((r) => r.key)
        .toSet();
    final groups = {
      'faith': 'الصلاة والقرآن',
      'meals': 'الوجبات',
      'habits': 'العادات',
      'light': 'خفيفة',
      'money': 'المال',
    };
    return [
      const SizedBox(height: 8),
      for (final g in groups.entries) ...[
        if (libraryEntries.any(
          (e) => e.group == g.key && (!e.islamOnly || profile.islam),
        ))
          SectionTitle(g.value),
        for (final e in libraryEntries.where(
          (e) => e.group == g.key && (!e.islamOnly || profile.islam),
        ))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MCard(
              child: Row(
                children: [
                  Icon(iconFor(e.icon), color: c.ink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          e.description,
                          style: TextStyle(fontSize: 12, color: c.ink2),
                        ),
                      ],
                    ),
                  ),
                  if (active.contains(e.key))
                    Text(
                      'مضافة ✓',
                      style: TextStyle(
                        color: c.good,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    PillButton(
                      label: 'أضف',
                      dense: true,
                      onPressed: () async {
                        final cfg = await editRuleConfig(
                          context,
                          e.build(),
                          weekend: profile.weekend,
                        );
                        if (cfg != null && context.mounted) {
                          await saveWithPreview(
                            context,
                            ref,
                            null,
                            cfg,
                            key: e.key,
                          );
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
      ],
      const SectionTitle('عادة من عندك'),
      PillButton(
        label: '+ عادة جديدة',
        expand: true,
        onPressed: () async {
          final cfg = await editRuleConfig(
            context,
            const FlexConfig(
              kind: RuleKind.habit,
              title: '',
              duration: 20,
              recurrence: TimesPerWeek(3),
              optional: true,
            ),
          );
          if (cfg != null && context.mounted) {
            await saveWithPreview(
              context,
              ref,
              null,
              cfg,
              key: 'habit:${newId().substring(0, 8)}',
            );
          }
        },
      ),
    ];
  }
}

class _RuleTile extends ConsumerWidget {
  const _RuleTile({
    required this.rule,
    required this.today,
    required this.city,
  });
  final Rule rule;
  final Day today;
  final String city;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final cfg = rule.config;
    final paused = rule.pausedOn(today);
    final starts = rule.validFrom.isAfter(today);
    final track = switch (cfg) {
      FlexConfig(:final track) => trackLabel(track),
      PrayersConfig(:final track) => trackLabel(track),
      AdhkarConfig() => trackLabel(TrackMode.confirm),
      KidConfig() || ClassConfig() => 'تأكيد سريع',
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MCard(
        color: paused ? c.bg : null,
        onTap: () => _actions(context, ref),
        child: Row(
          children: [
            Icon(iconFor(ruleIcon(cfg)), color: paused ? c.muted : c.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ruleTitle(cfg),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: paused ? c.muted : c.ink,
                    ),
                  ),
                  Text(
                    ruleSummary(cfg, city: city),
                    style: TextStyle(fontSize: 12, color: c.ink2),
                  ),
                  if (track != null || paused || starts)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        [
                          if (paused)
                            'موقوف مؤقتًا${rule.pausedUntil == null ? '' : ' حتى ${rule.pausedUntil!.day}/${rule.pausedUntil!.month}'}',
                          if (starts) 'يبدأ ${fmtDayLong(rule.validFrom)}',
                          ?track,
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: paused ? c.warn : c.accent2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.tune, color: c.muted, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _actions(BuildContext context, WidgetRef ref) async {
    final ctrl = ref.read(appDataProvider.notifier);
    final paused = rule.pausedOn(today);
    final choice = await showModalBottomSheet<String>(
      useRootNavigator: true,
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                ruleTitle(rule.config),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('عدّل'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            if (rule.kind != RuleKind.work && rule.kind != RuleKind.prayers)
              paused
                  ? ListTile(
                      leading: const Icon(Icons.play_arrow),
                      title: const Text('استأنف'),
                      onTap: () => Navigator.pop(ctx, 'resume'),
                    )
                  : ListTile(
                      leading: const Icon(Icons.pause),
                      title: const Text('أوقف مؤقتًا'),
                      subtitle: const Text('يختفي من جدولك ولا يُحسب'),
                      onTap: () => Navigator.pop(ctx, 'pause'),
                    ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
              title: Text(
                'احذف من روتيني',
                style: TextStyle(color: Colors.red.shade400),
              ),
              subtitle: const Text('الأيام السابقة تبقى كما هي'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'edit':
        final cfg = await editRuleConfig(
          context,
          rule.config,
          weekend: ref.read(appDataProvider).profile!.weekend,
        );
        if (cfg != null && context.mounted) {
          await saveWithPreview(context, ref, rule, cfg);
        }
      case 'pause':
        final until = await showModalBottomSheet<int>(
          useRootNavigator: true,
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('أسبوع'),
                  onTap: () => Navigator.pop(ctx, 7),
                ),
                ListTile(
                  title: const Text('أسبوعين'),
                  onTap: () => Navigator.pop(ctx, 14),
                ),
                ListTile(
                  title: const Text('شهر'),
                  onTap: () => Navigator.pop(ctx, 30),
                ),
                ListTile(
                  title: const Text('حتى أستأنف'),
                  onTap: () => Navigator.pop(ctx, 0),
                ),
              ],
            ),
          ),
        );
        if (until != null) {
          await ctrl.pauseRule(
            rule.key,
            from: today,
            until: until == 0 ? null : today.add(until - 1),
          );
        }
      case 'resume':
        await ctrl.resumeRule(rule.key);
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('نحذف «${ruleTitle(rule.config)}»؟'),
            content: const Text(
              'يختفي من اليوم فصاعدًا. الأيام السابقة وسجلاتها تبقى.',
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
        if (ok == true) await ctrl.removeRule(rule.key, from: today);
    }
  }
}

class _SleepTile extends ConsumerWidget {
  const _SleepTile({required this.profile});
  final UserProfile profile;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MCard(
        onTap: () async {
          final wake = await pickTime(
            context,
            initial: profile.wake,
            title: 'وقت الصحيان',
          );
          if (wake == null || !context.mounted) return;
          final sleep = await pickTime(
            context,
            initial: profile.sleep,
            title: 'وقت النوم',
          );
          if (sleep == null) return;
          await ref
              .read(appDataProvider.notifier)
              .updateProfile(profile.copyWith(wake: wake, sleep: sleep));
        },
        child: Row(
          children: [
            Icon(iconFor('sleep'), color: c.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'النوم',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    'الصحيان ${fmtTime(profile.wake)} · النوم ${fmtTime(profile.sleep)}',
                    style: TextStyle(fontSize: 12, color: c.ink2),
                  ),
                  Text(
                    'نحجز وقت النوم ولا نحط فيه شي',
                    style: TextStyle(
                      fontSize: 12,
                      color: c.accent2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.tune, color: c.muted, size: 20),
          ],
        ),
      ),
    );
  }
}
