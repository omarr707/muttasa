import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import 'core/theme.dart';
import 'router.dart';
import 'services/notifications.dart';
import 'state/providers.dart';

class MuttasaApp extends ConsumerStatefulWidget {
  const MuttasaApp({super.key, this.notifications = true});

  /// يُطفأ في الاختبارات.
  final bool notifications;

  @override
  ConsumerState<MuttasaApp> createState() => _MuttasaAppState();
}

class _MuttasaAppState extends ConsumerState<MuttasaApp>
    with WidgetsBindingObserver {
  Timer? _debounce;
  StreamSubscription<NotificationTap>? _taps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onOpen());
    if (widget.notifications) {
      _taps = NotificationService.instance.taps.stream.listen(_handleTap);
      final launch = NotificationService.instance.launchTap;
      if (launch != null) {
        NotificationService.instance.launchTap = null;
        WidgetsBinding.instance.addPostFrameCallback((_) => _handleTap(launch));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _taps?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onOpen();
  }

  /// عند الفتح: تحديث الساعة، إقفال الأيام الماضية، وإعادة جدولة التنبيهات.
  Future<void> _onOpen() async {
    ref.read(clockProvider.notifier).refresh();
    if (!ref.read(appDataProvider).onboarded) return;
    await ref.read(appDataProvider.notifier).closePastDays();
    _scheduleSoon();
  }

  void _scheduleSoon() {
    if (!widget.notifications) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      if (!mounted || !ref.read(appDataProvider).onboarded) return;
      final engine = ref.read(engineProvider);
      final s = ref.read(appDataProvider).settings;
      final today = ref.read(todayProvider);
      final now = ref.read(nowMinuteProvider);
      NotificationService.instance.reschedule(
        notificationWindow(engine, s, today, now),
      );
    });
  }

  Future<void> _handleTap(NotificationTap t) async {
    final ctrl = ref.read(appDataProvider.notifier);
    final plan = ref.read(dayPlanProvider(t.date));
    final item = plan.byKey(t.itemKey);
    if (item != null && t.action == 'done') {
      await ctrl.markDone(t.date, item);
    } else if (item != null && t.action == 'snooze') {
      final slot = postponeHourSlot(plan, item, ref.read(nowMinuteProvider));
      if (slot != null) await ctrl.postponeHour(t.date, item, slot);
    }
    ref.read(selectedDayProvider.notifier).set(t.date);
    ref
        .read(routerProvider)
        .go(
          item == null
              ? '/day'
              : '/day?focus=${Uri.encodeQueryComponent(t.itemKey)}',
        );
  }

  @override
  Widget build(BuildContext context) {
    // أي تغيير في الجدول يعيد حساب التنبيهات القادمة.
    ref.listen(engineProvider, (_, _) => _scheduleSoon());
    ref.listen(todayProvider, (_, _) => _onOpen());
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'مُتَّسَع',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
    );
  }
}
