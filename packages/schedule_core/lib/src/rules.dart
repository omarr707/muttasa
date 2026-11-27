import 'day.dart';
import 'recurrence.dart';

/// نوافذ الجلسات المفضلة.
enum Window {
  afterFajr('بعد الفجر'),
  morning('الصباح'),
  afternoon('العصر والمغرب'),
  night('الليل'),
  any('أي وقت');

  const Window(this.label);
  final String label;
}

/// أنماط التتبع.
enum TrackMode {
  /// تمرّ بدون تسجيل، خارج النسبة (الدوام، الأحداث، الفترات الثابتة).
  auto,

  /// ابدأ / أوقف مؤقتًا / أنهِ (المشي، العمل الحر، العادات بمؤقت).
  start,

  /// تأكيد سريع من البطاقة أو التنبيه.
  confirm,

  /// «تُحسب ما لم أستثنها»: تصير auto عند إقفال اليوم.
  autocount,

  /// نقرة واحدة، خارج النسبة (الماء والوقوف والتنفس).
  quick,
}

enum RuleKind {
  prayers,
  adhkar,
  quran,
  habit,
  meal,
  work,
  kid,
  klass,
  reminders,
  savings,
  health,
  mother,
}

/// قاعدة مؤرّخة. «من اليوم فصاعدًا» يغلق الصف القديم ويفتح صفًا جديدًا
/// بنفس [key]، فالأيام السابقة تُولّد بقواعدها الأصلية.
class Rule {
  const Rule({
    required this.id,
    required this.key,
    required this.validFrom,
    this.validTo,
    this.pausedFrom,
    this.pausedUntil,
    required this.config,
  });

  /// معرّف الصف (UUID)، فريد لكل نسخة.
  final String id;

  /// المفتاح الثابت عبر النسخ، مثل `habit:walk` أو `prayers`.
  final String key;
  final Day validFrom;

  /// آخر يوم تسري فيه هذه النسخة (شامل). null = مفتوحة.
  final Day? validTo;

  /// وضع الإيقاف المؤقت: من [pausedFrom] حتى [pausedUntil] شامل.
  /// [pausedUntil] = null مع [pausedFrom] = إيقاف مفتوح.
  final Day? pausedFrom;
  final Day? pausedUntil;
  final RuleConfig config;

  RuleKind get kind => config.kind;

  bool activeOn(Day d) =>
      !d.isBefore(validFrom) && (validTo == null || !d.isAfter(validTo!));

  bool pausedOn(Day d) =>
      pausedFrom != null &&
      !d.isBefore(pausedFrom!) &&
      (pausedUntil == null || !d.isAfter(pausedUntil!));

  Rule copyWith({
    String? id,
    Day? validFrom,
    Day? validTo,
    bool clearValidTo = false,
    Day? pausedFrom,
    Day? pausedUntil,
    bool clearPause = false,
    RuleConfig? config,
  }) => Rule(
    id: id ?? this.id,
    key: key,
    validFrom: validFrom ?? this.validFrom,
    validTo: clearValidTo ? null : (validTo ?? this.validTo),
    pausedFrom: clearPause ? null : (pausedFrom ?? this.pausedFrom),
    pausedUntil: clearPause ? null : (pausedUntil ?? this.pausedUntil),
    config: config ?? this.config,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'key': key,
    'validFrom': validFrom.key,
    'validTo': validTo?.key,
    'pausedFrom': pausedFrom?.key,
    'pausedUntil': pausedUntil?.key,
    'config': config.toJson(),
  };

  factory Rule.fromJson(Map<String, Object?> j) => Rule(
    id: j['id']! as String,
    key: j['key']! as String,
    validFrom: Day.parse(j['validFrom']! as String),
    validTo: j['validTo'] == null ? null : Day.parse(j['validTo']! as String),
    pausedFrom: j['pausedFrom'] == null
        ? null
        : Day.parse(j['pausedFrom']! as String),
    pausedUntil: j['pausedUntil'] == null
        ? null
        : Day.parse(j['pausedUntil']! as String),
    config: RuleConfig.fromJson((j['config']! as Map).cast<String, Object?>()),
  );
}

sealed class RuleConfig {
  const RuleConfig();
  RuleKind get kind;
  Map<String, Object?> toJson();

  static RuleConfig fromJson(Map<String, Object?> j) {
    final kind = RuleKind.values.byName(j['kind']! as String);
    switch (kind) {
      case RuleKind.prayers:
        return PrayersConfig.fromJson(j);
      case RuleKind.adhkar:
        return AdhkarConfig.fromJson(j);
      case RuleKind.quran:
      case RuleKind.habit:
      case RuleKind.meal:
        return FlexConfig.fromJson(j);
      case RuleKind.work:
        return WorkConfig.fromJson(j);
      case RuleKind.kid:
        return KidConfig.fromJson(j);
      case RuleKind.klass:
        return ClassConfig.fromJson(j);
      case RuleKind.reminders:
        return RemindersConfig.fromJson(j);
      case RuleKind.savings:
        return SavingsConfig.fromJson(j);
      case RuleKind.health:
        return HealthConfig.fromJson(j);
      case RuleKind.mother:
        return MotherConfig.fromJson(j);
    }
  }
}

/// الصلوات الخمس (والجمعة). الأوقات من السياق.
class PrayersConfig extends RuleConfig {
  const PrayersConfig({
    this.place = 'في المسجد القريب',
    this.track = TrackMode.confirm,
    this.sunnah = const [],
  });
  final String place;
  final TrackMode track;

  /// السنن الرواتب المفعّلة: fajr, dhuhr, maghrib, isha, witr.
  final List<String> sunnah;
  @override
  RuleKind get kind => RuleKind.prayers;
  PrayersConfig copyWith({
    String? place,
    TrackMode? track,
    List<String>? sunnah,
  }) => PrayersConfig(
    place: place ?? this.place,
    track: track ?? this.track,
    sunnah: sunnah ?? this.sunnah,
  );
  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'place': place,
    'track': track.name,
    if (sunnah.isNotEmpty) 'sunnah': sunnah,
  };
  factory PrayersConfig.fromJson(Map<String, Object?> j) => PrayersConfig(
    place: (j['place'] as String?) ?? '',
    track: TrackMode.values.byName((j['track'] as String?) ?? 'confirm'),
    sunnah: ((j['sunnah'] as List?) ?? const []).cast<String>().toList(),
  );
}

/// السنن الرواتب لكل صلاة: (المعرّف، العنوان، التفصيل).
const sunnahOf = <String, List<(String, String, String)>>{
  'fajr': [('fajr', 'سنة الفجر', 'ركعتان قبل الصلاة')],
  'dhuhr': [
    ('dhuhr_before', 'سنة الظهر القبلية', 'أربع ركعات'),
    ('dhuhr_after', 'سنة الظهر البعدية', 'ركعتان'),
  ],
  'maghrib': [('maghrib', 'سنة المغرب', 'ركعتان بعد الصلاة')],
  'isha': [('isha', 'سنة العشاء', 'ركعتان بعد الصلاة')],
  'witr': [('witr', 'الوتر', 'ركعة أو أكثر قبل النوم')],
};

class AdhkarConfig extends RuleConfig {
  const AdhkarConfig({
    this.morning = true,
    this.evening = true,
    this.minutes = 10,
  });
  final bool morning;
  final bool evening;
  final int minutes;
  @override
  RuleKind get kind => RuleKind.adhkar;
  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'morning': morning,
    'evening': evening,
    'minutes': minutes,
  };
  factory AdhkarConfig.fromJson(Map<String, Object?> j) => AdhkarConfig(
    morning: (j['morning'] as bool?) ?? true,
    evening: (j['evening'] as bool?) ?? true,
    minutes: (j['minutes'] as int?) ?? 10,
  );
}

/// عنصر مرن: عادة، ورد قرآن، وجبة.
class FlexConfig extends RuleConfig {
  const FlexConfig({
    required this.kind,
    required this.title,
    this.subtitle,
    this.icon = 'star',
    this.recurrence = const Daily(),
    required this.duration,
    this.windows = const [Window.any],
    this.preferred,
    this.perDay = 1,
    this.track = TrackMode.confirm,
    this.optional = false,
    this.counted = true,
    this.category = 'habits',
    this.pages,
    this.book,
    this.startPage,
    this.khatmaBy,
  });

  @override
  final RuleKind kind;
  final String title;
  final String? subtitle;
  final String icon;
  final Recurrence recurrence;
  final int duration;

  /// نافذة لكل جلسة بالترتيب. الجلسات الزائدة تأخذ آخر نافذة.
  final List<Window> windows;

  /// الوقت المفضل (دقيقة من منتصف الليل). يُحدَّث بـ «من اليوم فصاعدًا».
  final int? preferred;

  /// 1 إلى 3 جلسات باليوم.
  final int perDay;
  final TrackMode track;

  /// اختياري = يدخل في الحد اليومي للوقت الاختياري (180 دقيقة افتراضيًا).
  final bool optional;
  final bool counted;
  final String category;

  /// للقراءة والورد: صفحات اليوم، اسم الكتاب، صفحة البداية.
  final int? pages;
  final String? book;
  final int? startPage;

  /// ختمة: آخر يوم للختم. صفحات اليوم تُحسب من المتبقي ÷ أيام القراءة الباقية،
  /// وتتعدل مع كل تسجيل. null = ورد ثابت بعدد [pages].
  final Day? khatmaBy;

  bool get isKhatma => khatmaBy != null;

  Window windowFor(int session) => windows.isEmpty
      ? Window.any
      : windows[session.clamp(0, windows.length - 1)];

  FlexConfig copyWith({
    String? title,
    String? subtitle,
    String? icon,
    Recurrence? recurrence,
    int? duration,
    List<Window>? windows,
    int? preferred,
    bool clearPreferred = false,
    int? perDay,
    TrackMode? track,
    bool? optional,
    bool? counted,
    int? pages,
    String? book,
    int? startPage,
    Day? khatmaBy,
    bool clearKhatma = false,
  }) => FlexConfig(
    kind: kind,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    icon: icon ?? this.icon,
    recurrence: recurrence ?? this.recurrence,
    duration: duration ?? this.duration,
    windows: windows ?? this.windows,
    preferred: clearPreferred ? null : (preferred ?? this.preferred),
    perDay: perDay ?? this.perDay,
    track: track ?? this.track,
    optional: optional ?? this.optional,
    counted: counted ?? this.counted,
    category: category,
    pages: pages ?? this.pages,
    book: book ?? this.book,
    startPage: startPage ?? this.startPage,
    khatmaBy: clearKhatma ? null : (khatmaBy ?? this.khatmaBy),
  );

  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'title': title,
    'subtitle': subtitle,
    'icon': icon,
    'recurrence': recurrence.toJson(),
    'duration': duration,
    'windows': windows.map((w) => w.name).toList(),
    'preferred': preferred,
    'perDay': perDay,
    'track': track.name,
    'optional': optional,
    'counted': counted,
    'category': category,
    'pages': pages,
    'book': book,
    'startPage': startPage,
    if (khatmaBy != null) 'khatmaBy': khatmaBy!.key,
  };

  factory FlexConfig.fromJson(Map<String, Object?> j) => FlexConfig(
    kind: RuleKind.values.byName(j['kind']! as String),
    title: j['title']! as String,
    subtitle: j['subtitle'] as String?,
    icon: (j['icon'] as String?) ?? 'star',
    recurrence: Recurrence.fromJson(
      (j['recurrence']! as Map).cast<String, Object?>(),
    ),
    duration: j['duration']! as int,
    windows: ((j['windows'] as List?) ?? const ['any'])
        .map((w) => Window.values.byName(w as String))
        .toList(),
    preferred: j['preferred'] as int?,
    perDay: (j['perDay'] as int?) ?? 1,
    track: TrackMode.values.byName((j['track'] as String?) ?? 'confirm'),
    optional: (j['optional'] as bool?) ?? false,
    counted: (j['counted'] as bool?) ?? true,
    category: (j['category'] as String?) ?? 'habits',
    pages: j['pages'] as int?,
    book: j['book'] as String?,
    startPage: j['startPage'] as int?,
    khatmaBy: j['khatmaBy'] == null
        ? null
        : Day.parse(j['khatmaBy']! as String),
  );
}

/// فترة دوام. النهاية قبل البداية = وردية تعبر منتصف الليل.
/// الاستراحة فجوة متاحة داخل الدوام.
class WorkPeriod {
  const WorkPeriod(this.start, this.end, {this.breakStart, this.breakEnd});
  final int start;
  final int end;
  final int? breakStart;
  final int? breakEnd;

  bool get crossesMidnight => end <= start;
  bool get hasBreak =>
      breakStart != null && breakEnd != null && breakEnd! > breakStart!;

  Map<String, Object?> toJson() => {
    'start': start,
    'end': end,
    'breakStart': breakStart,
    'breakEnd': breakEnd,
  };
  factory WorkPeriod.fromJson(Map<String, Object?> j) => WorkPeriod(
    j['start']! as int,
    j['end']! as int,
    breakStart: j['breakStart'] as int?,
    breakEnd: j['breakEnd'] as int?,
  );
}

enum WorkPattern {
  morning('صباحي'),
  evening('مسائي'),
  night('ليلي'),
  custom('مخصص');

  const WorkPattern(this.label);
  final String label;
}

class WorkConfig extends RuleConfig {
  const WorkConfig({
    this.title = 'الدوام',
    this.pattern = WorkPattern.morning,
    required this.days,
  });
  final String title;
  final WorkPattern pattern;

  /// لكل يوم من الأسبوع (1..7) قائمة فترات.
  final Map<int, List<WorkPeriod>> days;

  @override
  RuleKind get kind => RuleKind.work;

  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'title': title,
    'pattern': pattern.name,
    'days': {
      for (final e in days.entries)
        '${e.key}': e.value.map((p) => p.toJson()).toList(),
    },
  };

  factory WorkConfig.fromJson(Map<String, Object?> j) => WorkConfig(
    title: (j['title'] as String?) ?? 'الدوام',
    pattern: WorkPattern.values.byName((j['pattern'] as String?) ?? 'custom'),
    days: {
      for (final e in ((j['days'] as Map?) ?? const {}).entries)
        int.parse(e.key as String): (e.value as List)
            .map((p) => WorkPeriod.fromJson((p as Map).cast<String, Object?>()))
            .toList(),
    },
  );
}

/// مواعيد يوم واحد للطفل: توصيل و/أو استلام.
class KidDay {
  const KidDay({this.drop, this.pick});
  final int? drop;
  final int? pick;
  Map<String, Object?> toJson() => {'drop': drop, 'pick': pick};
  factory KidDay.fromJson(Map<String, Object?> j) =>
      KidDay(drop: j['drop'] as int?, pick: j['pick'] as int?);
}

class KidConfig extends RuleConfig {
  const KidConfig({
    required this.child,
    this.place,
    this.trip = 20,
    required this.days,
  });
  final String child;
  final String? place;

  /// مدة المشوار بالدقائق.
  final int trip;
  final Map<int, KidDay> days;

  @override
  RuleKind get kind => RuleKind.kid;
  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'child': child,
    'place': place,
    'trip': trip,
    'days': {for (final e in days.entries) '${e.key}': e.value.toJson()},
  };
  factory KidConfig.fromJson(Map<String, Object?> j) => KidConfig(
    child: j['child']! as String,
    place: j['place'] as String?,
    trip: (j['trip'] as int?) ?? 20,
    days: {
      for (final e in ((j['days'] as Map?) ?? const {}).entries)
        int.parse(e.key as String): KidDay.fromJson(
          (e.value as Map).cast<String, Object?>(),
        ),
    },
  );
}

/// نوع الالتزام في «التزاماتي».
enum CommitmentType {
  university('الجامعة', 'محاضرة', 'university'),
  school('المدرسة', 'المدرسة', 'school'),
  club('النادي', 'النادي', 'gym'),
  course('دورة', 'دورة', 'course'),
  other('التزام خاص', 'التزام', 'class');

  const CommitmentType(this.label, this.defaultTitle, this.icon);
  final String label;
  final String defaultTitle;
  final String icon;
}

/// فترة واحدة داخل يوم.
class Slot {
  const Slot(this.start, this.end);
  final int start;
  final int end;
  Map<String, Object?> toJson() => {'start': start, 'end': end};
  factory Slot.fromJson(Map<String, Object?> j) =>
      Slot(j['start']! as int, j['end']! as int);
}

/// التزام أسبوعي: محاضرات، مدرسة، نادي، دورة، أو حصة.
/// [slots] (اختياري) يعطي كل يوم فتراته، ولو أكثر من فترة في اليوم.
class ClassConfig extends RuleConfig {
  const ClassConfig({
    required this.title,
    this.who = 'أنا',
    required this.weekdays,
    required this.start,
    required this.end,
    this.place,
    this.type = CommitmentType.other,
    this.slots = const {},
  });
  final String title;
  final String who;
  final Set<int> weekdays;
  final int start;
  final int end;
  final String? place;
  final CommitmentType type;
  final Map<int, List<Slot>> slots;

  /// فترات يوم [weekday]: من [slots] إن وُجدت، وإلا الوقت الموحّد.
  List<Slot> slotsOn(int weekday) {
    if (slots.isNotEmpty) return slots[weekday] ?? const [];
    return weekdays.contains(weekday) ? [Slot(start, end)] : const [];
  }

  @override
  RuleKind get kind => RuleKind.klass;
  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'title': title,
    'who': who,
    'weekdays': (weekdays.toList()..sort()),
    'start': start,
    'end': end,
    'place': place,
    'type': type.name,
    if (slots.isNotEmpty)
      'slots': {
        for (final e in slots.entries)
          '${e.key}': [for (final s in e.value) s.toJson()],
      },
  };
  factory ClassConfig.fromJson(Map<String, Object?> j) => ClassConfig(
    title: j['title']! as String,
    who: (j['who'] as String?) ?? 'أنا',
    weekdays: {...(j['weekdays']! as List).cast<int>()},
    start: j['start']! as int,
    end: j['end']! as int,
    place: j['place'] as String?,
    type: CommitmentType.values.asNameMap()[j['type']] ?? CommitmentType.other,
    slots: {
      for (final e in ((j['slots'] as Map?) ?? const {}).entries)
        int.parse(e.key as String): [
          for (final s in e.value as List)
            Slot.fromJson((s as Map).cast<String, Object?>()),
        ],
    },
  );
}

/// التذكيرات القصيرة: خطوط خفيفة لا تحجز وقتًا ولا تُحسب.
class RemindersConfig extends RuleConfig {
  const RemindersConfig({
    this.water = true,
    this.cups = 8,
    this.waterAlerts,
    this.waterDays = allWeekdays,
    this.stand = true,
    this.standEvery = 120,
    this.standDays = allWeekdays,
    this.breathe = true,
    this.breatheSlots = const {BreatheSlot.afternoon},
    this.breatheMinutes = 1,
    this.breatheDays = allWeekdays,
  });

  /// الماء: أكواب شرب فقط (لا يدخل فيها ماء الأكل). [cups] هدف التسجيل،
  /// و[waterAlerts] عدد التذكيرات (null = بعدد الأكواب).
  final bool water;
  final int cups;
  final int? waterAlerts;
  final Set<int> waterDays;

  /// الحركة: تمرين قصير كل [standEvery] دقيقة من يقظتك، في الدوام والإجازة.
  final bool stand;
  final int standEvery;
  final Set<int> standDays;

  /// التنفّس: جلسة أو أكثر يختارها المستخدم.
  final bool breathe;
  final Set<BreatheSlot> breatheSlots;
  final int breatheMinutes;
  final Set<int> breatheDays;

  int get alerts => (waterAlerts ?? cups).clamp(1, 16);

  @override
  RuleKind get kind => RuleKind.reminders;

  RemindersConfig copyWith({
    bool? water,
    int? cups,
    int? waterAlerts,
    bool clearAlerts = false,
    Set<int>? waterDays,
    bool? stand,
    int? standEvery,
    Set<int>? standDays,
    bool? breathe,
    Set<BreatheSlot>? breatheSlots,
    int? breatheMinutes,
    Set<int>? breatheDays,
  }) => RemindersConfig(
    water: water ?? this.water,
    cups: cups ?? this.cups,
    waterAlerts: clearAlerts ? null : (waterAlerts ?? this.waterAlerts),
    waterDays: waterDays ?? this.waterDays,
    stand: stand ?? this.stand,
    standEvery: standEvery ?? this.standEvery,
    standDays: standDays ?? this.standDays,
    breathe: breathe ?? this.breathe,
    breatheSlots: breatheSlots ?? this.breatheSlots,
    breatheMinutes: breatheMinutes ?? this.breatheMinutes,
    breatheDays: breatheDays ?? this.breatheDays,
  );

  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'water': water,
    'cups': cups,
    'waterAlerts': waterAlerts,
    'waterDays': (waterDays.toList()..sort()),
    'stand': stand,
    'standEvery': standEvery,
    'standDays': (standDays.toList()..sort()),
    'breathe': breathe,
    'breatheSlots': [for (final b in breatheSlots) b.name],
    'breatheMinutes': breatheMinutes,
    'breatheDays': (breatheDays.toList()..sort()),
  };
  factory RemindersConfig.fromJson(Map<String, Object?> j) {
    Set<int> days(String k) =>
        j[k] == null ? allWeekdays : {for (final d in j[k] as List) d as int};
    return RemindersConfig(
      water: (j['water'] as bool?) ?? true,
      cups: (j['cups'] as int?) ?? 8,
      waterAlerts: j['waterAlerts'] as int?,
      waterDays: days('waterDays'),
      stand: (j['stand'] as bool?) ?? true,
      standEvery: (j['standEvery'] as int?) ?? 120,
      standDays: days('standDays'),
      breathe: (j['breathe'] as bool?) ?? true,
      breatheSlots: j['breatheSlots'] == null
          ? const {BreatheSlot.afternoon}
          : {
              for (final n in j['breatheSlots'] as List)
                BreatheSlot.values.byName(n as String),
            },
      breatheMinutes: (j['breatheMinutes'] as int?) ?? 1,
      breatheDays: days('breatheDays'),
    );
  }
}

/// أيام الأسبوع كلها (DateTime.monday..sunday).
const allWeekdays = {1, 2, 3, 4, 5, 6, 7};

/// أوقات جلسات التنفّس.
enum BreatheSlot {
  morning('الصباح', 'breathe#am'),
  afternoon('العصر', 'breathe'),
  night('قبل النوم', 'breathe#pm');

  const BreatheSlot(this.label, this.key);
  final String label;

  /// مفتاح السطر في السجل. العصر يحتفظ بالمفتاح القديم «breathe».
  final String key;
}

/// الادخار: تذكير يوم الراتب بمبلغ شهري، وهدف اختياري. إدخال يدوي فقط.
class SavingsConfig extends RuleConfig {
  const SavingsConfig({
    this.payDay = 27,
    this.monthly = 500,
    this.target,
    this.targetBy,
  });

  /// يوم الراتب من الشهر (1..31). الشهر الأقصر يأخذ آخر يوم فيه.
  final int payDay;

  /// المبلغ المخطط كل شهر.
  final int monthly;

  /// هدف الادخار (اختياري) وموعده.
  final int? target;
  final Day? targetBy;

  @override
  RuleKind get kind => RuleKind.savings;

  /// هل [d] يوم الراتب؟
  bool isPayDay(Day d) {
    final last = Day(d.year, d.month + 1, 1).add(-1).day;
    return d.day == (payDay > last ? last : payDay);
  }

  SavingsConfig copyWith({
    int? payDay,
    int? monthly,
    int? target,
    bool clearTarget = false,
    Day? targetBy,
    bool clearTargetBy = false,
  }) => SavingsConfig(
    payDay: payDay ?? this.payDay,
    monthly: monthly ?? this.monthly,
    target: clearTarget ? null : (target ?? this.target),
    targetBy: clearTargetBy ? null : (targetBy ?? this.targetBy),
  );

  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'payDay': payDay,
    'monthly': monthly,
    'target': target,
    'targetBy': targetBy?.key,
  };

  factory SavingsConfig.fromJson(Map<String, Object?> j) => SavingsConfig(
    payDay: (j['payDay'] as int?) ?? 27,
    monthly: (j['monthly'] as int?) ?? 500,
    target: j['target'] as int?,
    targetBy: j['targetBy'] == null
        ? null
        : Day.parse(j['targetBy']! as String),
  );
}

// ---------------------------------------------------------------------------
// صحتي: تذكير وتسجيل فقط. الأوقات وعددها يحددها المستخدم حسب طبيبه،
// والتطبيق ما يقترح جرعات ولا أرقامًا علاجية.
// ---------------------------------------------------------------------------

enum HealthCheckKind {
  glucose('قياس السكر', 'glucose', 'ملغ/دل'),
  pressure('قياس الضغط', 'pressure', 'ملم زئبق'),
  medicine('الدواء', 'pill', null),
  other('متابعة أخرى', 'health', null);

  const HealthCheckKind(this.label, this.icon, this.unit);
  final String label;
  final String icon;

  /// وحدة القراءة، أو null إذا ما فيه قراءة (الدواء: تمّ فقط).
  final String? unit;
  bool get hasReading => unit != null;
}

class HealthCheck {
  const HealthCheck({
    required this.id,
    required this.kind,
    required this.title,
    required this.times,
    this.days = allWeekdays,
  });
  final String id;
  final HealthCheckKind kind;
  final String title;
  final List<int> times;
  final Set<int> days;

  HealthCheck copyWith({
    HealthCheckKind? kind,
    String? title,
    List<int>? times,
    Set<int>? days,
  }) => HealthCheck(
    id: id,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    times: times ?? this.times,
    days: days ?? this.days,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'times': times,
    'days': (days.toList()..sort()),
  };
  factory HealthCheck.fromJson(Map<String, Object?> j) => HealthCheck(
    id: j['id']! as String,
    kind:
        HealthCheckKind.values.asNameMap()[j['kind']] ?? HealthCheckKind.other,
    title: j['title']! as String,
    times: [...(j['times']! as List).cast<int>()],
    days: j['days'] == null
        ? allWeekdays
        : {...(j['days']! as List).cast<int>()},
  );
}

class HealthConfig extends RuleConfig {
  const HealthConfig({this.checks = const []});
  final List<HealthCheck> checks;
  @override
  RuleKind get kind => RuleKind.health;
  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'checks': [for (final c in checks) c.toJson()],
  };
  factory HealthConfig.fromJson(Map<String, Object?> j) => HealthConfig(
    checks: [
      for (final c in (j['checks'] as List?) ?? const [])
        HealthCheck.fromJson((c as Map).cast<String, Object?>()),
    ],
  );
}

// ---------------------------------------------------------------------------
// الحمل والطفل: مشي خفيف اختياري للحامل، وتذكير الرضعات وتسجيلها للرضيع.
// المواعيد الطبية يضيفها المستخدم من «+». ما فيه جداول تطعيم الحين.
// ---------------------------------------------------------------------------

enum MotherStage {
  pregnant('حامل'),
  infant('أم لطفل رضيع');

  const MotherStage(this.label);
  final String label;
}

class MotherConfig extends RuleConfig {
  const MotherConfig({
    this.stage = MotherStage.pregnant,
    this.walk = true,
    this.walkMinutes = 20,
    this.feeds = true,
    this.feedEvery = 180,
    this.babyBorn,
  });
  final MotherStage stage;

  /// للحامل: مشي خفيف (بعد موافقة الطبيبة).
  final bool walk;
  final int walkMinutes;

  /// للرضيع: تذكير الرضعات كل [feedEvery] دقيقة من صحيانك لنومك.
  final bool feeds;
  final int feedEvery;
  final Day? babyBorn;

  @override
  RuleKind get kind => RuleKind.mother;

  MotherConfig copyWith({
    MotherStage? stage,
    bool? walk,
    int? walkMinutes,
    bool? feeds,
    int? feedEvery,
    Day? babyBorn,
  }) => MotherConfig(
    stage: stage ?? this.stage,
    walk: walk ?? this.walk,
    walkMinutes: walkMinutes ?? this.walkMinutes,
    feeds: feeds ?? this.feeds,
    feedEvery: feedEvery ?? this.feedEvery,
    babyBorn: babyBorn ?? this.babyBorn,
  );

  @override
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'stage': stage.name,
    'walk': walk,
    'walkMinutes': walkMinutes,
    'feeds': feeds,
    'feedEvery': feedEvery,
    'babyBorn': babyBorn?.key,
  };
  factory MotherConfig.fromJson(Map<String, Object?> j) => MotherConfig(
    stage: MotherStage.values.asNameMap()[j['stage']] ?? MotherStage.pregnant,
    walk: (j['walk'] as bool?) ?? true,
    walkMinutes: (j['walkMinutes'] as int?) ?? 20,
    feeds: (j['feeds'] as bool?) ?? true,
    feedEvery: (j['feedEvery'] as int?) ?? 180,
    babyBorn: j['babyBorn'] == null
        ? null
        : Day.parse(j['babyBorn']! as String),
  );
}
