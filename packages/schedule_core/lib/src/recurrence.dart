import 'day.dart';

/// نموذج تكرار واحد لكل العناصر المتكررة.
/// المرحلة الأولى تدعم: كل يوم، أيام محددة، عدد بالأسبوع، مرة واحدة.
sealed class Recurrence {
  const Recurrence();

  Map<String, Object?> toJson();

  static Recurrence fromJson(Map<String, Object?> j) {
    switch (j['type']) {
      case 'daily':
        return const Daily();
      case 'weekdays':
        return Weekdays({...(j['days']! as List).cast<int>()});
      case 'timesPerWeek':
        return TimesPerWeek(j['n']! as int);
      case 'once':
        return Once(Day.parse(j['date']! as String));
    }
    throw FormatException('تكرار غير معروف: ${j['type']}');
  }
}

class Daily extends Recurrence {
  const Daily();
  @override
  Map<String, Object?> toJson() => {'type': 'daily'};
  @override
  bool operator ==(Object other) => other is Daily;
  @override
  int get hashCode => 1;
}

class Weekdays extends Recurrence {
  const Weekdays(this.days);
  final Set<int> days;
  @override
  Map<String, Object?> toJson() => {
    'type': 'weekdays',
    'days': (days.toList()..sort()),
  };
  @override
  bool operator ==(Object other) =>
      other is Weekdays &&
      other.days.length == days.length &&
      other.days.containsAll(days);
  @override
  int get hashCode => Object.hashAllUnordered(days);
}

/// المحرك يختار الأيام الفاضية كل أسبوع.
class TimesPerWeek extends Recurrence {
  const TimesPerWeek(this.n);
  final int n;
  @override
  Map<String, Object?> toJson() => {'type': 'timesPerWeek', 'n': n};
  @override
  bool operator ==(Object other) => other is TimesPerWeek && other.n == n;
  @override
  int get hashCode => n;
}

class Once extends Recurrence {
  const Once(this.date);
  final Day date;
  @override
  Map<String, Object?> toJson() => {'type': 'once', 'date': date.key};
  @override
  bool operator ==(Object other) => other is Once && other.date == date;
  @override
  int get hashCode => date.hashCode;
}

/// أنماط التوزيع على الأسبوع: 3 جلسات ← اليوم الثاني والرابع والسابع.
/// تعيد فهارس الأيام (0 = السبت).
List<int> spreadOverWeek(int n) {
  if (n <= 0) return const [];
  if (n >= 7) return const [0, 1, 2, 3, 4, 5, 6];
  return [for (var i = 0; i < n; i++) ((i + 1) * 7 ~/ n) - 1];
}
