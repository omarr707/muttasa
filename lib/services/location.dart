import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../data/defaults.dart';

/// نتيجة «استخدم موقعي».
class LocatedCity {
  const LocatedCity(this.country, this.city, this.km);
  final Country country;

  /// المدينة الأقرب، بإحداثيات موقعك الفعلية لحساب المواقيت بدقة.
  final City city;

  /// المسافة لأقرب مدينة معروفة.
  final double km;
}

class LocationException implements Exception {
  const LocationException(this.message);
  final String message;
  @override
  String toString() => message;
}

double _km(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// أقرب مدينة في الإعدادات المدمجة لإحداثيات معيّنة.
LocatedCity? nearestCity(Defaults d, double lat, double lng) {
  LocatedCity? best;
  for (final co in d.countries) {
    for (final ci in co.cities) {
      final km = _km(lat, lng, ci.lat, ci.lng);
      if (best == null || km < best.km) {
        final name = km <= 50 ? ci.name : 'قرب ${ci.name}';
        best = LocatedCity(co, City(name, lat, lng, ci.tz), km);
      }
    }
  }
  return best;
}

/// يقرأ الموقع مرة واحدة بدقة تقريبية ويختار أقرب مدينة. لا تتبّع ولا حفظ للموقع الخام.
Future<LocatedCity> locateMe(Defaults d) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationException('خدمة الموقع مقفلة في الجوال');
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied ||
      perm == LocationPermission.deniedForever) {
    throw const LocationException(
      'ما وصلنا إذن الموقع، اختر مدينتك من القائمة',
    );
  }
  final pos = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.low,
      timeLimit: Duration(seconds: 20),
    ),
  );
  final found = nearestCity(d, pos.latitude, pos.longitude);
  if (found == null) {
    throw const LocationException('ما لقينا مدينة قريبة، اختر من القائمة');
  }
  return found;
}
