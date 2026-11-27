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
  sms('رسالة');

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
  });

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
  );
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
