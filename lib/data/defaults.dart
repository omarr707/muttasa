import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:schedule_core/schedule_core.dart';

class City {
  const City(this.name, this.lat, this.lng, this.tz);
  final String name;
  final double lat;
  final double lng;
  final String tz;
}

class Country {
  const Country({
    required this.code,
    required this.name,
    required this.method,
    required this.weekend,
    required this.currency,
    required this.cities,
    this.holidays = const [],
  });
  final String code;
  final String name;
  final CalcMethod method;
  final Set<int> weekend;
  final String currency;
  final List<City> cities;

  /// المناسبات الوطنية والعطل الرسمية (من لوحة التحكم لاحقًا).
  final List<Holiday> holidays;

  String get weekendLabel =>
      'الإجازة ${fmtWeekdays(weekend).replaceAll('، ', ' و')}';
}

/// الإعدادات المدمجة في assets/defaults/ فيعمل التطبيق أول مرة بلا إنترنت.
class Defaults {
  const Defaults({required this.version, required this.countries});
  final int version;
  final List<Country> countries;

  Country country(String code) => countries.firstWhere(
    (c) => c.code == code,
    orElse: () => countries.first,
  );

  static Future<Defaults> load() async =>
      parse(await rootBundle.loadString('assets/defaults/config.json'));

  static Defaults parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return Defaults(
      version: j['config_version'] as int,
      countries: [
        for (final c in (j['countries'] as List).cast<Map<String, dynamic>>())
          Country(
            code: c['code'] as String,
            name: c['name'] as String,
            method: CalcMethod.values.byName(c['method'] as String),
            weekend: {...(c['weekend'] as List).cast<int>()},
            currency: c['currency'] as String,
            cities: [
              for (final ct
                  in (c['cities'] as List).cast<Map<String, dynamic>>())
                City(
                  ct['name'] as String,
                  (ct['lat'] as num).toDouble(),
                  (ct['lng'] as num).toDouble(),
                  ct['tz'] as String,
                ),
            ],
            holidays: [
              for (final h
                  in ((c['holidays'] as List?) ?? const [])
                      .cast<Map<String, dynamic>>())
                Holiday.fromJson(h),
            ],
          ),
      ],
    );
  }
}
