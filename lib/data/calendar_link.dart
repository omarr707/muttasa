import 'package:schedule_core/schedule_core.dart';

/// تقويم من الجهاز يقدر المستخدم يربطه.
class DeviceCal {
  const DeviceCal({
    required this.id,
    required this.name,
    required this.source,
    this.colorHex,
  });
  final String id;
  final String name;

  /// Google أو Apple أو اسم الحساب.
  final String source;
  final String? colorHex;
}

/// التقويمات المربوطة: تُحفظ مع آخر نسخة محلية من مواعيدها.
class CalendarLink {
  const CalendarLink({this.calendars = const [], this.events = const []});

  final List<DeviceCal> calendars;
  final List<ImportedEvent> events;

  bool get linked => calendars.isNotEmpty;

  Map<String, Object?> toJson() => {
    'calendars': [
      for (final c in calendars)
        {'id': c.id, 'name': c.name, 'source': c.source, 'color': c.colorHex},
    ],
    'events': events.map((e) => e.toJson()).toList(),
  };

  factory CalendarLink.fromJson(Map<String, Object?> j) => CalendarLink(
    calendars: [
      for (final c in ((j['calendars'] as List?) ?? const []).cast<Map>())
        DeviceCal(
          id: c['id'] as String,
          name: (c['name'] as String?) ?? '',
          source: (c['source'] as String?) ?? 'التقويم',
          colorHex: c['color'] as String?,
        ),
    ],
    events: [
      for (final e in ((j['events'] as List?) ?? const []).cast<Map>())
        ImportedEvent.fromJson(e.cast<String, Object?>()),
    ],
  );
}
