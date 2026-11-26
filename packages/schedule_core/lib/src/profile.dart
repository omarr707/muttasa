import 'day.dart';

enum Religion { islam, none }

/// طرق حساب الصلاة المدعومة.
enum CalcMethod {
  ummAlQura('أم القرى'),
  dubai('الهيئة العامة للشؤون الإسلامية'),
  kuwait('وزارة الأوقاف الكويتية'),
  egyptian('الهيئة المصرية العامة للمساحة'),
  jordan('وزارة الأوقاف الأردنية'),
  muslimWorldLeague('رابطة العالم الإسلامي');

  const CalcMethod(this.label);
  final String label;
}

class UserProfile {
  const UserProfile({
    required this.name,
    required this.country,
    required this.city,
    required this.lat,
    required this.lng,
    required this.timezone,
    this.religion = Religion.islam,
    this.calcMethod = CalcMethod.ummAlQura,
    this.wake = 4 * 60 + 30,
    this.sleep = 22 * 60 + 30,
    required this.joinedAt,
    this.weekend = const {DateTime.friday, DateTime.saturday},
    this.hijriOffset = 0,
    this.currency = 'ريال',
  });

  /// الاسم (توقيع الرسائل).
  final String name;
  final String country;
  final String city;
  final double lat;
  final double lng;

  /// اسم IANA، مثل Asia/Riyadh.
  final String timezone;
  final Religion religion;
  final CalcMethod calcMethod;

  /// وقت الصحيان والنوم بالدقائق من منتصف الليل.
  final int wake;
  final int sleep;

  /// تاريخ ودقيقة الانضمام: ما قبلها في أول يوم «قبل انضمامك».
  final DateTime joinedAt;
  final Set<int> weekend;

  /// إزاحة ±1 يوم لبداية الشهر الهجري.
  final int hijriOffset;
  final String currency;

  Day get joinDay => Day.fromDateTime(joinedAt);
  int get joinMinute => joinedAt.hour * 60 + joinedAt.minute;
  bool get islam => religion == Religion.islam;

  UserProfile copyWith({
    String? name,
    String? country,
    String? city,
    double? lat,
    double? lng,
    String? timezone,
    Religion? religion,
    CalcMethod? calcMethod,
    int? wake,
    int? sleep,
    DateTime? joinedAt,
    Set<int>? weekend,
    int? hijriOffset,
    String? currency,
  }) =>
      UserProfile(
        name: name ?? this.name,
        country: country ?? this.country,
        city: city ?? this.city,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        timezone: timezone ?? this.timezone,
        religion: religion ?? this.religion,
        calcMethod: calcMethod ?? this.calcMethod,
        wake: wake ?? this.wake,
        sleep: sleep ?? this.sleep,
        joinedAt: joinedAt ?? this.joinedAt,
        weekend: weekend ?? this.weekend,
        hijriOffset: hijriOffset ?? this.hijriOffset,
        currency: currency ?? this.currency,
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'country': country,
        'city': city,
        'lat': lat,
        'lng': lng,
        'timezone': timezone,
        'religion': religion.name,
        'calcMethod': calcMethod.name,
        'wake': wake,
        'sleep': sleep,
        'joinedAt': joinedAt.toIso8601String(),
        'weekend': (weekend.toList()..sort()),
        'hijriOffset': hijriOffset,
        'currency': currency,
      };

  factory UserProfile.fromJson(Map<String, Object?> j) => UserProfile(
        name: j['name']! as String,
        country: j['country']! as String,
        city: j['city']! as String,
        lat: (j['lat']! as num).toDouble(),
        lng: (j['lng']! as num).toDouble(),
        timezone: j['timezone']! as String,
        religion: Religion.values.byName((j['religion'] as String?) ?? 'islam'),
        calcMethod: CalcMethod.values.byName((j['calcMethod'] as String?) ?? 'ummAlQura'),
        wake: (j['wake'] as int?) ?? 270,
        sleep: (j['sleep'] as int?) ?? 1350,
        joinedAt: DateTime.parse(j['joinedAt']! as String),
        weekend: {...((j['weekend'] as List?) ?? const [5, 6]).cast<int>()},
        hijriOffset: (j['hijriOffset'] as int?) ?? 0,
        currency: (j['currency'] as String?) ?? 'ريال',
      );
}

/// أنواع التنبيهات بالأولوية.
enum NotifyKind {
  prayer('الصلاة'),
  appointments('المواعيد'),
  routine('الروتين'),
  water('الماء');

  const NotifyKind(this.label);
  final String label;
}

class AppSettings {
  const AppSettings({
    this.optionalCapMinutes = 180,
    this.notifyEnabled = const {NotifyKind.prayer, NotifyKind.appointments, NotifyKind.routine, NotifyKind.water},
    this.leadMinutes = 10,
    this.quietStart = 22 * 60 + 30,
    this.quietEnd = 6 * 60,
    this.dailyCap = 12,
    this.eveningReview = true,
  });

  /// الحد اليومي للوقت الاختياري.
  final int optionalCapMinutes;
  final Set<NotifyKind> notifyEnabled;

  /// قبل العنصر بعدد دقائق. الصلاة والماء في وقتهما.
  final int leadMinutes;

  /// أوقات الهدوء: ما يقع فيها لا يُرسل (عدا الصلاة).
  final int quietStart;
  final int quietEnd;

  /// الحد اليومي للتنبيهات (عدا الصلاة).
  final int dailyCap;

  /// «راجع يومك» قبل وقت النوم بنصف ساعة.
  final bool eveningReview;

  AppSettings copyWith({
    int? optionalCapMinutes,
    Set<NotifyKind>? notifyEnabled,
    int? leadMinutes,
    int? quietStart,
    int? quietEnd,
    int? dailyCap,
    bool? eveningReview,
  }) =>
      AppSettings(
        optionalCapMinutes: optionalCapMinutes ?? this.optionalCapMinutes,
        notifyEnabled: notifyEnabled ?? this.notifyEnabled,
        leadMinutes: leadMinutes ?? this.leadMinutes,
        quietStart: quietStart ?? this.quietStart,
        quietEnd: quietEnd ?? this.quietEnd,
        dailyCap: dailyCap ?? this.dailyCap,
        eveningReview: eveningReview ?? this.eveningReview,
      );

  Map<String, Object?> toJson() => {
        'optionalCapMinutes': optionalCapMinutes,
        'notifyEnabled': notifyEnabled.map((k) => k.name).toList(),
        'leadMinutes': leadMinutes,
        'quietStart': quietStart,
        'quietEnd': quietEnd,
        'dailyCap': dailyCap,
        'eveningReview': eveningReview,
      };

  factory AppSettings.fromJson(Map<String, Object?> j) => AppSettings(
        optionalCapMinutes: (j['optionalCapMinutes'] as int?) ?? 180,
        notifyEnabled: {
          ...((j['notifyEnabled'] as List?) ?? NotifyKind.values.map((k) => k.name).toList())
              .map((n) => NotifyKind.values.byName(n as String)),
        },
        leadMinutes: (j['leadMinutes'] as int?) ?? 10,
        quietStart: (j['quietStart'] as int?) ?? 1350,
        quietEnd: (j['quietEnd'] as int?) ?? 360,
        dailyCap: (j['dailyCap'] as int?) ?? 12,
        eveningReview: (j['eveningReview'] as bool?) ?? true,
      );
}
