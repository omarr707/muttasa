/// تاريخ يوم بلا وقت ولا منطقة زمنية. كل المحرك يعمل بالأيام والدقائق من منتصف الليل.
class Day implements Comparable<Day> {
  const Day(this.year, this.month, this.day);

  factory Day.fromDateTime(DateTime d) => Day(d.year, d.month, d.day);

  /// يقبل الصيغة `yyyy-MM-dd`.
  factory Day.parse(String s) {
    final p = s.split('-');
    return Day(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  final int year;
  final int month;
  final int day;

  DateTime get _utc => DateTime.utc(year, month, day);

  /// الاثنين = 1 ... الأحد = 7 (مثل DateTime).
  int get weekday => _utc.weekday;

  Day add(int days) => Day.fromDateTime(_utc.add(Duration(days: days)));

  Day get next => add(1);
  Day get prev => add(-1);

  /// عدد الأيام من [other] إلى هذا اليوم.
  int difference(Day other) => _utc.difference(other._utc).inDays;

  /// بداية الأسبوع: السبت، كما في شريط الأسبوع في النموذج.
  Day get weekStart {
    // السبت = 6 في DateTime.
    final offset = (weekday - DateTime.saturday) % 7;
    return add(-offset);
  }

  bool isBefore(Day o) => compareTo(o) < 0;
  bool isAfter(Day o) => compareTo(o) > 0;

  /// وقت محلي عند الدقيقة [minute] من هذا اليوم.
  DateTime at(int minute) => DateTime(year, month, day, minute ~/ 60, minute % 60);

  String get key =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(Day o) => year != o.year
      ? year - o.year
      : month != o.month
          ? month - o.month
          : day - o.day;

  @override
  bool operator ==(Object other) => other is Day && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => key;
}

/// فترة زمنية [start, end) بالدقائق من منتصف الليل.
class Span {
  const Span(this.start, this.end);
  final int start;
  final int end;
  int get length => end - start;
  bool overlaps(Span o) => start < o.end && o.start < end;
  bool overlapsRange(int s, int e) => start < e && s < end;
  bool contains(int m) => m >= start && m < end;
  @override
  bool operator ==(Object other) => other is Span && other.start == start && other.end == end;
  @override
  int get hashCode => Object.hash(start, end);
  @override
  String toString() => '[$start,$end)';
}

const int minutesPerDay = 1440;
