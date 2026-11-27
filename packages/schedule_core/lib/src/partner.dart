import 'day.dart';

/// من يسوّي مشوار الأولاد.
enum RunWho {
  me('أنا'),
  partner('الشريك'),
  byDays('حسب الأيام');

  const RunWho(this.label);
  final String label;
}

/// إعداد مشوار واحد: [byDays] يعني الشريك في أيام [partnerDays] وأنا في الباقي.
class RunAssign {
  const RunAssign(this.who, {this.partnerDays = const {}});
  final RunWho who;
  final Set<int> partnerDays;

  bool partnerOn(Day d) => switch (who) {
    RunWho.me => false,
    RunWho.partner => true,
    RunWho.byDays => partnerDays.contains(d.weekday),
  };

  Map<String, Object?> toJson() => {
    'who': who.name,
    if (partnerDays.isNotEmpty) 'days': (partnerDays.toList()..sort()),
  };
  factory RunAssign.fromJson(Map<String, Object?> j) => RunAssign(
    RunWho.values.byName((j['who'] as String?) ?? 'me'),
    partnerDays: {...((j['days'] as List?) ?? const []).cast<int>()},
  );
}

/// مشاركة جدول الأولاد مع الزوج أو الزوجة. مشاوير الشريك للعلم فقط:
/// لا تحجز وقتًا ولا تُحسب. المشاركة نفسها عبر واتساب.
class PartnerShare {
  const PartnerShare({this.name = '', this.phone, this.runs = const {}});

  final String name;
  final String? phone;

  /// بمفتاح عنصر المشوار، مثل `kid:salma:drop`.
  final Map<String, RunAssign> runs;

  bool get active => name.trim().isNotEmpty;

  /// هل المشوار [itemKey] على الشريك في يوم [d] (قبل تبديل اليوم)؟
  bool partnerOn(String itemKey, Day d) =>
      active && (runs[itemKey]?.partnerOn(d) ?? false);

  PartnerShare copyWith({
    String? name,
    String? phone,
    Map<String, RunAssign>? runs,
  }) => PartnerShare(
    name: name ?? this.name,
    phone: phone ?? this.phone,
    runs: runs ?? this.runs,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'phone': phone,
    'runs': {for (final e in runs.entries) e.key: e.value.toJson()},
  };

  factory PartnerShare.fromJson(Map<String, Object?> j) => PartnerShare(
    name: (j['name'] as String?) ?? '',
    phone: j['phone'] as String?,
    runs: {
      for (final e in ((j['runs'] as Map?) ?? const {}).entries)
        e.key as String: RunAssign.fromJson(
          (e.value as Map).cast<String, Object?>(),
        ),
    },
  );
}

/// موعد مستورد من تقويم الجهاز (قراءة فقط). ثابت وخارج النسبة.
class ImportedEvent {
  const ImportedEvent({
    required this.id,
    required this.date,
    required this.title,
    this.start,
    this.end,
    this.source = 'التقويم',
    this.calendar,
  });

  final String id;
  final Day date;
  final String title;

  /// null = طوال اليوم.
  final int? start;
  final int? end;

  /// Google أو Apple أو اسم الحساب.
  final String source;
  final String? calendar;

  bool get allDay => start == null || end == null;
  String get itemKey => 'cal:$id';

  Map<String, Object?> toJson() => {
    'id': id,
    'date': date.key,
    'title': title,
    'start': start,
    'end': end,
    'source': source,
    'calendar': calendar,
  };

  factory ImportedEvent.fromJson(Map<String, Object?> j) => ImportedEvent(
    id: j['id']! as String,
    date: Day.parse(j['date']! as String),
    title: j['title']! as String,
    start: j['start'] as int?,
    end: j['end'] as int?,
    source: (j['source'] as String?) ?? 'التقويم',
    calendar: j['calendar'] as String?,
  );
}
