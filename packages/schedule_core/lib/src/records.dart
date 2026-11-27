import 'day.dart';
import 'rules.dart';

/// حالات العنصر.
enum ItemStatus {
  /// لم يُسجّل بعد. في المقام.
  pending,

  /// تمت، مع وقت التنفيذ الفعلي. بسط ومقام.
  done,

  /// محسوبة بنمط «تُحسب ما لم أستثنها». بسط ومقام.
  auto,

  /// لم تُسجّل حتى نهاية اليوم. مقام فقط.
  missed,

  /// «لم أنفّذها». مقام فقط.
  notDone,

  /// مستثناة بقرار المستخدم. خارج النسبة.
  skipped,

  /// مؤجلة إلى موعد آخر. خارج النسبة.
  postponed,

  /// قبل انضمامك. خارج النسبة.
  preJoin,
}

/// ما يضاف من «+ إضافة».
enum OneOffKind {
  task('مهمة'),
  period('فترة'),
  event('حدث'),
  reminder('تذكير قصير'),
  habitSession('جلسة لعادة');

  const OneOffKind(this.label);
  final String label;
}

class OneOff {
  const OneOff({
    required this.id,
    required this.kind,
    required this.title,
    required this.date,
    this.start,
    this.duration = 30,
    this.window = Window.any,
    this.habitKey,
    this.note,
    this.icon,
    this.preferred,
  });

  final String id;
  final OneOffKind kind;
  final String title;
  final Day date;

  /// فارغة = مرن، يضعه المحرك.
  final int? start;
  final int duration;
  final Window window;

  /// للجلسة الإضافية: مفتاح العادة.
  final String? habitKey;
  final String? note;

  /// رمز البطاقة (مثل أعمال الجمعة). فارغ = حسب النوع.
  final String? icon;

  /// وقت مفضل للمرن.
  final int? preferred;

  String get itemKey => 'once:$id';

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'date': date.key,
    'start': start,
    'duration': duration,
    'window': window.name,
    'habitKey': habitKey,
    'note': note,
    'icon': icon,
    'preferred': preferred,
  };

  factory OneOff.fromJson(Map<String, Object?> j) => OneOff(
    id: j['id']! as String,
    kind: OneOffKind.values.byName(j['kind']! as String),
    title: j['title']! as String,
    date: Day.parse(j['date']! as String),
    start: j['start'] as int?,
    duration: (j['duration'] as int?) ?? 30,
    window: Window.values.byName((j['window'] as String?) ?? 'any'),
    habitKey: j['habitKey'] as String?,
    note: j['note'] as String?,
    icon: j['icon'] as String?,
    preferred: j['preferred'] as int?,
  );
}

/// «هذه المرة فقط»: تعديل على (date, itemKey).
class DayOverride {
  const DayOverride({
    required this.date,
    required this.itemKey,
    this.start,
    this.off = false,
    this.reason,
  });
  final Day date;
  final String itemKey;

  /// بداية جديدة للعنصر في هذا اليوم.
  final int? start;

  /// إلغاء العنصر الثابت اليوم (إجازة من الدوام مثلًا).
  final bool off;
  final String? reason;

  Map<String, Object?> toJson() => {
    'date': date.key,
    'itemKey': itemKey,
    'start': start,
    'off': off,
    'reason': reason,
  };
  factory DayOverride.fromJson(Map<String, Object?> j) => DayOverride(
    date: Day.parse(j['date']! as String),
    itemKey: j['itemKey']! as String,
    start: j['start'] as int?,
    off: (j['off'] as bool?) ?? false,
    reason: j['reason'] as String?,
  );
}

/// عنصر مؤجل إلى يوم آخر.
class CarryOver {
  const CarryOver({
    required this.id,
    required this.fromDate,
    required this.itemKey,
    required this.title,
    required this.duration,
    required this.toDate,
    this.start,
    this.counted = true,
  });
  final String id;
  final Day fromDate;
  final String itemKey;
  final String title;
  final int duration;
  final Day toDate;
  final int? start;
  final bool counted;

  String get newKey => 'carry:${fromDate.key}:$itemKey';

  Map<String, Object?> toJson() => {
    'id': id,
    'fromDate': fromDate.key,
    'itemKey': itemKey,
    'title': title,
    'duration': duration,
    'toDate': toDate.key,
    'start': start,
    'counted': counted,
  };
  factory CarryOver.fromJson(Map<String, Object?> j) => CarryOver(
    id: j['id']! as String,
    fromDate: Day.parse(j['fromDate']! as String),
    itemKey: j['itemKey']! as String,
    title: j['title']! as String,
    duration: j['duration']! as int,
    toDate: Day.parse(j['toDate']! as String),
    start: j['start'] as int?,
    counted: (j['counted'] as bool?) ?? true,
  );
}

/// سجل ما تم فعلًا لعنصر في يوم (Occurrence). مفتاحه (date, itemKey)
/// فالكتابة idempotent ولا تسجيل مزدوج.
class ItemLog {
  const ItemLog({
    required this.date,
    required this.itemKey,
    required this.status,
    this.plannedStart,
    this.plannedEnd,
    this.doneAt,
    this.actualSeconds,
    this.value,
    this.value2,
    this.timerStartedAt,
    this.timerAccumSeconds = 0,
    this.category,
    this.title,
  });

  final Day date;
  final String itemKey;
  final ItemStatus status;

  /// الوقت المخطط وقت التسجيل، منفصل عن وقت التنفيذ.
  final int? plannedStart;
  final int? plannedEnd;

  /// دقيقة التنفيذ الفعلية.
  final int? doneAt;

  /// مدة المؤقت الفعلية.
  final int? actualSeconds;

  /// قيمة: صفحات (من/إلى) أو عدد أكواب الماء.
  final int? value;
  final int? value2;

  /// مؤقت يعمل: لحظة البدء (millisecondsSinceEpoch) والمتراكم.
  final int? timerStartedAt;
  final int timerAccumSeconds;

  /// للتقارير: الفئة والعنوان وقت الإقفال.
  final String? category;
  final String? title;

  bool get timerRunning => timerStartedAt != null;

  ItemLog copyWith({
    ItemStatus? status,
    int? plannedStart,
    int? plannedEnd,
    int? doneAt,
    bool clearDoneAt = false,
    int? actualSeconds,
    int? value,
    int? value2,
    int? timerStartedAt,
    bool clearTimer = false,
    int? timerAccumSeconds,
    String? category,
    String? title,
  }) => ItemLog(
    date: date,
    itemKey: itemKey,
    status: status ?? this.status,
    plannedStart: plannedStart ?? this.plannedStart,
    plannedEnd: plannedEnd ?? this.plannedEnd,
    doneAt: clearDoneAt ? null : (doneAt ?? this.doneAt),
    actualSeconds: actualSeconds ?? this.actualSeconds,
    value: value ?? this.value,
    value2: value2 ?? this.value2,
    timerStartedAt: clearTimer ? null : (timerStartedAt ?? this.timerStartedAt),
    timerAccumSeconds: timerAccumSeconds ?? this.timerAccumSeconds,
    category: category ?? this.category,
    title: title ?? this.title,
  );

  Map<String, Object?> toJson() => {
    'date': date.key,
    'itemKey': itemKey,
    'status': status.name,
    'plannedStart': plannedStart,
    'plannedEnd': plannedEnd,
    'doneAt': doneAt,
    'actualSeconds': actualSeconds,
    'value': value,
    'value2': value2,
    'timerStartedAt': timerStartedAt,
    'timerAccumSeconds': timerAccumSeconds,
    'category': category,
    'title': title,
  };

  factory ItemLog.fromJson(Map<String, Object?> j) => ItemLog(
    date: Day.parse(j['date']! as String),
    itemKey: j['itemKey']! as String,
    status: ItemStatus.values.byName(j['status']! as String),
    plannedStart: j['plannedStart'] as int?,
    plannedEnd: j['plannedEnd'] as int?,
    doneAt: j['doneAt'] as int?,
    actualSeconds: j['actualSeconds'] as int?,
    value: j['value'] as int?,
    value2: j['value2'] as int?,
    timerStartedAt: j['timerStartedAt'] as int?,
    timerAccumSeconds: (j['timerAccumSeconds'] as int?) ?? 0,
    category: j['category'] as String?,
    title: j['title'] as String?,
  );
}

/// مفتاح (date, itemKey) للخرائط.
String recordKey(Day date, String itemKey) => '${date.key}|$itemKey';
