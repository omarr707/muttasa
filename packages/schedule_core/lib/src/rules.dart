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

enum RuleKind { prayers, adhkar, quran, habit, meal, work, kid, klass, reminders }

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

  bool activeOn(Day d) => !d.isBefore(validFrom) && (validTo == null || !d.isAfter(validTo!));

  bool pausedOn(Day d) =>
      pausedFrom != null && !d.isBefore(pausedFrom!) && (pausedUntil == null || !d.isAfter(pausedUntil!));

  Rule copyWith({
    String? id,
    Day? validFrom,
    Day? validTo,
    bool clearValidTo = false,
    Day? pausedFrom,
    Day? pausedUntil,
    bool clearPause = false,
    RuleConfig? config,
  }) =>
      Rule(
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
        pausedFrom: j['pausedFrom'] == null ? null : Day.parse(j['pausedFrom']! as String),
        pausedUntil: j['pausedUntil'] == null ? null : Day.parse(j['pausedUntil']! as String),
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
    }
  }
}

/// الصلوات الخمس (والجمعة). الأوقات من السياق.
class PrayersConfig extends RuleConfig {
  const PrayersConfig({this.place = 'في المسجد القريب', this.track = TrackMode.confirm});
  final String place;
  final TrackMode track;
  @override
  RuleKind get kind => RuleKind.prayers;
  @override
  Map<String, Object?> toJson() => {'kind': kind.name, 'place': place, 'track': track.name};
  factory PrayersConfig.fromJson(Map<String, Object?> j) => PrayersConfig(
        place: (j['place'] as String?) ?? '',
        track: TrackMode.values.byName((j['track'] as String?) ?? 'confirm'),
      );
}

class AdhkarConfig extends RuleConfig {
  const AdhkarConfig({this.morning = true, this.evening = true, this.minutes = 10});
  final bool morning;
  final bool evening;
  final int minutes;
  @override
  RuleKind get kind => RuleKind.adhkar;
  @override
  Map<String, Object?> toJson() =>
      {'kind': kind.name, 'morning': morning, 'evening': evening, 'minutes': minutes};
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

  Window windowFor(int session) => windows.isEmpty ? Window.any : windows[session.clamp(0, windows.length - 1)];

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
  }) =>
      FlexConfig(
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
      };

  factory FlexConfig.fromJson(Map<String, Object?> j) => FlexConfig(
        kind: RuleKind.values.byName(j['kind']! as String),
        title: j['title']! as String,
        subtitle: j['subtitle'] as String?,
        icon: (j['icon'] as String?) ?? 'star',
        recurrence: Recurrence.fromJson((j['recurrence']! as Map).cast<String, Object?>()),
        duration: j['duration']! as int,
        windows: ((j['windows'] as List?) ?? const ['any']).map((w) => Window.values.byName(w as String)).toList(),
        preferred: j['preferred'] as int?,
        perDay: (j['perDay'] as int?) ?? 1,
        track: TrackMode.values.byName((j['track'] as String?) ?? 'confirm'),
        optional: (j['optional'] as bool?) ?? false,
        counted: (j['counted'] as bool?) ?? true,
        category: (j['category'] as String?) ?? 'habits',
        pages: j['pages'] as int?,
        book: j['book'] as String?,
        startPage: j['startPage'] as int?,
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
  bool get hasBreak => breakStart != null && breakEnd != null && breakEnd! > breakStart!;

  Map<String, Object?> toJson() => {'start': start, 'end': end, 'breakStart': breakStart, 'breakEnd': breakEnd};
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
  const WorkConfig({this.title = 'الدوام', this.pattern = WorkPattern.morning, required this.days});
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
        'days': {for (final e in days.entries) '${e.key}': e.value.map((p) => p.toJson()).toList()},
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
  factory KidDay.fromJson(Map<String, Object?> j) => KidDay(drop: j['drop'] as int?, pick: j['pick'] as int?);
}

class KidConfig extends RuleConfig {
  const KidConfig({required this.child, this.place, this.trip = 20, required this.days});
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
            int.parse(e.key as String): KidDay.fromJson((e.value as Map).cast<String, Object?>()),
        },
      );
}

/// حصة أو نادٍ أو دورة بموعد أسبوعي.
class ClassConfig extends RuleConfig {
  const ClassConfig({
    required this.title,
    this.who = 'أنا',
    required this.weekdays,
    required this.start,
    required this.end,
    this.place,
  });
  final String title;
  final String who;
  final Set<int> weekdays;
  final int start;
  final int end;
  final String? place;

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
      };
  factory ClassConfig.fromJson(Map<String, Object?> j) => ClassConfig(
        title: j['title']! as String,
        who: (j['who'] as String?) ?? 'أنا',
        weekdays: {...(j['weekdays']! as List).cast<int>()},
        start: j['start']! as int,
        end: j['end']! as int,
        place: j['place'] as String?,
      );
}

/// التذكيرات القصيرة: خطوط خفيفة لا تحجز وقتًا ولا تُحسب.
class RemindersConfig extends RuleConfig {
  const RemindersConfig({this.water = true, this.cups = 8, this.stand = true, this.breathe = true});
  final bool water;
  final int cups;
  final bool stand;
  final bool breathe;
  @override
  RuleKind get kind => RuleKind.reminders;
  @override
  Map<String, Object?> toJson() =>
      {'kind': kind.name, 'water': water, 'cups': cups, 'stand': stand, 'breathe': breathe};
  factory RemindersConfig.fromJson(Map<String, Object?> j) => RemindersConfig(
        water: (j['water'] as bool?) ?? true,
        cups: (j['cups'] as int?) ?? 8,
        stand: (j['stand'] as bool?) ?? true,
        breathe: (j['breathe'] as bool?) ?? true,
      );
}
