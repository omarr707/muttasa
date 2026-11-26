import 'day.dart';

/// تنسيق عربي بأرقام لاتينية 0-9 داخل النص، مثل «5:35 م».
/// دالة واحدة للوقت والعدد كما تنص الوثيقة.
String fmtTime(int minute) {
  var m = minute % minutesPerDay;
  if (m < 0) m += minutesPerDay;
  final h24 = m ~/ 60;
  final mm = m % 60;
  final pm = h24 >= 12;
  var h = h24 % 12;
  if (h == 0) h = 12;
  return '$h:${mm.toString().padLeft(2, '0')} ${pm ? 'م' : 'ص'}';
}

/// «5:35 م إلى 6:05 م».
String fmtRange(int start, int end) => '${fmtTime(start)} إلى ${fmtTime(end)}';

/// الساعة فقط للعمود الجانبي: «5 م».
String fmtHour(int minute) {
  final h24 = (minute % minutesPerDay) ~/ 60;
  var h = h24 % 12;
  if (h == 0) h = 12;
  return '$h ${h24 >= 12 ? 'م' : 'ص'}';
}

/// المدة بالعربية: «10 دقائق»، «ساعة»، «ساعة ونص»، «ساعتين».
String fmtDuration(int minutes) {
  if (minutes < 60) return '$minutes ${_minuteWord(minutes)}';
  final h = minutes ~/ 60;
  final r = minutes % 60;
  String hs;
  if (h == 1) {
    hs = 'ساعة';
  } else if (h == 2) {
    hs = 'ساعتين';
  } else {
    hs = '$h ساعات';
  }
  if (r == 0) return hs;
  if (r == 30) return '$hs ونص';
  if (r == 15) return '$hs وربع';
  return '$hs و$r ${_minuteWord(r)}';
}

String _minuteWord(int n) => (n >= 3 && n <= 10) ? 'دقائق' : 'دقيقة';

/// «5 من 18».
String fmtCount(int done, int total) => '$done من $total';

const arabicWeekdays = {
  DateTime.saturday: 'السبت',
  DateTime.sunday: 'الأحد',
  DateTime.monday: 'الاثنين',
  DateTime.tuesday: 'الثلاثاء',
  DateTime.wednesday: 'الأربعاء',
  DateTime.thursday: 'الخميس',
  DateTime.friday: 'الجمعة',
};

const arabicWeekdayLetters = {
  DateTime.saturday: 'س',
  DateTime.sunday: 'ح',
  DateTime.monday: 'ن',
  DateTime.tuesday: 'ث',
  DateTime.wednesday: 'ر',
  DateTime.thursday: 'خ',
  DateTime.friday: 'ج',
};

const arabicMonths = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// «الخميس 26 نوفمبر».
String fmtDayLong(Day d) =>
    '${arabicWeekdays[d.weekday]} ${d.day} ${arabicMonths[d.month - 1]}';

/// قائمة أيام الأسبوع بترتيب يبدأ بالسبت.
const weekOrder = [
  DateTime.saturday,
  DateTime.sunday,
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
];

/// «من الأحد إلى الخميس» أو «السبت، الاثنين».
String fmtWeekdays(Set<int> days) {
  if (days.length == 7) return 'كل يوم';
  if (days.isEmpty) return 'بدون أيام';
  final ordered = weekOrder.where(days.contains).toList();
  // نطاق متصل؟
  final idx = ordered.map(weekOrder.indexOf).toList();
  var contiguous = ordered.length > 2;
  for (var i = 1; i < idx.length; i++) {
    if (idx[i] != idx[i - 1] + 1) contiguous = false;
  }
  if (contiguous) {
    return 'من ${arabicWeekdays[ordered.first]} إلى ${arabicWeekdays[ordered.last]}';
  }
  return ordered.map((d) => arabicWeekdays[d]).join('، ');
}
