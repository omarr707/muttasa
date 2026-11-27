import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';

/// «تنفّس»: نافذة منبثقة فيها زهرة تتمدد مع الشهيق وتنكمش مع الزفير.
/// عند الانتهاء يُسجّل سطر التنفس لليوم (إن وُجد).
Future<void> showBreatheDialog(
  BuildContext context,
  WidgetRef ref,
  Day date, {
  String? lineKey,
}) => showGeneralDialog<void>(
  context: context,
  useRootNavigator: true,
  barrierDismissible: true,
  barrierLabel: 'إغلاق',
  barrierColor: Colors.black.withValues(alpha: .55),
  transitionDuration: const Duration(milliseconds: 260),
  transitionBuilder: (ctx, a, _, child) => FadeTransition(
    opacity: a,
    child: ScaleTransition(
      scale: Tween(
        begin: .92,
        end: 1.0,
      ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
      child: child,
    ),
  ),
  pageBuilder: (ctx, _, _) => _BreatheDialog(date: date, lineKey: lineKey),
);

class _BreatheDialog extends ConsumerStatefulWidget {
  const _BreatheDialog({required this.date, this.lineKey});
  final Day date;
  final String? lineKey;
  @override
  ConsumerState<_BreatheDialog> createState() => _BreatheDialogState();
}

enum _Phase { ready, running, done }

class _BreatheDialogState extends ConsumerState<_BreatheDialog>
    with SingleTickerProviderStateMixin {
  /// دورة كاملة: شهيق ٤ ثوانٍ وزفير ٦ ثوانٍ (نحو ٦ أنفاس في الدقيقة).
  static const _inhale = 4000;
  static const _exhale = 6000;
  static const _cycle = _inhale + _exhale;

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _cycle),
  );
  _Phase _phase = _Phase.ready;
  int _minutes = 1;
  int _breaths = 0;
  bool _inhaling = true;

  int get _total => (_minutes * 60000 / _cycle).round();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_tick);
    _ctrl.addStatusListener((s) {
      if (s != AnimationStatus.completed || _phase != _Phase.running) return;
      _breaths++;
      if (_breaths >= _total) {
        _finish();
      } else {
        _ctrl.forward(from: 0);
      }
    });
  }

  void _tick() {
    final inhale = _ctrl.value * _cycle < _inhale;
    if (inhale != _inhaling) {
      HapticFeedback.lightImpact();
      setState(() => _inhaling = inhale);
    }
  }

  /// حجم الزهرة من ٠ إلى ١: صعود ناعم في الشهيق ونزول في الزفير.
  double get _size {
    final t = _ctrl.value * _cycle;
    if (_phase != _Phase.running) return _phase == _Phase.done ? .35 : .15;
    if (t < _inhale) return Curves.easeInOut.transform(t / _inhale);
    return 1 - Curves.easeInOut.transform((t - _inhale) / _exhale);
  }

  void _start() {
    HapticFeedback.mediumImpact();
    setState(() {
      _phase = _Phase.running;
      _breaths = 0;
      _inhaling = true;
    });
    _ctrl.forward(from: 0);
  }

  Future<void> _finish() async {
    _ctrl.stop();
    unawaited(HapticFeedback.heavyImpact());
    setState(() => _phase = _Phase.done);
    final key = widget.lineKey;
    if (key != null) {
      await ref
          .read(appDataProvider.notifier)
          .toggleLine(widget.date, key, true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0E1A24);
    const petal = Color(0xFF4FD1C5);
    final label = switch (_phase) {
      _Phase.ready => 'خذ نفس عميق',
      _Phase.running => _inhaling ? 'شهيق…' : 'زفير…',
      _Phase.done => 'أحسنت',
    };
    final sub = switch (_phase) {
      _Phase.ready => 'تابع الزهرة: تكبر مع الشهيق وتصغر مع الزفير.',
      _Phase.running => '${nums(_breaths + 1)} من ${nums(_total)}',
      _Phase.done => 'سجّلنا التنفّس لليوم.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 340,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.air, color: petal, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'تنفّس',
                        style: T.cardTitle.copyWith(color: Colors.white),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'إغلاق',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: AnimatedBuilder(
                      animation: _ctrl,
                      builder: (_, _) => CustomPaint(
                        painter: _FlowerPainter(
                          size: _size,
                          rotation: _ctrl.value * math.pi / 3,
                          color: petal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      label,
                      key: ValueKey(label),
                      style: T.section.copyWith(
                        color: Colors.white,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    textAlign: TextAlign.center,
                    style: T.meta.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  if (_phase == _Phase.ready) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final m in const [1, 2, 3])
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(nums('$m د')),
                              selected: _minutes == m,
                              showCheckmark: false,
                              selectedColor: petal,
                              backgroundColor: Colors.white10,
                              labelStyle: T.label.copyWith(
                                color: _minutes == m ? bg : Colors.white,
                              ),
                              side: BorderSide.none,
                              onSelected: (_) => setState(() => _minutes = m),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: petal,
                        foregroundColor: bg,
                        shape: const StadiumBorder(),
                        textStyle: T.label.copyWith(fontSize: 15),
                      ),
                      onPressed: switch (_phase) {
                        _Phase.ready => _start,
                        _Phase.running => _finish,
                        _Phase.done => () => Navigator.of(context).pop(),
                      },
                      child: Text(switch (_phase) {
                        _Phase.ready => 'ابدأ',
                        _Phase.running => 'أنهِ الآن',
                        _Phase.done => 'تمّ',
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ست بتلات دائرية متداخلة تبتعد عن المركز وتكبر مع الشهيق.
class _FlowerPainter extends CustomPainter {
  _FlowerPainter({
    required this.size,
    required this.rotation,
    required this.color,
  });
  final double size;
  final double rotation;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final center = s.center(Offset.zero);
    final maxR = s.shortestSide / 4;
    final r = maxR * (.45 + .55 * size);
    final dist = r * size;
    final paint = Paint()
      ..color = color.withValues(alpha: .38)
      ..blendMode = BlendMode.plus;
    for (var k = 0; k < 6; k++) {
      final a = rotation + k * math.pi / 3;
      canvas.drawCircle(
        center + Offset(math.cos(a), math.sin(a)) * dist,
        r,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_FlowerPainter old) =>
      old.size != size || old.rotation != rotation;
}
