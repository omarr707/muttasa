import 'package:schedule_core/schedule_core.dart';

String recurrenceLabel(Recurrence r) => nums(_recurrenceLabel(r));

String _recurrenceLabel(Recurrence r) => switch (r) {
  Daily() => 'كل يوم',
  Weekdays(:final days) => fmtWeekdays(days),
  TimesPerWeek(:final n) =>
    n == 1 ? 'مرة بالأسبوع' : (n == 2 ? 'مرتين بالأسبوع' : '$n مرات بالأسبوع'),
  Once(:final date) => 'مرة ${date.day}/${date.month}',
};

String trackLabel(TrackMode t) => switch (t) {
  TrackMode.confirm => 'تأكيد سريع',
  TrackMode.start => 'تبدأ بزر «ابدأ»',
  TrackMode.autocount => 'تُحسب ما لم أستثنها',
  TrackMode.auto => 'بدون تسجيل',
  TrackMode.quick => 'نقرة واحدة',
};

String ruleTitle(RuleConfig c) => switch (c) {
  PrayersConfig() => 'الصلوات',
  AdhkarConfig() => 'أذكار الصباح والمساء',
  FlexConfig(:final title) => title,
  WorkConfig(:final title) => title,
  KidConfig(:final child) => 'توصيل واستلام $child',
  ClassConfig(:final title) => title,
  RemindersConfig() => 'تذكيرات قصيرة',
  SavingsConfig() => 'الادخار',
};

String ruleIcon(RuleConfig c) => switch (c) {
  PrayersConfig() => 'prayer',
  AdhkarConfig() => 'sun',
  FlexConfig(:final icon) => icon,
  WorkConfig() => 'work',
  KidConfig() => 'kid',
  ClassConfig() => 'class',
  RemindersConfig() => 'water',
  SavingsConfig() => 'coin',
};

String ruleSummary(RuleConfig c, {String city = ''}) =>
    nums(_ruleSummary(c, city: city));

String _ruleSummary(RuleConfig c, {String city = ''}) {
  switch (c) {
    case PrayersConfig(:final sunnah):
      return [
        'حسب مواقيت $city',
        if (sunnah.isNotEmpty) 'مع السنن الرواتب' else 'الجمعة في وقتها',
      ].join(' · ');
    case AdhkarConfig(:final morning, :final evening, :final minutes):
      final parts = [if (morning) 'الصباح', if (evening) 'المساء'];
      return '${parts.join(' و')} · $minutes دقائق';
    case FlexConfig():
      final parts = <String>[recurrenceLabel(c.recurrence)];
      if (c.perDay > 1) parts.add('${c.perDay} جلسات باليوم');
      parts.add(fmtDuration(c.duration));
      parts.add(c.windows.map((w) => w.label).toSet().join(' ثم '));
      if (c.preferred != null) parts.add('يفضّل ${fmtTime(c.preferred!)}');
      if (c.pages != null) parts.add('${c.pages} صفحات');
      return parts.join(' · ');
    case WorkConfig(:final days, :final pattern):
      if (days.isEmpty) return 'بدون أيام';
      final periods = days.values.expand((p) => p).toList();
      final same = periods.every(
        (p) => p.start == periods.first.start && p.end == periods.first.end,
      );
      final p = periods.first;
      final brk = p.hasBreak
          ? ' · استراحة ${fmtRange(p.breakStart!, p.breakEnd!)}'
          : '';
      if (same) {
        return '${pattern.label} ${fmtWeekdays(days.keys.toSet())}، ${fmtRange(p.start, p.end)}$brk';
      }
      return '${pattern.label} · ${days.length} أيام بأوقات مختلفة';
    case KidConfig(:final days):
      if (days.isEmpty) return 'بدون أيام';
      final d = days.values.first;
      return [
        if (d.drop != null) 'توصيل ${fmtTime(d.drop!)}',
        if (d.pick != null) 'استلام ${fmtTime(d.pick!)}',
        fmtWeekdays(days.keys.toSet()),
      ].join(' · ');
    case ClassConfig(
      :final weekdays,
      :final start,
      :final end,
      :final place,
      :final who,
    ):
      return [
        fmtWeekdays(weekdays),
        fmtRange(start, end),
        if (who != 'أنا') who,
        if (place != null && place.isNotEmpty) place,
      ].join(' · ');
    case RemindersConfig(
      :final water,
      :final cups,
      :final stand,
      :final breathe,
    ):
      return [
        if (water) 'الماء $cups أكواب مع الوجبات والاستراحة',
        if (stand) 'الوقوف',
        if (breathe) 'التنفّس',
      ].join(' · ');
    case SavingsConfig(:final payDay, :final monthly, :final target):
      return [
        'يوم $payDay من كل شهر',
        '${fmtThousands(monthly)} ريال',
        if (target != null) 'الهدف ${fmtThousands(target)}',
      ].join(' · ');
  }
}
