import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';

/// «يوم خفيف»: يعرض الثابت اللي يبقى، ويقترح تأجيل المرن. المستخدم يغيّر
/// أي اقتراح (خلّه / المساء / بكرة) ثم يطبّق.
Future<void> showLightDaySheet(BuildContext context, WidgetRef ref, Day date) {
  return showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    builder: (_) => _LightDaySheet(date: date),
  );
}

class _LightDaySheet extends ConsumerStatefulWidget {
  const _LightDaySheet({required this.date});
  final Day date;
  @override
  ConsumerState<_LightDaySheet> createState() => _LightDaySheetState();
}

class _LightDaySheetState extends ConsumerState<_LightDaySheet> {
  late final DayPlan _plan = ref.read(dayPlanProvider(widget.date));
  late final bool _isToday = widget.date == ref.read(todayProvider);
  late final int _now = ref.read(nowMinuteProvider);
  late final List<LightProposal> _base = lightDay(
    _plan,
    now: _now,
    isToday: _isToday,
  );
  late final Map<String, LightAction> _choice = {
    for (final p in _base) p.item.key: p.action,
  };
  bool _busy = false;

  Future<void> _apply() async {
    setState(() => _busy = true);
    final ctrl = ref.read(appDataProvider.notifier);
    final evening = <String, int>{};
    var moved = 0;
    for (final p in _base) {
      final a = _choice[p.item.key]!;
      if (a == LightAction.keep) continue;
      moved++;
      if (a == LightAction.evening && p.eveningAt != null) {
        evening[p.item.key] = p.eveningAt!;
      } else {
        await ctrl.postponeTo(widget.date, p.item, widget.date.next);
      }
    }
    if (evening.isNotEmpty) await ctrl.applyRearrange(widget.date, evening);
    if (!mounted) return;
    Navigator.pop(context);
    toast(
      context,
      moved == 0 ? 'ما غيّرنا شي' : 'خفّفنا يومك: ${nums(moved)} تأجلت',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final stays = _plan.items
        .where(
          (i) =>
              staysOnLightDay(i) &&
              i.status == ItemStatus.pending &&
              i.kind != ItemKind.work &&
              (!_isToday || i.end > _now),
        )
        .toList();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * .85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const SheetHeader('يوم خفيف'),
            Text(
              'الثابت يبقى في وقته، والمرن نقترح نأجله. غيّر اللي تبغاه ثم طبّق.',
              style: T.meta.copyWith(color: c.muted),
            ),
            const SizedBox(height: 12),
            if (_base.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'يومك خفيف أصلًا. ما فيه شي مرن نأجله.',
                  style: T.body.copyWith(color: c.ink2),
                ),
              )
            else ...[
              Text('نخففه', style: T.label.copyWith(color: c.muted)),
              const SizedBox(height: 6),
              for (final p in _base)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: MCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(iconFor(p.item.icon), size: 18, color: c.ink2),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${p.item.title} · ${fmtTime(p.item.start)}',
                                style: T.cardTitle.copyWith(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final a in LightAction.values)
                              if (a != LightAction.evening ||
                                  p.eveningAt != null)
                                ChoiceChip(
                                  label: Text(
                                    a == LightAction.evening
                                        ? 'المساء ${fmtTime(p.eveningAt!)}'
                                        : a.label,
                                  ),
                                  selected: _choice[p.item.key] == a,
                                  showCheckmark: false,
                                  onSelected: (_) =>
                                      setState(() => _choice[p.item.key] = a),
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            if (stays.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('يبقى في وقته', style: T.label.copyWith(color: c.muted)),
              const SizedBox(height: 6),
              Text(
                stays.map((i) => '${i.title} ${fmtTime(i.start)}').join(' · '),
                style: T.meta.copyWith(color: c.ink2),
              ),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'طبّق',
              onPressed: _busy || _base.isEmpty ? null : _apply,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// المراجعة الأسبوعية
// ---------------------------------------------------------------------------

/// مفتاح يوم المراجعة في الإعدادات الصغيرة (meta). الافتراضي الخميس.
const reviewDayKey = 'reviewDay';

int reviewDayOf(WidgetRef ref) =>
    int.tryParse(
      ref.watch(appDataProvider.select((d) => d.meta[reviewDayKey])) ?? '',
    ) ??
    DateTime.thursday;

String reviewDoneKey(Day today) => 'review:${today.weekStart.key}';

Future<void> showWeeklyReview(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    builder: (_) => const _WeeklyReview(),
  );
}

class _WeeklyReview extends ConsumerWidget {
  const _WeeklyReview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final today = ref.watch(todayProvider);
    final engine = ref.watch(engineProvider);
    final notes = weeklyNotes(engine, today);
    final ctrl = ref.read(appDataProvider.notifier);
    var done = 0, total = 0;
    for (var k = 1; k <= 7; k++) {
      final p = dayProgress(engine.day(today.add(-k)));
      done += p.done;
      total += p.total;
    }
    final pct = total == 0 ? 0 : (done * 100 / total).round();
    final day = reviewDayOf(ref);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * .85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const SheetHeader('مراجعة أسبوعك'),
            Text(
              total == 0
                  ? 'ما فيه أسبوع كامل نراجعه بعد.'
                  : 'التزامك آخر ${nums('7')} أيام: ${nums('$pct')}٪ (${fmtCount(done, total)})',
              style: T.body,
            ),
            const SizedBox(height: 12),
            if (notes.isEmpty)
              Text(
                'ما لاحظنا شي يتكرر تأجيله. أسبوعك ماشي زين.',
                style: T.meta.copyWith(color: c.muted),
              ),
            for (final n in notes.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.suggestWindow == null
                            ? '«${n.title}» تأجل أو فات ${nums(n.missed)} من ${nums(n.total)}.'
                            : '«${n.title}» تأجل أو فات ${nums(n.missed)} من ${nums(n.total)}. تبغى نجربه ${n.suggestWindow == Window.morning ? 'صباحًا' : 'بالليل'} الأسبوع الجاي؟',
                        style: T.body,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (n.suggestWindow != null)
                            SmallButton(
                              label: 'جرّبه',
                              primary: true,
                              onTap: () async {
                                final r = engine
                                    .rulesOn(today)
                                    .where((r) => r.key == n.ruleKey)
                                    .firstOrNull;
                                final cfg = r?.config;
                                if (r == null || cfg is! FlexConfig) return;
                                await ctrl.saveRule(
                                  r,
                                  cfg.copyWith(
                                    windows: [n.suggestWindow!],
                                    clearPreferred: true,
                                  ),
                                  from: today,
                                );
                                if (context.mounted) {
                                  toast(
                                    context,
                                    'نقلنا «${n.title}» إلى ${n.suggestWindow!.label}',
                                  );
                                }
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text('يوم المراجعة', style: T.label.copyWith(color: c.muted)),
            const SizedBox(height: 6),
            ChoiceChips<int>(
              values: weekOrder,
              label: (d) => arabicWeekdays[d]!,
              selected: (d) => d == day,
              onSelected: (d) => ctrl.setMeta(reviewDayKey, '$d'),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'تمّ',
              onPressed: () async {
                await ctrl.setMeta(reviewDoneKey(today), 'done');
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
