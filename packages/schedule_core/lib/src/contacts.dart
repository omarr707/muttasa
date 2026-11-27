import 'day.dart';

/// صلة الشخص.
enum Relation {
  family('أهل'),
  friend('صديق'),
  colleague('زميل'),
  neighbor('جار');

  const Relation(this.label);
  final String label;
}

/// كل كم يوم نقترح التواصل معه.
enum ContactFreq {
  weekly('أسبوعيًا', 7),
  biweekly('كل أسبوعين', 14),
  monthly('شهريًا', 30);

  const ContactFreq(this.label, this.days);
  final String label;
  final int days;
}

/// طريقة التواصل المفضلة.
enum ContactMethod {
  call('اتصال'),
  whatsapp('واتساب'),
  sms('رسالة'),
  visit('زيارة');

  const ContactMethod(this.label);
  final String label;
}

enum OccasionKind {
  birthday('عيد ميلاد', 'عيد ميلاده'),
  wedding('زواج', 'الزواج'),
  other('مناسبة', 'المناسبة');

  const OccasionKind(this.label, this.phrase);
  final String label;

  /// «هنّئ سعد بـ…»
  final String phrase;
}

/// مناسبة لشخص: سنوية (عيد ميلاد) أو بتاريخ واحد (زواج).
class Occasion {
  const Occasion({
    required this.kind,
    required this.month,
    required this.day,
    this.year,
  });
  final OccasionKind kind;
  final int month;
  final int day;

  /// إن وُجدت فالمناسبة مرة واحدة في تلك السنة.
  final int? year;

  bool on(Day d) =>
      d.month == month && d.day == day && (year == null || d.year == year);

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'month': month,
    'day': day,
    'year': year,
  };

  factory Occasion.fromJson(Map<String, Object?> j) => Occasion(
    kind: OccasionKind.values.byName((j['kind'] as String?) ?? 'other'),
    month: j['month']! as int,
    day: j['day']! as int,
    year: j['year'] as int?,
  );
}

/// شخص في قائمة التواصل. نحفظ الاسم والرقم فقط.
class Person {
  const Person({
    required this.id,
    required this.name,
    this.phone,
    this.relation = Relation.family,
    this.freq = ContactFreq.biweekly,
    this.method = ContactMethod.call,
    this.pinned = false,
    this.occasions = const [],
    this.giftBudget,
    required this.addedAt,
  });

  final String id;
  final String name;
  final String? phone;
  final Relation relation;
  final ContactFreq freq;
  final ContactMethod method;

  /// المثبّت يُقترح بتكراره الخاص خارج عدد الاقتراحات الأسبوعي.
  final bool pinned;
  final List<Occasion> occasions;

  /// ميزانية الهدية بالعملة المحلية، لاقتراح فكرة.
  final int? giftBudget;
  final Day addedAt;

  String get itemKey => 'contact:$id';
  String get initial => name.isEmpty ? '؟' : name.characters1;

  Person copyWith({
    String? name,
    String? phone,
    Relation? relation,
    ContactFreq? freq,
    ContactMethod? method,
    bool? pinned,
    List<Occasion>? occasions,
    int? giftBudget,
    bool clearBudget = false,
  }) => Person(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    relation: relation ?? this.relation,
    freq: freq ?? this.freq,
    method: method ?? this.method,
    pinned: pinned ?? this.pinned,
    occasions: occasions ?? this.occasions,
    giftBudget: clearBudget ? null : (giftBudget ?? this.giftBudget),
    addedAt: addedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'relation': relation.name,
    'freq': freq.name,
    'method': method.name,
    'pinned': pinned,
    'occasions': occasions.map((o) => o.toJson()).toList(),
    'giftBudget': giftBudget,
    'addedAt': addedAt.key,
  };

  factory Person.fromJson(Map<String, Object?> j) => Person(
    id: j['id']! as String,
    name: j['name']! as String,
    phone: j['phone'] as String?,
    relation: Relation.values.byName((j['relation'] as String?) ?? 'family'),
    freq: ContactFreq.values.byName((j['freq'] as String?) ?? 'biweekly'),
    method: ContactMethod.values.byName((j['method'] as String?) ?? 'call'),
    pinned: (j['pinned'] as bool?) ?? false,
    occasions: ((j['occasions'] as List?) ?? const [])
        .map((e) => Occasion.fromJson((e as Map).cast<String, Object?>()))
        .toList(),
    giftBudget: j['giftBudget'] as int?,
    addedAt: Day.parse(j['addedAt']! as String),
  );
}

extension on String {
  String get characters1 =>
      runes.isEmpty ? '' : String.fromCharCode(runes.first);
}

/// مستوى التواصل: عدد الاقتراحات في الأسبوع.
enum ContactLevel {
  off('إيقاف', 0),
  low('قليل', 1),
  mid('متوسط', 3),
  high('كثير', 5);

  const ContactLevel(this.label, this.perWeek);
  final String label;
  final int perWeek;
}

/// إعدادات قسم التواصل مع الناس.
class ContactsConfig {
  const ContactsConfig({
    this.enabled = false,
    this.level = ContactLevel.mid,
    this.calls = true,
    this.messages = true,
    this.occasions = true,
    this.gifts = true,
    this.windowStart = 19 * 60,
    this.windowEnd = 21 * 60,
    this.avoidWork = true,
    this.visitsWeekendOnly = true,
    this.excludedDays = const {},
    this.outings = defaultOutings,
  });

  /// الطلعات: خرجة الأصحاب وطلعة العائلة.
  final List<OutingConfig> outings;

  OutingConfig outing(OutingKind k) =>
      outings.where((o) => o.kind == k).firstOrNull ??
      defaultOutings.firstWhere((o) => o.kind == k);

  /// أيام الأسبوع (DateTime.weekday) التي لا نقترح فيها تواصلًا.
  final Set<int> excludedDays;

  final bool enabled;
  final ContactLevel level;
  final bool calls;
  final bool messages;
  final bool occasions;
  final bool gifts;

  /// وقت الاقتراحات: المساء ٧ إلى ٩ افتراضيًا.
  final int windowStart;
  final int windowEnd;
  final bool avoidWork;
  final bool visitsWeekendOnly;

  bool get active => enabled && level != ContactLevel.off;

  ContactsConfig copyWith({
    bool? enabled,
    ContactLevel? level,
    bool? calls,
    bool? messages,
    bool? occasions,
    bool? gifts,
    int? windowStart,
    int? windowEnd,
    bool? avoidWork,
    bool? visitsWeekendOnly,
    Set<int>? excludedDays,
    List<OutingConfig>? outings,
  }) => ContactsConfig(
    enabled: enabled ?? this.enabled,
    level: level ?? this.level,
    calls: calls ?? this.calls,
    messages: messages ?? this.messages,
    occasions: occasions ?? this.occasions,
    gifts: gifts ?? this.gifts,
    windowStart: windowStart ?? this.windowStart,
    windowEnd: windowEnd ?? this.windowEnd,
    avoidWork: avoidWork ?? this.avoidWork,
    visitsWeekendOnly: visitsWeekendOnly ?? this.visitsWeekendOnly,
    excludedDays: excludedDays ?? this.excludedDays,
    outings: outings ?? this.outings,
  );

  ContactsConfig withOuting(OutingConfig o) => copyWith(
    outings: [for (final k in OutingKind.values) k == o.kind ? o : outing(k)],
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'level': level.name,
    'calls': calls,
    'messages': messages,
    'occasions': occasions,
    'gifts': gifts,
    'windowStart': windowStart,
    'windowEnd': windowEnd,
    'avoidWork': avoidWork,
    'visitsWeekendOnly': visitsWeekendOnly,
    'excludedDays': excludedDays.toList()..sort(),
    'outings': outings.map((o) => o.toJson()).toList(),
  };

  factory ContactsConfig.fromJson(Map<String, Object?> j) => ContactsConfig(
    enabled: (j['enabled'] as bool?) ?? false,
    level: ContactLevel.values.byName((j['level'] as String?) ?? 'mid'),
    calls: (j['calls'] as bool?) ?? true,
    messages: (j['messages'] as bool?) ?? true,
    occasions: (j['occasions'] as bool?) ?? true,
    gifts: (j['gifts'] as bool?) ?? true,
    windowStart: (j['windowStart'] as int?) ?? 19 * 60,
    windowEnd: (j['windowEnd'] as int?) ?? 21 * 60,
    avoidWork: (j['avoidWork'] as bool?) ?? true,
    visitsWeekendOnly: (j['visitsWeekendOnly'] as bool?) ?? true,
    excludedDays: {...((j['excludedDays'] as List?) ?? const []).cast<int>()},
    outings: j['outings'] == null
        ? defaultOutings
        : [
            for (final o in j['outings']! as List)
              OutingConfig.fromJson((o as Map).cast<String, Object?>()),
          ],
  );
}

/// الافتراضات حسب العلاقة: التكرار والطريقة. المستخدم يغيّرها من ⚙ فقط إذا بغى.
(ContactFreq, ContactMethod) relationDefaults(Relation r) => switch (r) {
  Relation.family => (ContactFreq.weekly, ContactMethod.call),
  Relation.friend => (ContactFreq.biweekly, ContactMethod.whatsapp),
  Relation.colleague => (ContactFreq.monthly, ContactMethod.whatsapp),
  Relation.neighbor => (ContactFreq.monthly, ContactMethod.visit),
};

/// هل عند الشخص مناسبة خلال [days] يوم من [from]؟
bool occasionSoon(Person p, Day from, {int days = 7}) {
  for (var i = 0; i <= days; i++) {
    final d = from.add(i);
    if (p.occasions.any((o) => o.on(d))) return true;
  }
  return false;
}

/// مسودة قصيرة حسب الوقت. لا تُرسل إلا من المستخدم.
String contactDraft(Person p, int minute) {
  final first = p.name.split(' ').first;
  final greet = minute >= 15 * 60 ? 'مسا الخير' : 'صباح الخير';
  return '$greet يا $first، وش أخبارك؟';
}

/// فكرة هدية بسيطة حسب المناسبة والميزانية.
String giftIdea(OccasionKind k, int budget) {
  final idea = switch (k) {
    OccasionKind.wedding => budget >= 300 ? 'طقم ضيافة' : 'بوكيه ورد وبطاقة',
    OccasionKind.birthday => budget >= 200 ? 'عطر' : 'كتاب أو كوب مميز',
    OccasionKind.other => 'هدية رمزية',
  };
  return idea;
}

/// قوالب الرسائل حسب العلاقة والوقت والمناسبة. المستخدم يختار ويعدّل.
List<String> messageTemplates(Person p, int minute, {OccasionKind? occasion}) {
  final first = p.name.split(' ').first;
  final greet = minute >= 15 * 60 ? 'مسا الخير' : 'صباح الخير';
  if (occasion != null) {
    return switch (occasion) {
      OccasionKind.birthday => [
        'كل عام وأنت بخير يا $first، عسى سنتك الجاية أحلى 🎉',
        'عيد ميلاد سعيد يا $first، الله يسعدك ويحقق اللي تتمناه',
      ],
      OccasionKind.wedding => [
        'ألف مبروك يا $first، الله يتمم لكم على خير ويجعله زواج مبارك',
        'مبروك الزواج يا $first، بارك الله لكما وبارك عليكما وجمع بينكما في خير',
      ],
      OccasionKind.other => [
        'مبروك يا $first، الله يتمم فرحتك',
        'أبارك لك يا $first، فرحت لك من قلب',
      ],
    };
  }
  return switch (p.relation) {
    Relation.family => [
      '$greet يا $first، وش أخبارك؟ اشتقت لك',
      'السلام عليكم يا $first، طمّني عنك وعن صحتك',
      'يا $first، وش رايك نجتمع هالأسبوع؟',
    ],
    Relation.friend => [
      '$greet يا $first، وش أخبارك؟',
      'يا $first، من زمان عنك! وش الجديد؟',
      'وش رايك نطلع قهوة هالأسبوع يا $first؟',
    ],
    Relation.colleague => [
      '$greet يا $first، عساك بخير؟',
      'السلام عليكم $first، كيف الشغل معك؟',
    ],
    Relation.neighbor => [
      '$greet يا $first، عساكم بخير؟',
      'السلام عليكم يا $first، إذا احتجت شي أنا موجود',
    ],
  };
}

/// نوع الطلعة: خرجة الأصحاب أو طلعة العائلة.
enum OutingKind {
  friends('خرجة الأصحاب', 'friends'),
  family('طلعة العائلة', 'family');

  const OutingKind(this.label, this.icon);
  final String label;
  final String icon;
}

/// إعداد طلعة متكررة: الأيام والفترة والمدة والتكرار، ثابتة أو مقترحة،
/// ومع مين (تُحسب تواصلًا معهم إذا تمّت).
class OutingConfig {
  const OutingConfig({
    required this.kind,
    this.enabled = false,
    this.days = const {DateTime.thursday, DateTime.friday},
    this.windowStart = 19 * 60 + 30,
    this.windowEnd = 23 * 60,
    this.duration = 120,
    this.everyWeeks = 1,
    this.suggested = true,
    this.people = const [],
  });

  final OutingKind kind;
  final bool enabled;

  /// أيام الأسبوع المسموحة (DateTime.weekday).
  final Set<int> days;
  final int windowStart;
  final int windowEnd;
  final int duration;

  /// كل أسبوع، كل أسبوعين، أو كل 4 أسابيع (شهريًا).
  final int everyWeeks;

  /// مقترحة = تظهر «مقترحة» وتثبّتها بنفسك. ثابتة = تنحجز مباشرة.
  final bool suggested;
  final List<String> people;

  String get itemKey => 'outing:${kind.name}';

  String get frequencyLabel => switch (everyWeeks) {
    1 => 'أسبوعيًا',
    2 => 'كل أسبوعين',
    _ => 'شهريًا',
  };

  OutingConfig copyWith({
    bool? enabled,
    Set<int>? days,
    int? windowStart,
    int? windowEnd,
    int? duration,
    int? everyWeeks,
    bool? suggested,
    List<String>? people,
  }) => OutingConfig(
    kind: kind,
    enabled: enabled ?? this.enabled,
    days: days ?? this.days,
    windowStart: windowStart ?? this.windowStart,
    windowEnd: windowEnd ?? this.windowEnd,
    duration: duration ?? this.duration,
    everyWeeks: everyWeeks ?? this.everyWeeks,
    suggested: suggested ?? this.suggested,
    people: people ?? this.people,
  );

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'enabled': enabled,
    'days': days.toList()..sort(),
    'windowStart': windowStart,
    'windowEnd': windowEnd,
    'duration': duration,
    'everyWeeks': everyWeeks,
    'suggested': suggested,
    'people': people,
  };

  factory OutingConfig.fromJson(Map<String, Object?> j) => OutingConfig(
    kind: OutingKind.values.byName(j['kind']! as String),
    enabled: (j['enabled'] as bool?) ?? false,
    days: {
      ...((j['days'] as List?) ?? const [DateTime.thursday, DateTime.friday])
          .cast<int>(),
    },
    windowStart: (j['windowStart'] as int?) ?? 19 * 60 + 30,
    windowEnd: (j['windowEnd'] as int?) ?? 23 * 60,
    duration: (j['duration'] as int?) ?? 120,
    everyWeeks: (j['everyWeeks'] as int?) ?? 1,
    suggested: (j['suggested'] as bool?) ?? true,
    people: [...((j['people'] as List?) ?? const []).cast<String>()],
  );
}

/// الافتراض: الأصحاب كل أسبوعين الخميس، والعائلة كل أسبوع الجمعة عصرًا.
const defaultOutings = [
  OutingConfig(
    kind: OutingKind.friends,
    days: {DateTime.thursday},
    everyWeeks: 2,
  ),
  OutingConfig(
    kind: OutingKind.family,
    days: {DateTime.friday},
    windowStart: 16 * 60 + 30,
    windowEnd: 21 * 60,
  ),
];
