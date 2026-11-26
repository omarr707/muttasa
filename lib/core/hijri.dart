import 'package:hijri/hijri_calendar.dart';
import 'package:schedule_core/schedule_core.dart';

const _hijriMonths = [
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

/// التاريخ الهجري (أم القرى) مع إزاحة ±1 يوم، بأرقام لاتينية: «16 جمادى الآخرة 1448 هـ».
String hijriLabel(Day d, {int offset = 0, bool short = false}) {
  final dt = DateTime(d.year, d.month, d.day).add(Duration(days: offset));
  final h = HijriCalendar.fromDate(dt);
  if (short) return '${h.hDay} ${_hijriMonths[h.hMonth - 1]}';
  return '${h.hDay} ${_hijriMonths[h.hMonth - 1]} ${h.hYear} هـ';
}
