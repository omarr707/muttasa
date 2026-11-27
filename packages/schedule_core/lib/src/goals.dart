import 'dart:math' as math;

import 'day.dart';
import 'engine.dart';
import 'records.dart';
import 'recurrence.dart';
import 'rules.dart';

/// بماذا نقيس الهدف.
enum GoalMetric {
  pages('صفحات', 'صفحة', 'book'),
  books('كتب', 'كتاب', 'book'),
  sessions('جلسات عادة', 'جلسة', 'star'),
  money('مبلغ ادخار', 'ريال', 'coin'),
  count('عدد أسجّله بنفسي', 'مرة', 'flag'),

  /// الختمة: تُشتق من ورد القرآن، ولا تُنشأ يدويًا.
  khatma('ختمة', 'صفحة', 'book');

  const GoalMetric(this.label, this.unit, this.icon);
  final String label;
  final String unit;
  final String icon;

  /// الأنواع التي يختارها المستخدم في «هدف جديد».
  static const pickable = [pages, books, sessions, money, count];

  /// يقبل عادة تغذيه؟
  bool get linkable => this == pages || this == sessions || this == books;

  /// يُسجَّل يدويًا من بطاقة الهدف (+١).
  bool get manual => this == books || this == count;
}

/// تسجيل يدوي على هدف (كتاب خلص، حديث حفظته...).
class GoalEntry {
  const GoalEntry(this.date, this.value);
  final Day date;
  final int value;
  Map<String, Object?> toJson() => {'d': date.key, 'v': value};
  factory GoalEntry.fromJson(Map<String, Object?> j) =>
      GoalEntry(Day.parse(j['d']! as String), j['v']! as int);
}

/// هدف بالنتيجة والموعد: «أقرأ 12 كتاب هالسنة».
class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.metric,
    required this.target,
    required this.start,
    this.due,
    this.unit,
    this.linkKey,
    this.entries = const [],
    this.base = 0,
    this.derived = false,
  });

  final String id;
  final String title;
  final GoalMetric metric;
  final int target;
  final Day start;

  /// الموعد (اختياري).
  final Day? due;

  /// وحدة مخصصة لهدف «عدد» (حديث، دورة...).
  final String? unit;

  /// مفتاح العادة التي تغذيه (مثل habit:read).
  final String? linkKey;
  final List<GoalEntry> entries;

  /// نقطة البداية (للختمة: الصفحة التي بدأت منها).
  final int base;

  /// مشتق من الروتين (الختمة، هدف الادخار): لا يُحذف من «أهدافي».
  final bool derived;

  String unitLabel([String currency = 'ريال']) =>
      unit ?? (metric == GoalMetric.money ? currency : metric.unit);

  Goal copyWith({
    String? title,
    GoalMetric? metric,
    int? target,
    Day? start,
    Day? due,
    bool clearDue = false,
    String? unit,
    String? linkKey,
    bool clearLink = false,
    List<GoalEntry>? entries,
  }) => Goal(
    id: id,
    title: title ?? this.title,
    metric: metric ?? this.metric,
    target: target ?? this.target,
    start: start ?? this.start,
    due: clearDue ? null : (due ?? this.due),
    unit: unit ?? this.unit,
    linkKey: clearLink ? null : (linkKey ?? this.linkKey),
    entries: entries ?? this.entries,
    base: base,
    derived: derived,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'metric': metric.name,
    'target': target,
    'start': start.key,
    'due': due?.key,
    'unit': unit,
    'linkKey': linkKey,
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  factory Goal.fromJson(Map<String, Object?> j) => Goal(
    id: j['id']! as String,
    title: j['title']! as String,
    metric: GoalMetric.values.byName((j['metric'] as String?) ?? 'count'),
    target: j['target']! as int,
    start: Day.parse(j['start']! as String),
    due: j['due'] == null ? null : Day.parse(j['due']! as String),
    unit: j['unit'] as String?,
    linkKey: j['linkKey'] as String?,
    entries: ((j['entries'] as List?) ?? const [])
        .map((e) => GoalEntry.fromJson((e as Map).cast<String, Object?>()))
        .toList(),
  );
}

/// قوالب «هدف جديد».
class GoalTemplate {
  const GoalTemplate(
    this.title,
    this.metric,
    this.target,
    this.days, {
    this.linkKey,
    this.unit,
  });
  final String title;
  final GoalMetric metric;
  final int target;
  final int days;
  final String? linkKey;
  final String? unit;
}

const goalTemplates = [
  GoalTemplate(
    'أقرأ 12 كتاب هالسنة',
    GoalMetric.books,
    12,
    365,
    linkKey: 'habit:read',
  ),
  GoalTemplate(
    'أقرأ 3000 صفحة',
    GoalMetric.pages,
    3000,
    180,
    linkKey: 'habit:read',
  ),
  GoalTemplate('أدّخر 10,000 ريال', GoalMetric.money, 10000, 365),
  GoalTemplate(
    'أمشي 100 مرة',
    GoalMetric.sessions,
    100,
    90,
    linkKey: 'habit:walk',
  ),
  GoalTemplate('أحفظ 30 حديث', GoalMetric.count, 30, 90, unit: 'حديث'),
];

/// حالة الهدف: واحدة من «على الخط / متأخر / ما يكفي / تحقق».
enum GoalState {
  onTrack('على الخط'),
  behind('متأخر'),
  notEnough('ما يكفي'),
  achieved('تحقق'),
  noDue('بدون موعد'),
  expired('انتهى الموعد');

  const GoalState(this.label);
  final String label;

  bool get good => this == onTrack || this == achieved;
  bool get late => this == behind || this == notEnough || this == expired;
}

class GoalStatus {
  const GoalStatus({
    required this.goal,
    required this.value,
    required this.state,
    required this.message,
    this.expected,
  });
  final Goal goal;
  final int value;
  final GoalState state;

  /// سطر الشرح تحت البطاقة (بأرقام لاتينية، الواجهة تحوّلها).
  final String message;

  /// أين المفروض تكون اليوم (لعلامة على شريط التقدم).
  final double? expected;

  int get target => goal.target;
  double get ratio => target <= 0 ? 0 : (value / target).clamp(0, 1).toDouble();
}

/// قراءة الأهداف من سجلات المحرك. كل إجراء على بطاقة يحدّث الهدف فورًا.
extension GoalsOnEngine on ScheduleEngine {
  bool _ofRule(String itemKey, String ruleKey) =>
      itemKey == ruleKey || itemKey.startsWith('$ruleKey#');

  /// القيمة الحالية للهدف.
  int goalValue(Goal g) {
    final today = input.today;
    switch (g.metric) {
      case GoalMetric.books:
      case GoalMetric.count:
        return g.entries
            .where((e) => !e.date.isBefore(g.start))
            .fold(0, (a, e) => a + e.value);
      case GoalMetric.pages:
        if (g.linkKey == null) return 0;
        var n = 0;
        for (final l in input.logs.values) {
          if (!_ofRule(l.itemKey, g.linkKey!)) continue;
          if (l.status != ItemStatus.done || l.date.isBefore(g.start)) continue;
          if (l.value == null || l.value2 == null) continue;
          n += l.value2! - l.value! + 1;
        }
        return n;
      case GoalMetric.sessions:
        if (g.linkKey == null) return 0;
        final extras = {
          for (final o in input.oneOffs)
            if (o.habitKey == g.linkKey) o.itemKey,
        };
        var n = 0;
        for (final l in input.logs.values) {
          if (l.status != ItemStatus.done && l.status != ItemStatus.auto) {
            continue;
          }
          if (l.date.isBefore(g.start) || l.date.isAfter(today)) continue;
          if (_ofRule(l.itemKey, g.linkKey!) || extras.contains(l.itemKey)) {
            n++;
          }
        }
        return n;
      case GoalMetric.money:
        return savedSince(g.start);
      case GoalMetric.khatma:
        final r = input.rules.where((r) => r.key == g.linkKey).toList();
        if (r.isEmpty) return g.base;
        return math.max(g.base, lastPageBefore(today.next, r.last));
    }
  }

  /// مجموع ما سُجّل ادخارًا من [from].
  int savedSince(Day from) {
    var n = 0;
    for (final l in input.logs.values) {
      if (l.itemKey != 'savings' && !l.itemKey.startsWith('savings:')) {
        continue;
      }
      if (l.status != ItemStatus.done || l.date.isBefore(from)) continue;
      n += l.value ?? 0;
    }
    return n;
  }

  /// كم جلسة بالأسبوع تسمح بها العادة المرتبطة حاليًا.
  int? weeklyRate(String? ruleKey) {
    if (ruleKey == null) return null;
    final r = rulesOn(input.today).where((r) => r.key == ruleKey).toList();
    if (r.isEmpty || r.first.config is! FlexConfig) return null;
    final c = r.first.config as FlexConfig;
    final per = c.perDay.clamp(1, 3);
    return switch (c.recurrence) {
      Daily() => 7 * per,
      Weekdays(:final days) => days.length * per,
      TimesPerWeek(:final n) => n * per,
      Once() => 0,
    };
  }

  /// الأهداف المشتقة من الروتين: الختمة، وهدف الادخار إن لم يضع المستخدم هدفًا للمال.
  List<Goal> derivedGoals(List<Goal> userGoals) {
    final out = <Goal>[];
    for (final r in rulesOn(input.today, includePaused: true)) {
      final c = r.config;
      if (c is FlexConfig && c.kind == RuleKind.quran && c.isKhatma) {
        // بداية الختمة: أول نسخة من القاعدة فيها موعد الختم نفسه.
        var start = r.validFrom;
        for (final o in input.rules) {
          if (o.key != r.key || o.config is! FlexConfig) continue;
          if ((o.config as FlexConfig).khatmaBy == c.khatmaBy &&
              o.validFrom.isBefore(start)) {
            start = o.validFrom;
          }
        }
        out.add(
          Goal(
            id: '_khatma',
            title: 'ختمة القرآن',
            metric: GoalMetric.khatma,
            target: mushafPages,
            start: start,
            due: c.khatmaBy,
            linkKey: r.key,
            base: (c.startPage ?? 1) - 1,
            derived: true,
          ),
        );
      }
      if (c is SavingsConfig &&
          c.target != null &&
          !userGoals.any((g) => g.metric == GoalMetric.money)) {
        out.add(
          Goal(
            id: '_savings',
            title: 'الادخار',
            metric: GoalMetric.money,
            target: c.target!,
            start: r.validFrom,
            due: c.targetBy,
            linkKey: r.key,
            derived: true,
          ),
        );
      }
    }
    return out;
  }

  GoalStatus goalStatus(Goal g) {
    final today = input.today;
    final v = goalValue(g);
    final t = g.target <= 0 ? 1 : g.target;
    final u = g.unitLabel(input.profile.currency);
    if (v >= t) {
      return GoalStatus(
        goal: g,
        value: v,
        state: GoalState.achieved,
        message: 'وصلت هدفك',
      );
    }
    if (g.due == null) {
      return GoalStatus(
        goal: g,
        value: v,
        state: GoalState.noDue,
        message: 'باقي ${fmtThousands(t - v)} $u',
      );
    }
    final due = g.due!;
    final span = math.max(1, due.difference(g.start) + 1);
    final elapsed = math.min(span, math.max(0, today.difference(g.start)));
    final left = due.difference(today) + 1;
    if (left <= 0) {
      return GoalStatus(
        goal: g,
        value: v,
        state: GoalState.expired,
        message: 'وصلت ${fmtThousands(v)} من ${fmtThousands(t)}',
      );
    }
    final exp = g.base + (t - g.base) * elapsed / span;
    final need = (t - v) / left;
    final needText = need >= 1
        ? '${fmtThousands(need.ceil())} $u باليوم'
        : need * 7 >= 1
        ? '${fmtThousands((need * 7).ceil())} $u بالأسبوع'
        : '1 $u كل ${(1 / need).floor()} يوم';

    var warn = '';
    if (g.metric == GoalMetric.sessions) {
      final wr = weeklyRate(g.linkKey);
      if (wr != null) {
        final reach = (v + wr * left / 7).floor();
        if (reach < t) {
          warn =
              ' · بمعدل عادتك ($wr بالأسبوع) توصل ${fmtThousands(reach)} بس. زِد تكرار العادة';
        }
      }
    }
    if (v >= exp * 0.9) {
      return GoalStatus(
        goal: g,
        value: v,
        state: warn.isEmpty ? GoalState.onTrack : GoalState.notEnough,
        message: 'باقي $left يوم · يكفيك $needText$warn',
        expected: exp,
      );
    }
    return GoalStatus(
      goal: g,
      value: v,
      state: GoalState.behind,
      message:
          'المفروض توصل ${fmtThousands(exp.floor())} الحين · تحتاج $needText$warn',
      expected: exp,
    );
  }
}

/// «10,000» بفواصل الآلاف.
String fmtThousands(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}
