import 'day.dart';
import 'prayer.dart';
import 'records.dart';
import 'rules.dart';

/// نوع العنصر المولّد، يحدد شكل البطاقة وإجراءها.
enum ItemKind {
  prayer,
  adhkar,
  quran,
  habit,
  meal,
  work,
  kid,
  klass,
  task,
  period,
  event,
  contact,
  savings,
}

/// عنصر واحد في خطة اليوم.
class PlanItem {
  const PlanItem({
    required this.key,
    this.ruleKey,
    required this.kind,
    required this.title,
    this.subtitle,
    this.icon = 'star',
    required this.start,
    required this.end,
    required this.fixed,
    required this.counted,
    this.optional = false,
    required this.track,
    this.status = ItemStatus.pending,
    this.doneAt,
    this.category = 'other',
    this.isExtra = false,
    this.manual = false,
    this.outsideWindow = false,
    this.workBreak,
    this.pagesFrom,
    this.pagesTo,
    this.book,
    this.carriedFrom,
    this.oneOffId,
    this.window,
    this.log,
    this.subs = const [],
    this.personId,
  });

  /// المفتاح الثابت (date, itemKey) مثل habit:read#2 أو prayer:fajr.
  final String key;
  final String? ruleKey;
  final ItemKind kind;
  final String title;
  final String? subtitle;
  final String icon;
  final int start;
  final int end;

  /// الثابت لا يحرّكه المحرك أبدًا.
  final bool fixed;
  final bool counted;
  final bool optional;
  final TrackMode track;
  final ItemStatus status;
  final int? doneAt;
  final String category;

  /// جلسة إضافية: تدخل العدّ فقط عندما تتم.
  final bool isExtra;

  /// له تعديل يدوي لهذا اليوم.
  final bool manual;

  /// وُضع خارج النافذة المفضلة لأنها ممتلئة.
  final bool outsideWindow;
  final Span? workBreak;
  final int? pagesFrom;
  final int? pagesTo;
  final String? book;
  final Day? carriedFrom;
  final String? oneOffId;
  final Window? window;
  final ItemLog? log;

  /// بنود فرعية داخل البطاقة (السنن الرواتب). لا تدخل في نسبة الإنجاز.
  final List<SubItem> subs;

  /// لبطاقات التواصل: الشخص المقترح.
  final String? personId;

  int get duration => end - start;
  Span get span => Span(start, end);

  bool get isDoneLike => status == ItemStatus.done || status == ItemStatus.auto;
  bool get isClosed =>
      isDoneLike ||
      status == ItemStatus.notDone ||
      status == ItemStatus.skipped ||
      status == ItemStatus.postponed ||
      status == ItemStatus.preJoin;

  /// يدخل في مقام الإنجاز؟
  bool get inDenominator {
    if (!counted) return false;
    if (status == ItemStatus.skipped ||
        status == ItemStatus.postponed ||
        status == ItemStatus.preJoin) {
      return false;
    }
    if (isExtra && !isDoneLike) return false;
    return true;
  }

  PlanItem copyWith({
    int? start,
    int? end,
    ItemStatus? status,
    bool? manual,
    ItemLog? log,
  }) => PlanItem(
    key: key,
    ruleKey: ruleKey,
    kind: kind,
    title: title,
    subtitle: subtitle,
    icon: icon,
    start: start ?? this.start,
    end: end ?? this.end,
    fixed: fixed,
    counted: counted,
    optional: optional,
    track: track,
    status: status ?? this.status,
    doneAt: doneAt,
    category: category,
    isExtra: isExtra,
    manual: manual ?? this.manual,
    outsideWindow: outsideWindow,
    workBreak: workBreak,
    pagesFrom: pagesFrom,
    pagesTo: pagesTo,
    book: book,
    carriedFrom: carriedFrom,
    oneOffId: oneOffId,
    window: window,
    log: log ?? this.log,
    subs: subs,
    personId: personId,
  );

  @override
  String toString() => '$key[$start-$end ${status.name}]';
}

/// بند فرعي يُسجَّل بمفتاحه الخاص.
class SubItem {
  const SubItem({
    required this.key,
    required this.title,
    required this.detail,
    this.done = false,
  });
  final String key;
  final String title;
  final String detail;
  final bool done;
}

enum LineKind { water, stand, breathe, custom, sleep }

/// الخطوط الخفيفة: لا تحجز وقتًا ولا تُحسب.
class ReminderLine {
  const ReminderLine({
    required this.key,
    required this.kind,
    required this.minute,
    required this.title,
    this.done = false,
  });
  final String key;
  final LineKind kind;
  final int minute;
  final String title;
  final bool done;
}

/// تداخل بين ثابتين: يظهر شريطًا «عدّل هذا أو ذاك».
class Conflict {
  const Conflict(this.a, this.b);
  final PlanItem a;
  final PlanItem b;
}

enum UnplacedReason {
  noTime('ما لقت وقت'),
  cap('وصلت حد وقتك الاختياري');

  const UnplacedReason(this.label);
  final String label;
}

class Unplaced {
  const Unplaced(
    this.key,
    this.title,
    this.reason, {
    this.ruleKey,
    this.duration = 0,
  });
  final String key;
  final String title;
  final UnplacedReason reason;
  final String? ruleKey;
  final int duration;
}

/// سبب حجز فترة.
enum BusyKind { sleep, work, fixed, flex }

class Busy {
  const Busy(this.span, this.kind, this.label, {this.key});
  final Span span;
  final BusyKind kind;
  final String label;
  final String? key;
}

/// خطة يوم كاملة: نتيجة المحرك.
class DayPlan {
  DayPlan({
    required this.date,
    required this.items,
    required this.lines,
    required this.conflicts,
    required this.unplaced,
    required this.busy,
    required this.prayers,
    required this.wake,
    required this.bedtime,
    this.workOff = false,
  });

  final Day date;

  /// مرتبة بوقت البداية.
  final List<PlanItem> items;
  final List<ReminderLine> lines;
  final List<Conflict> conflicts;
  final List<Unplaced> unplaced;

  /// كل الفترات المحجوزة (نوم، دوام خارج الاستراحة، ثابت، مرن موضوع).
  final List<Busy> busy;
  final DayPrayers prayers;
  final int wake;
  final int bedtime;
  final bool workOff;

  PlanItem? byKey(String key) {
    for (final i in items) {
      if (i.key == key) return i;
    }
    return null;
  }

  bool hasKey(String key) => items.any((i) => i.key == key);
}
