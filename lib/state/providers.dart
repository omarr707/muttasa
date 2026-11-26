import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';
import 'package:uuid/uuid.dart';

import '../data/defaults.dart';
import '../data/repository.dart';

final repositoryProvider = Provider<Repository>(
  (ref) => throw UnimplementedError('يُحقن في main'),
);
final defaultsProvider = Provider<Defaults>(
  (ref) => throw UnimplementedError('يُحقن في main'),
);
final initialDataProvider = Provider<AppData>((ref) => const AppData());

/// الساعة: تتحدث كل 20 ثانية. يمكن تثبيتها في الاختبارات.
class Clock extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    _timer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => state = DateTime.now(),
    );
    ref.onDispose(() => _timer?.cancel());
    return DateTime.now();
  }

  void refresh() => state = DateTime.now();
}

final clockProvider = NotifierProvider<Clock, DateTime>(Clock.new);

/// اليوم الحالي: يتغير مرة عند منتصف الليل فقط.
final todayProvider = Provider<Day>(
  (ref) => Day.fromDateTime(ref.watch(clockProvider)),
);

/// الدقيقة الحالية من منتصف الليل.
final nowMinuteProvider = Provider<int>((ref) {
  final n = ref.watch(clockProvider);
  return n.hour * 60 + n.minute;
});

final appDataProvider = NotifierProvider<AppController, AppData>(
  AppController.new,
);

final prayerCalcProvider = Provider<PrayerCalculator?>((ref) {
  final p = ref.watch(appDataProvider.select((d) => d.profile));
  if (p == null) return null;
  return PrayerCalculator.forProfile(p);
});

/// المحرك للبيانات الحالية. يُعاد بناؤه عند أي كتابة أو تغيّر اليوم.
final engineProvider = Provider<ScheduleEngine>((ref) {
  final d = ref.watch(appDataProvider);
  final today = ref.watch(todayProvider);
  final calc = ref.watch(prayerCalcProvider);
  return ScheduleEngine(buildInput(d, calc, today));
});

EngineInput buildInput(
  AppData d,
  PrayerCalculator? calc,
  Day today, {
  List<Rule>? rules,
}) => EngineInput(
  profile: d.profile!,
  settings: d.settings,
  rules: rules ?? d.rules,
  oneOffs: d.oneOffs,
  overrides: d.overrides,
  carries: d.carries,
  logs: d.logs,
  prayers: calc?.forDay ?? (_) => DayPrayers.neutral,
  today: today,
  nowMinute: 0,
);

/// dayPlanProvider(date): يجمع القواعد السارية وسياق اليوم وتعديلاته، ثم يستدعي المحرك.
final dayPlanProvider = Provider.family<DayPlan, Day>(
  (ref, d) => ref.watch(engineProvider).day(d),
);

/// اليوم المعروض في «يومي».
class SelectedDay extends Notifier<Day> {
  @override
  Day build() => ref.watch(todayProvider);
  void set(Day d) => state = d;
}

final selectedDayProvider = NotifierProvider<SelectedDay, Day>(SelectedDay.new);

const _uuid = Uuid();
String newId() => _uuid.v4();

/// حالات الاستخدام: كل كتابة تذهب للقاعدة ثم تُحدّث الحالة، فتُبطَل الأيام المتأثرة.
class AppController extends Notifier<AppData> {
  @override
  AppData build() => ref.read(initialDataProvider);

  Repository get _repo => ref.read(repositoryProvider);
  PrayerCalculator? _calc;
  UserProfile? _calcFor;

  /// محرك للحالة الحالية. لا نقرأ engineProvider هنا لأنه يعتمد على هذا الـ Notifier.
  ScheduleEngine get _engine {
    final p = state.profile!;
    if (_calc == null || !identical(_calcFor, p)) {
      _calc = PrayerCalculator.forProfile(p);
      _calcFor = p;
    }
    return ScheduleEngine(buildInput(state, _calc, _today));
  }

  Day get _today => ref.read(todayProvider);
  int get _nowMin => ref.read(nowMinuteProvider);

  // --------------------------------------------------------------------------
  // التهيئة والإعدادات
  // --------------------------------------------------------------------------

  Future<void> completeOnboarding(UserProfile profile, List<Rule> rules) async {
    await _repo.saveProfile(profile);
    await _repo.saveSettings(state.settings);
    for (final r in rules) {
      await _repo.upsertRule(r);
    }
    await _repo.setMeta('lastClosed', profile.joinDay.prev.key);
    state = state.copyWith(
      profile: profile,
      rules: rules,
      meta: {...state.meta, 'lastClosed': profile.joinDay.prev.key},
    );
  }

  Future<void> updateProfile(UserProfile p) async {
    await _repo.saveProfile(p);
    state = state.copyWith(profile: p);
  }

  Future<void> updateSettings(AppSettings s) async {
    await _repo.saveSettings(s);
    state = state.copyWith(settings: s);
  }

  // --------------------------------------------------------------------------
  // التسجيل الصادق
  // --------------------------------------------------------------------------

  ItemLog _baseLog(Day d, PlanItem i) =>
      state.logs[recordKey(d, i.key)] ??
      ItemLog(date: d, itemKey: i.key, status: ItemStatus.pending);

  Future<void> _putLog(ItemLog l) async {
    await _repo.upsertLog(l);
    state = state.copyWith(
      logs: {...state.logs, recordKey(l.date, l.itemKey): l},
    );
  }

  /// «تمت»: الوقت المخطط يُحفظ منفصلًا عن وقت التنفيذ.
  Future<void> markDone(
    Day d,
    PlanItem i, {
    int? at,
    int? value,
    int? value2,
  }) async {
    final when = at ?? (d == _today ? _nowMin : i.start);
    await _putLog(
      _baseLog(d, i).copyWith(
        status: ItemStatus.done,
        plannedStart: i.start,
        plannedEnd: i.end,
        doneAt: when,
        value: value,
        value2: value2,
        category: i.category,
        title: i.title,
        clearTimer: true,
      ),
    );
  }

  Future<void> setStatus(Day d, PlanItem i, ItemStatus s) => _putLog(
    _baseLog(d, i).copyWith(
      status: s,
      plannedStart: i.start,
      plannedEnd: i.end,
      category: i.category,
      title: i.title,
      clearDoneAt: true,
      clearTimer: true,
    ),
  );

  /// تراجع: يرجع العنصر لحالته قبل التسجيل.
  Future<void> undo(Day d, String key) async {
    await _repo.deleteLog(d, key);
    final logs = {...state.logs}..remove(recordKey(d, key));
    // إن كان مؤجلًا لبكرة نحذف الترحيل أيضًا.
    final carries = state.carries
        .where((c) => !(c.fromDate == d && c.itemKey == key))
        .toList();
    for (final c in state.carries.where(
      (c) => c.fromDate == d && c.itemKey == key,
    )) {
      await _repo.deleteCarry(c.id);
    }
    state = state.copyWith(logs: logs, carries: carries);
  }

  /// الماء: «4 من 8» بنقرة مع تراجع.
  Future<void> addWater(Day d, int delta) async {
    final cur = state.logs[recordKey(d, 'water')];
    final v = ((cur?.value ?? 0) + delta).clamp(0, 30);
    await _putLog(
      (cur ?? ItemLog(date: d, itemKey: 'water', status: ItemStatus.pending))
          .copyWith(value: v, category: 'water'),
    );
  }

  Future<void> toggleLine(Day d, String key, bool done) async {
    if (!done) return undo(d, key);
    await _putLog(
      ItemLog(
        date: d,
        itemKey: key,
        status: ItemStatus.done,
        doneAt: _nowMin,
        category: 'light',
      ),
    );
  }

  // --------------------------------------------------------------------------
  // المؤقت: طوابع زمنية حقيقية. بدء جلسة ثانية يوقف الأولى ويحفظ تقدمها.
  // --------------------------------------------------------------------------

  Future<void> startTimer(Day d, PlanItem i) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (final l in state.logs.values.where((l) => l.timerRunning).toList()) {
      final acc = l.timerAccumSeconds + ((nowMs - l.timerStartedAt!) ~/ 1000);
      await _putLog(l.copyWith(clearTimer: true, timerAccumSeconds: acc));
    }
    await _putLog(
      _baseLog(d, i).copyWith(
        plannedStart: i.start,
        plannedEnd: i.end,
        timerStartedAt: nowMs,
        category: i.category,
        title: i.title,
      ),
    );
  }

  Future<void> pauseTimer(Day d, PlanItem i) async {
    final l = _baseLog(d, i);
    if (!l.timerRunning) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _putLog(
      l.copyWith(
        clearTimer: true,
        timerAccumSeconds:
            l.timerAccumSeconds + ((nowMs - l.timerStartedAt!) ~/ 1000),
      ),
    );
  }

  Future<void> finishTimer(Day d, PlanItem i) async {
    final l = _baseLog(d, i);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final total =
        l.timerAccumSeconds +
        (l.timerRunning ? (nowMs - l.timerStartedAt!) ~/ 1000 : 0);
    await _putLog(
      l.copyWith(
        status: ItemStatus.done,
        plannedStart: i.start,
        plannedEnd: i.end,
        doneAt: d == _today ? _nowMin : i.end,
        actualSeconds: total,
        clearTimer: true,
        timerAccumSeconds: total,
        category: i.category,
        title: i.title,
      ),
    );
  }

  // --------------------------------------------------------------------------
  // النقل والتأجيل
  // --------------------------------------------------------------------------

  Future<void> setOverride(DayOverride o) async {
    await _repo.upsertOverride(o);
    state = state.copyWith(
      overrides: {...state.overrides, recordKey(o.date, o.itemKey): o},
    );
  }

  Future<void> clearOverride(Day d, String key) async {
    await _repo.deleteOverride(d, key);
    state = state.copyWith(
      overrides: {...state.overrides}..remove(recordKey(d, key)),
    );
  }

  /// «هذه المرة فقط».
  Future<void> moveOnce(Day d, PlanItem i, int start) => setOverride(
    DayOverride(date: d, itemKey: i.key, start: start, reason: 'نقل يدوي'),
  );

  /// «من اليوم فصاعدًا»: نسخة جديدة من القاعدة بوقت مفضل جديد.
  Future<void> moveFromToday(Day d, PlanItem i, int start) async {
    final rule = _engine
        .rulesOn(d)
        .where((r) => r.key == i.ruleKey)
        .firstOrNull;
    if (rule == null || rule.config is! FlexConfig) {
      return moveOnce(d, i, start);
    }
    final c = rule.config as FlexConfig;
    final plan = _engine.day(d);
    // نختار النافذة التي يقع فيها الوقت الجديد، وإلا «أي وقت».
    var win = Window.any;
    for (final w in [
      Window.afterFajr,
      Window.morning,
      Window.afternoon,
      Window.night,
    ]) {
      final s = ScheduleEngine.windowSpan(
        w,
        plan.prayers,
        plan.wake,
        plan.bedtime,
      );
      if (start >= s.start && start + c.duration <= s.end) {
        win = w;
        break;
      }
    }
    final windows = [...c.windows];
    if (windows.isEmpty) {
      windows.add(win);
    } else {
      windows[0] = win;
    }
    await saveRule(
      rule,
      c.copyWith(preferred: start, windows: windows),
      from: d,
    );
    // التعديل اليدوي القديم لهذا اليوم لم يعد لازمًا.
    if (state.overrides.containsKey(recordKey(d, i.key))) {
      await clearOverride(d, i.key);
    }
  }

  Future<void> postponeHour(Day d, PlanItem i, int start) => setOverride(
    DayOverride(date: d, itemKey: i.key, start: start, reason: 'أجّل ساعة'),
  );

  /// بكرة: CarryOver، ولا يتكرر إذا العنصر موجود بكرة.
  Future<void> postponeTo(Day d, PlanItem i, Day to, {int? start}) async {
    if (to == d && start != null) return postponeHour(d, i, start);
    await setStatus(d, i, ItemStatus.postponed);
    final target = _engine.day(to);
    if (target.hasKey(i.key)) {
      if (start != null) {
        await setOverride(
          DayOverride(date: to, itemKey: i.key, start: start, reason: 'مؤجل'),
        );
      }
      return;
    }
    final c = CarryOver(
      id: newId(),
      fromDate: d,
      itemKey: i.key,
      title: i.title,
      duration: i.duration,
      toDate: to,
      start: start,
      counted: i.counted,
    );
    await _repo.upsertCarry(c);
    state = state.copyWith(carries: [...state.carries, c]);
  }

  /// موعده القادم حسب التكرار: يُسجّل مؤجلًا فقط.
  Future<void> postponeNext(Day d, PlanItem i) =>
      setStatus(d, i, ItemStatus.postponed);

  Future<void> applyRearrange(Day d, Map<String, int> moves) async {
    final next = {...state.overrides};
    for (final e in moves.entries) {
      final o = DayOverride(
        date: d,
        itemKey: e.key,
        start: e.value,
        reason: 'أعد ترتيب يومي',
      );
      await _repo.upsertOverride(o);
      next[recordKey(d, e.key)] = o;
    }
    state = state.copyWith(overrides: next);
  }

  Future<void> setWorkOff(Day d, bool off) async {
    if (off) {
      await setOverride(
        DayOverride(date: d, itemKey: 'work', off: true, reason: 'إجازة اليوم'),
      );
    } else {
      await clearOverride(d, 'work');
    }
  }

  Future<void> skipFixedToday(Day d, PlanItem i) => setOverride(
    DayOverride(date: d, itemKey: i.key, off: true, reason: 'ليس اليوم'),
  );

  // --------------------------------------------------------------------------
  // «+ إضافة»
  // --------------------------------------------------------------------------

  Future<void> addOneOff(OneOff o) async {
    await _repo.upsertOneOff(o);
    state = state.copyWith(oneOffs: [...state.oneOffs, o]);
  }

  Future<void> deleteOneOff(String id) async {
    await _repo.deleteOneOff(id);
    state = state.copyWith(
      oneOffs: state.oneOffs.where((o) => o.id != id).toList(),
    );
  }

  // --------------------------------------------------------------------------
  // «روتيني»: قواعد مؤرّخة
  // --------------------------------------------------------------------------

  /// يحسب قائمة القواعد بعد الحفظ دون كتابة، للمعاينة.
  List<Rule> rulesAfterSave(
    Rule? old,
    RuleConfig cfg, {
    required Day from,
    String? key,
  }) {
    final rules = [...state.rules];
    if (old == null) {
      rules.add(
        Rule(
          id: newId(),
          key: key ?? 'custom:${newId()}',
          validFrom: from,
          config: cfg,
        ),
      );
      return rules;
    }
    // نسخة سارية من «from» لنفس المفتاح.
    final idx = rules.indexWhere((r) => r.id == old.id);
    if (!old.validFrom.isBefore(from)) {
      rules[idx] = old.copyWith(config: cfg);
    } else {
      rules[idx] = old.copyWith(validTo: from.prev);
      rules.add(
        Rule(
          id: newId(),
          key: old.key,
          validFrom: from,
          validTo: old.validTo,
          config: cfg,
        ),
      );
    }
    return rules;
  }

  Future<void> saveRule(
    Rule? old,
    RuleConfig cfg, {
    required Day from,
    String? key,
  }) async {
    final next = rulesAfterSave(old, cfg, from: from, key: key);
    final changed = next.where((r) => !state.rules.contains(r));
    for (final r in changed) {
      await _repo.upsertRule(r);
    }
    state = state.copyWith(rules: next);
  }

  /// حذف من يوم بعينه: الأيام السابقة تبقى بقواعدها.
  Future<void> removeRule(String key, {required Day from}) async {
    final next = <Rule>[];
    for (final r in state.rules) {
      if (r.key != key) {
        next.add(r);
        continue;
      }
      if (!r.validFrom.isBefore(from)) {
        await _repo.deleteRule(r.id);
        continue;
      }
      if (r.validTo == null || !r.validTo!.isBefore(from)) {
        final closed = r.copyWith(validTo: from.prev);
        await _repo.upsertRule(closed);
        next.add(closed);
      } else {
        next.add(r);
      }
    }
    state = state.copyWith(rules: next);
  }

  /// وضع الإيقاف المؤقت للروتين.
  Future<void> pauseRule(String key, {required Day from, Day? until}) async {
    final next = <Rule>[];
    for (final r in state.rules) {
      if (r.key == key && (r.validTo == null || !r.validTo!.isBefore(from))) {
        final p = r.copyWith(pausedFrom: from, pausedUntil: until);
        await _repo.upsertRule(p);
        next.add(p);
      } else {
        next.add(r);
      }
    }
    state = state.copyWith(rules: next);
  }

  Future<void> resumeRule(String key) async {
    final next = <Rule>[];
    for (final r in state.rules) {
      if (r.key == key && r.pausedFrom != null) {
        final p = r.copyWith(clearPause: true);
        await _repo.upsertRule(p);
        next.add(p);
      } else {
        next.add(r);
      }
    }
    state = state.copyWith(rules: next);
  }

  // --------------------------------------------------------------------------
  // إقفال الأيام الماضية
  // --------------------------------------------------------------------------

  /// عند أول فتح بعد منتصف الليل: نكتب لكل عنصر محسوب لم يُسجّل صف Occurrence
  /// بوقته المخطط وحالته النهائية (missed أو auto). بعدها لا يغيّر أي تعديل التاريخ.
  Future<int> closePastDays() async {
    if (state.profile == null) return 0;
    final today = _today;
    final last = state.meta['lastClosed'] == null
        ? state.profile!.joinDay.prev
        : Day.parse(state.meta['lastClosed']!);
    var d = last.next;
    if (today.difference(d) > 31) d = today.add(-31);
    final engine = _engine;
    final newLogs = <ItemLog>[];
    while (d.isBefore(today)) {
      final plan = engine.day(d);
      for (final i in plan.items) {
        if (!i.counted || i.log != null) continue;
        if (i.status != ItemStatus.missed && i.status != ItemStatus.auto) {
          continue;
        }
        newLogs.add(
          ItemLog(
            date: d,
            itemKey: i.key,
            status: i.status,
            plannedStart: i.start,
            plannedEnd: i.end,
            category: i.category,
            title: i.title,
          ),
        );
      }
      d = d.next;
    }
    if (newLogs.isNotEmpty) await _repo.batchLogs(newLogs);
    final closed = today.prev.key;
    await _repo.setMeta('lastClosed', closed);
    state = state.copyWith(
      logs: {
        ...state.logs,
        for (final l in newLogs) recordKey(l.date, l.itemKey): l,
      },
      meta: {...state.meta, 'lastClosed': closed},
    );
    return newLogs.length;
  }

  // --------------------------------------------------------------------------
  // النسخ الاحتياطي
  // --------------------------------------------------------------------------

  Map<String, Object?> exportBackup() => _repo.exportJson(state);

  Future<void> importBackup(AppData d) async {
    await _repo.replaceAll(d);
    state = await _repo.loadAll();
  }

  Future<void> resetAll() async {
    await _repo.wipe();
    state = const AppData();
  }
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
