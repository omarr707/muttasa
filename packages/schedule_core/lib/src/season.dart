import 'package:hijri/hijri_calendar.dart';

import 'day.dart';
import 'profile.dart';

/// التاريخ الهجري (أم القرى) ليوم ميلادي، مع إزاحة ±1 للرؤية.
class HijriDay {
  const HijriDay(this.year, this.month, this.day);
  final int year;
  final int month;
  final int day;

  factory HijriDay.of(Day d, {int offset = 0}) {
    final x = d.add(offset);
    final h = HijriCalendar.fromDate(DateTime(x.year, x.month, x.day));
    return HijriDay(h.hYear, h.hMonth, h.hDay);
  }

  static const months = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  String get monthName => months[month - 1];

  @override
  bool operator ==(Object other) =>
      other is HijriDay &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => '$year-$month-$day';
}

/// وضع الصيام.
enum FastingMode {
  off('مغلق'),
  ramadan('تلقائي في رمضان'),
  ramadanMonThu('رمضان مع الاثنين والخميس');

  const FastingMode(this.label);
  final String label;
}

/// إعدادات المواسم: رمضان والعيد والصيام والعطل الرسمية.
class SeasonSettings {
  const SeasonSettings({
    this.fasting = FastingMode.ramadan,
    this.ramadanWork = true,
    this.ramadanWorkStart = 10 * 60,
    this.ramadanWorkEnd = 15 * 60,
    this.taraweeh = true,
    this.lateOutings = true,
    this.ramadanSleep = 23 * 60 + 30,
    this.eid = true,
    this.holidays = true,
    this.ramadanYears = const {},
  });

  final FastingMode fasting;

  /// دوام رمضان يحل محل دوام الأيام العادية (الورديات الليلية تبقى).
  final bool ramadanWork;
  final int ramadanWorkStart;
  final int ramadanWorkEnd;

  /// التراويح بعد العشاء بـ 20 دقيقة لمدة ساعة.
  final bool taraweeh;

  /// المشي والطلعات والاقتراحات بعد الإفطار.
  final bool lateOutings;

  /// وقت النوم في رمضان.
  final int ramadanSleep;

  /// وضع العيد: صلاة العيد، المعايدة، والدوام إجازة.
  final bool eid;

  /// العطل الرسمية في دولتك تلغي الدوام ومشاوير المدرسة.
  final bool holidays;

  /// الموافقة على جدول رمضان لكل سنة هجرية: true بدأ، false «خلّ جدولي كما هو».
  final Map<int, bool> ramadanYears;

  SeasonSettings copyWith({
    FastingMode? fasting,
    bool? ramadanWork,
    int? ramadanWorkStart,
    int? ramadanWorkEnd,
    bool? taraweeh,
    bool? lateOutings,
    int? ramadanSleep,
    bool? eid,
    bool? holidays,
    Map<int, bool>? ramadanYears,
  }) => SeasonSettings(
    fasting: fasting ?? this.fasting,
    ramadanWork: ramadanWork ?? this.ramadanWork,
    ramadanWorkStart: ramadanWorkStart ?? this.ramadanWorkStart,
    ramadanWorkEnd: ramadanWorkEnd ?? this.ramadanWorkEnd,
    taraweeh: taraweeh ?? this.taraweeh,
    lateOutings: lateOutings ?? this.lateOutings,
    ramadanSleep: ramadanSleep ?? this.ramadanSleep,
    eid: eid ?? this.eid,
    holidays: holidays ?? this.holidays,
    ramadanYears: ramadanYears ?? this.ramadanYears,
  );

  Map<String, Object?> toJson() => {
    'fasting': fasting.name,
    'ramadanWork': ramadanWork,
    'ramadanWorkStart': ramadanWorkStart,
    'ramadanWorkEnd': ramadanWorkEnd,
    'taraweeh': taraweeh,
    'lateOutings': lateOutings,
    'ramadanSleep': ramadanSleep,
    'eid': eid,
    'holidays': holidays,
    'ramadanYears': {for (final e in ramadanYears.entries) '${e.key}': e.value},
  };

  factory SeasonSettings.fromJson(Map<String, Object?> j) => SeasonSettings(
    fasting: FastingMode.values.byName((j['fasting'] as String?) ?? 'ramadan'),
    ramadanWork: (j['ramadanWork'] as bool?) ?? true,
    ramadanWorkStart: (j['ramadanWorkStart'] as int?) ?? 600,
    ramadanWorkEnd: (j['ramadanWorkEnd'] as int?) ?? 900,
    taraweeh: (j['taraweeh'] as bool?) ?? true,
    lateOutings: (j['lateOutings'] as bool?) ?? true,
    ramadanSleep: (j['ramadanSleep'] as int?) ?? 1410,
    eid: (j['eid'] as bool?) ?? true,
    holidays: (j['holidays'] as bool?) ?? true,
    ramadanYears: {
      for (final e in ((j['ramadanYears'] as Map?) ?? const {}).entries)
        int.parse(e.key as String): e.value as bool,
    },
  );
}

// -----------------------------------------------------------------------------
// الأوضاع: إجازة، سفر، إيقاف مؤقت
// -----------------------------------------------------------------------------

enum ModeKind {
  vacation('إجازة'),
  travel('سفر'),
  pause('إيقاف مؤقت');

  const ModeKind(this.label);
  final String label;
}

/// وضع من تاريخ إلى تاريخ (شامل).
class LifeMode {
  const LifeMode({
    required this.id,
    required this.kind,
    required this.from,
    required this.to,
    this.workOff = true,
    this.kidsOff = true,
    this.country,
    this.city,
    this.lat,
    this.lng,
    this.timezone,
    this.calcMethod,
  });

  final String id;
  final ModeKind kind;
  final Day from;
  final Day to;

  /// إجازة من الدوام. في الإجازة دائمًا، وفي السفر حسب اختيارك.
  final bool workOff;

  /// تتوقف مشاوير الأولاد والحصص.
  final bool kidsOff;

  // السفر: الوجهة تحدد المدينة والمنطقة الزمنية ومواقيت الصلاة.
  final String? country;
  final String? city;
  final double? lat;
  final double? lng;
  final String? timezone;
  final CalcMethod? calcMethod;

  bool covers(Day d) => !d.isBefore(from) && !d.isAfter(to);
  bool get hasPlace =>
      kind == ModeKind.travel && lat != null && lng != null && timezone != null;

  int get days => to.difference(from) + 1;

  LifeMode copyWith({
    Day? from,
    Day? to,
    bool? workOff,
    bool? kidsOff,
    String? country,
    String? city,
    double? lat,
    double? lng,
    String? timezone,
    CalcMethod? calcMethod,
  }) => LifeMode(
    id: id,
    kind: kind,
    from: from ?? this.from,
    to: to ?? this.to,
    workOff: workOff ?? this.workOff,
    kidsOff: kidsOff ?? this.kidsOff,
    country: country ?? this.country,
    city: city ?? this.city,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    timezone: timezone ?? this.timezone,
    calcMethod: calcMethod ?? this.calcMethod,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'from': from.key,
    'to': to.key,
    'workOff': workOff,
    'kidsOff': kidsOff,
    if (country != null) 'country': country,
    if (city != null) 'city': city,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
    if (timezone != null) 'timezone': timezone,
    if (calcMethod != null) 'calcMethod': calcMethod!.name,
  };

  factory LifeMode.fromJson(Map<String, Object?> j) => LifeMode(
    id: j['id']! as String,
    kind: ModeKind.values.byName(j['kind']! as String),
    from: Day.parse(j['from']! as String),
    to: Day.parse(j['to']! as String),
    workOff: (j['workOff'] as bool?) ?? true,
    kidsOff: (j['kidsOff'] as bool?) ?? true,
    country: j['country'] as String?,
    city: j['city'] as String?,
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    timezone: j['timezone'] as String?,
    calcMethod: j['calcMethod'] == null
        ? null
        : CalcMethod.values.byName(j['calcMethod']! as String),
  );
}

// -----------------------------------------------------------------------------
// المناسبات الوطنية والعطل
// -----------------------------------------------------------------------------

/// مناسبة وطنية من جدول الدولة: بالميلادي أو الهجري، وهل هي عطلة رسمية.
class Holiday {
  const Holiday({
    required this.name,
    required this.month,
    required this.day,
    this.hijri = false,
    this.days = 1,
    this.off = true,
  });

  final String name;
  final int month;
  final int day;
  final bool hijri;

  /// عدد أيام العطلة من [day].
  final int days;
  final bool off;

  bool on(Day d, {int hijriOffset = 0}) {
    if (hijri) {
      final h = HijriDay.of(d, offset: hijriOffset);
      return h.month == month && h.day >= day && h.day < day + days;
    }
    for (var i = 0; i < days; i++) {
      final x = d.add(-i);
      if (x.month == month && x.day == day) return true;
    }
    return false;
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'month': month,
    'day': day,
    if (hijri) 'hijri': true,
    if (days != 1) 'days': days,
    if (!off) 'off': false,
  };

  factory Holiday.fromJson(Map<String, Object?> j) => Holiday(
    name: j['name']! as String,
    month: j['month']! as int,
    day: j['day']! as int,
    hijri: (j['hijri'] as bool?) ?? false,
    days: (j['days'] as int?) ?? 1,
    off: (j['off'] as bool?) ?? true,
  );
}

// -----------------------------------------------------------------------------
// سياق اليوم
// -----------------------------------------------------------------------------

enum EidKind {
  fitr('عيد الفطر'),
  adha('عيد الأضحى');

  const EidKind(this.label);
  final String label;
}

class EidDay {
  const EidDay(this.kind, this.dayOfEid);
  final EidKind kind;

  /// 1 = أول أيام العيد.
  final int dayOfEid;
  bool get first => dayOfEid == 1;
}

/// سياق يوم واحد: الهجري، رمضان والعيد والصيام، الوضع، والعطلة.
class DayContext {
  const DayContext({
    required this.hijri,
    this.ramadan = false,
    this.ramadanPending = false,
    this.fasting = false,
    this.eid,
    this.mode,
    this.holiday,
  });

  final HijriDay? hijri;

  /// جدول رمضان مطبّق (المستخدم وافق عليه لهذه السنة).
  final bool ramadan;

  /// الشهر رمضان (أو قبله بأيام) ولم يجب المستخدم بعد على «نبدأ جدول رمضان؟».
  final bool ramadanPending;
  final bool fasting;
  final EidDay? eid;
  final LifeMode? mode;
  final Holiday? holiday;

  bool get paused => mode?.kind == ModeKind.pause;
  bool get travel => mode?.kind == ModeKind.travel;
  bool get vacation =>
      mode != null &&
      (mode!.kind == ModeKind.vacation ||
          (mode!.kind == ModeKind.travel && mode!.workOff));

  /// لا دوام اليوم: إجازة، سفر بإجازة، عيد، أو عطلة رسمية.
  bool get workOff => vacation || eid != null || (holiday?.off ?? false);

  /// تتوقف مشاوير المدرسة.
  bool get schoolOff =>
      (mode != null &&
          (mode!.kind == ModeKind.travel ||
              (mode!.kind == ModeKind.vacation && mode!.kidsOff))) ||
      eid != null ||
      (holiday?.off ?? false);

  /// تتوقف الحصص والدورات (مع الإجازة والسفر فقط).
  bool get classesOff =>
      mode != null &&
      (mode!.kind == ModeKind.travel ||
          (mode!.kind == ModeKind.vacation && mode!.kidsOff));
}

/// يبني سياق اليوم من الملف الشخصي والإعدادات والأوضاع والعطل.
DayContext dayContext(
  Day d, {
  required UserProfile profile,
  required SeasonSettings season,
  List<LifeMode> modes = const [],
  List<Holiday> holidays = const [],
}) {
  LifeMode? mode;
  for (final m in modes) {
    if (!m.covers(d)) continue;
    // الإيقاف يغلب، ثم السفر، ثم الإجازة.
    if (mode == null || m.kind.index > mode.kind.index) mode = m;
  }
  Holiday? holiday;
  if (season.holidays) {
    for (final h in holidays) {
      if (h.on(d, hijriOffset: profile.hijriOffset)) {
        holiday = h;
        break;
      }
    }
  }
  if (!profile.islam) {
    return DayContext(hijri: null, mode: mode, holiday: holiday);
  }
  final h = HijriDay.of(d, offset: profile.hijriOffset);
  EidDay? eid;
  if (season.eid) {
    if (h.month == 10 && h.day <= 3) eid = EidDay(EidKind.fitr, h.day);
    if (h.month == 12 && h.day >= 10 && h.day <= 13) {
      eid = EidDay(EidKind.adha, h.day - 9);
    }
  }
  final ramadanOn = season.fasting != FastingMode.off;
  final answer = season.ramadanYears[h.year];
  final ramadan = ramadanOn && h.month == 9 && answer == true;
  final pending =
      ramadanOn &&
      answer == null &&
      (h.month == 9 || (h.month == 8 && h.day >= 27));
  final monThu =
      season.fasting == FastingMode.ramadanMonThu &&
      h.month != 9 &&
      (d.weekday == DateTime.monday || d.weekday == DateTime.thursday);
  final fasting = eid == null && (ramadan || monThu);
  return DayContext(
    hijri: h,
    ramadan: ramadan,
    ramadanPending: pending,
    fasting: fasting,
    eid: eid,
    mode: mode,
    holiday: holiday,
  );
}

/// أيام حتى بداية رمضان من [d] (0 = اليوم رمضان، null = ليس قريبًا).
int? daysToRamadan(Day d, {int hijriOffset = 0}) {
  for (var i = 0; i < 6; i++) {
    if (HijriDay.of(d.add(i), offset: hijriOffset).month == 9) return i;
  }
  return null;
}
