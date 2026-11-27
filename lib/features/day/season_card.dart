import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';
import '../settings/season_screens.dart';
import '../settings/settings_screen.dart' show pushPage;

/// بطاقات المواسم في «يومي»: رمضان، العيد، الوضع الحالي، العطلة، ومواعيد اليوم كاملًا.
class SeasonCards extends ConsumerWidget {
  const SeasonCards({super.key, required this.date, required this.plan});
  final Day date;
  final DayPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = plan.context;
    if (ctx == null) return const SizedBox.shrink();
    final today = ref.watch(todayProvider);
    final ctrl = ref.read(appDataProvider.notifier);
    final season = ref.watch(appDataProvider.select((d) => d.settings.season));
    final offset = ref.watch(
      appDataProvider.select((d) => d.profile?.hijriOffset ?? 0),
    );
    final cards = <Widget>[];

    // «نبدأ جدول رمضان؟» من 27 شعبان حتى يجيب المستخدم.
    if (date == today && ctx.ramadanPending && ctx.hijri != null) {
      final soon = daysToRamadan(date, hijriOffset: offset) ?? 0;
      final title = switch (soon) {
        0 => 'رمضان مبارك! نبدأ جدول رمضان؟',
        1 => 'رمضان بكرة. نجهّز جدول رمضان؟',
        2 => 'رمضان بعد يومين. نجهّز جدول رمضان؟',
        _ => 'رمضان بعد ${nums(soon)} أيام. نجهّز جدول رمضان؟',
      };
      final year = ctx.hijri!.year;
      cards.add(
        SeasonCard(
          icon: Icons.nightlight_outlined,
          title: title,
          body: [
            'سحور وإفطار بدل الوجبات',
            if (season.taraweeh) 'التراويح',
            if (season.ramadanWork)
              'دوام رمضان ${fmtRange(season.ramadanWorkStart, season.ramadanWorkEnd)}',
            if (season.lateOutings) 'والمشي بعد الإفطار',
          ].join('، '),
          actions: [
            SmallButton(
              label: 'ابدأ جدول رمضان',
              primary: true,
              onTap: () async {
                await ctrl.answerRamadan(year, true);
                if (context.mounted) toast(context, 'رمضان مبارك. جدولك جاهز');
              },
            ),
            SmallButton(
              label: 'عدّل قبل',
              onTap: () => pushPage(context, const RamadanPage()),
            ),
            TextButton(
              onPressed: () async {
                await ctrl.answerRamadan(year, false);
                if (context.mounted) {
                  toast(
                    context,
                    'خلّينا جدولك كما هو. تقدر تفعّله من الإعدادات',
                  );
                }
              },
              child: const Text('خلّ جدولي كما هو'),
            ),
          ],
        ),
      );
    } else if (ctx.ramadan) {
      final pr = plan.prayers;
      final day = ctx.hijri!.day;
      cards.add(
        SeasonCard(
          icon: Icons.nightlight_outlined,
          title: day == 1 ? 'رمضان مبارك' : 'رمضان · اليوم ${nums(day)}',
          body:
              'الإمساك ${fmtTime(pr.fajr)} · الإفطار ${fmtTime(pr.maghrib)}'
              '${day >= 27 ? ' · لا تنسَ زكاة الفطر' : ''}',
          actions: [
            SmallButton(
              label: 'عدّل',
              onTap: () => pushPage(context, const RamadanPage()),
            ),
          ],
        ),
      );
    } else if (ctx.fasting) {
      cards.add(
        SeasonCard(
          icon: Icons.nightlight_outlined,
          title: 'صيام ${arabicWeekdays[date.weekday]}',
          body:
              'السحور قبل الفجر ${fmtTime(plan.prayers.fajr)} · الإفطار ${fmtTime(plan.prayers.maghrib)}',
        ),
      );
    }

    final eid = ctx.eid;
    if (eid != null) {
      cards.add(
        SeasonCard(
          icon: Icons.redeem_outlined,
          tone: SeasonTone.warm,
          title: '${eid.kind.label} مبارك',
          body: eid.first
              ? 'اليوم صلاة العيد ومعايدة الأهل، والدوام إجازة.'
              : 'أيام العيد: الدوام إجازة، ووقت للزيارات.',
        ),
      );
    }

    final mode = ctx.mode;
    if (mode != null) {
      final until = 'حتى ${fmtDayShort(mode.to)}';
      final (icon, title, body, action) = switch (mode.kind) {
        ModeKind.vacation => (
          Icons.beach_access_outlined,
          'إجازة $until',
          mode.kidsOff
              ? 'لا دوام، ومشاوير المدرسة والحصص متوقفة.'
              : 'لا دوام. مشاوير الأولاد باقية.',
          'أنهِها اليوم',
        ),
        ModeKind.travel => (
          Icons.flight_takeoff,
          'مسافر${mode.city == null ? '' : ' إلى ${mode.city}'} $until',
          [
            if (mode.hasPlace) 'المواقيت بتوقيت ${mode.city}',
            mode.workOff ? 'لا دوام' : 'الدوام باقٍ',
          ].join(' · '),
          'رجعت',
        ),
        ModeKind.pause => (
          Icons.pause_circle_outline,
          'الجدول موقوف $until',
          'تبقى الصلاة والمواعيد الثابتة. العادات والاقتراحات ترجع بعدها.',
          'استأنف',
        ),
      };
      cards.add(
        SeasonCard(
          icon: icon,
          title: title,
          body: body,
          actions: [
            if (date == today)
              SmallButton(label: action, onTap: () => ctrl.endModeToday(mode)),
          ],
        ),
      );
    }

    final h = ctx.holiday;
    if (h != null) {
      cards.add(
        SeasonCard(
          icon: Icons.flag_outlined,
          title: h.name,
          body: h.off ? 'عطلة رسمية: لا دوام ولا مدرسة.' : 'مناسبة وطنية',
        ),
      );
    }

    if (plan.allDay.isNotEmpty) {
      cards.add(
        SeasonCard(
          icon: Icons.event_outlined,
          title: plan.allDay.join('، '),
          body: 'من تقويمك · طوال اليوم',
        ),
      );
    }

    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final card in cards)
          Padding(padding: const EdgeInsets.only(top: 8), child: card),
      ],
    );
  }
}

enum SeasonTone { calm, warm }

/// بطاقة معلومة هادئة: أيقونة، عنوان، سطر، وأزرار اختيارية.
class SeasonCard extends StatelessWidget {
  const SeasonCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actions = const [],
    this.tone = SeasonTone.calm,
  });
  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;
  final SeasonTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final warm = tone == SeasonTone.warm;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(R.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconSquare(
                icon,
                bg: warm ? c.amberSoft : c.accentSoft,
                fg: warm ? c.amber : c.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: T.cardTitle,
                    ),
                    Text(
                      nums(body),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: T.meta.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}
