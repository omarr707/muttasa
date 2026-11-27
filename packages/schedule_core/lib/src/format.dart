import 'day.dart';

/// شكل الأرقام في النصوص: هندية «١٢٣» أو لاتينية «123».
/// التطبيق يضبطها من إعدادات المظهر، والمحرك يبقى على اللاتينية في اختباراته.
bool useArabicDigits = false;

const _arabicIndic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/// يحوّل كل الأرقام اللاتينية في النص حسب الإعداد الحالي.
String nums(Object? v) {
  final s = '$v';
  if (!useArabicDigits) return s;
  final b = StringBuffer();
  final u = s.codeUnits;
  bool digit(int i) => i >= 0 && i < u.length && u[i] >= 48 && u[i] <= 57;
  for (var i = 0; i < u.length; i++) {
    final c = u[i];
    if (digit(i)) {
      b.write(_arabicIndic[c - 48]);
    } else if (c == 46 && digit(i - 1) && digit(i + 1)) {
      b.write('٫'); // فاصلة عشرية بين رقمين فقط.
    } else if (c == 44 && digit(i - 1) && digit(i + 1)) {
      b.write('٬'); // فاصل الآلاف.
    } else {
      b.writeCharCode(c);
    }
  }
  return b.toString();
}

(int, int, bool) _hm(int minute) {
  var m = minute % minutesPerDay;
  if (m < 0) m += minutesPerDay;
  final h24 = m ~/ 60;
  var h = h24 % 12;
  if (h == 0) h = 12;
  return (h, m % 60, h24 >= 12);
}

/// «5:35 م».
String fmtTime(int minute) {
  final (h, mm, pm) = _hm(minute);
  return nums('$h:${mm.toString().padLeft(2, '0')} ${pm ? 'م' : 'ص'}');
}

/// «5:19–5:39 ص» إذا اتفق الطرفان في الفترة، وإلا «11:48 ص–12:33 م».
String fmtRange(int start, int end) {
  final (h1, m1, p1) = _hm(start);
  final (h2, m2, p2) = _hm(end);
  String t(int h, int m) => '$h:${m.toString().padLeft(2, '0')}';
  String p(bool pm) => pm ? 'م' : 'ص';
  if (p1 == p2) return nums('${t(h1, m1)}–${t(h2, m2)} ${p(p2)}');
  return nums('${t(h1, m1)} ${p(p1)}–${t(h2, m2)} ${p(p2)}');
}

/// الساعة فقط للعمود الجانبي: «5 م».
String fmtHour(int minute) {
  final h24 = (minute % minutesPerDay) ~/ 60;
  var h = h24 % 12;
  if (h == 0) h = 12;
  return nums('$h ${h24 >= 12 ? 'م' : 'ص'}');
}

/// المدة بالعربية: «10 دقائق»، «ساعة»، «ساعة ونص»، «ساعتين».
String fmtDuration(int minutes) => nums(_duration(minutes));

String _duration(int minutes) {
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
String fmtCount(int done, int total) => nums('$done من $total');

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
    nums('${arabicWeekdays[d.weekday]} ${d.day} ${arabicMonths[d.month - 1]}');

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
