import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:timezone/timezone.dart' as tz;

import 'day.dart';
import 'profile.dart';

/// مواقيت يوم واحد بالدقائق من منتصف الليل بتوقيت المدينة.
class DayPrayers {
  const DayPrayers({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  final int fajr;
  final int sunrise;
  final int dhuhr;
  final int asr;
  final int maghrib;
  final int isha;

  /// مراسٍ افتراضية لمن اختار «بدون» دين: تحدد النوافذ فقط ولا تظهر.
  static const neutral = DayPrayers(
    fajr: 5 * 60,
    sunrise: 6 * 60,
    dhuhr: 12 * 60,
    asr: 15 * 60 + 30,
    maghrib: 18 * 60,
    isha: 19 * 60 + 30,
  );

  @override
  String toString() =>
      'fajr=$fajr dhuhr=$dhuhr asr=$asr maghrib=$maghrib isha=$isha';
}

/// يحسب المواقيت محليًا بمكتبة adhan من الإحداثيات والتاريخ وطريقة الحساب.
/// يخبّئ النتائج بمفتاح (التاريخ، الموقع، الطريقة).
class PrayerCalculator {
  PrayerCalculator({
    required this.lat,
    required this.lng,
    required this.method,
    required this.location,
  });

  factory PrayerCalculator.forProfile(UserProfile p) => PrayerCalculator(
    lat: p.lat,
    lng: p.lng,
    method: p.calcMethod,
    location: tz.getLocation(p.timezone),
  );

  final double lat;
  final double lng;
  final CalcMethod method;
  final tz.Location location;
  final _cache = <Day, DayPrayers>{};

  adhan.CalculationParameters _params() {
    switch (method) {
      case CalcMethod.ummAlQura:
        return adhan.CalculationMethodParameters.ummAlQura();
      case CalcMethod.dubai:
        return adhan.CalculationMethodParameters.dubai();
      case CalcMethod.kuwait:
        return adhan.CalculationMethodParameters.kuwait();
      case CalcMethod.egyptian:
        return adhan.CalculationMethodParameters.egyptian();
      case CalcMethod.jordan:
        return adhan.CalculationMethodParameters.jordan();
      case CalcMethod.muslimWorldLeague:
        return adhan.CalculationMethodParameters.muslimWorldLeague();
    }
  }

  DayPrayers forDay(Day d) => _cache.putIfAbsent(d, () {
    final pt = adhan.PrayerTimes(
      date: DateTime(d.year, d.month, d.day),
      coordinates: adhan.Coordinates(lat, lng),
      calculationParameters: _params(),
    );
    int m(DateTime utc) {
      final local = tz.TZDateTime.from(utc, location);
      final dayOffset = Day(local.year, local.month, local.day).difference(d);
      return dayOffset * minutesPerDay + local.hour * 60 + local.minute;
    }

    return DayPrayers(
      fajr: m(pt.fajr),
      sunrise: m(pt.sunrise),
      dhuhr: m(pt.dhuhr),
      asr: m(pt.asr),
      maghrib: m(pt.maghrib),
      isha: m(pt.isha),
    );
  });
}
