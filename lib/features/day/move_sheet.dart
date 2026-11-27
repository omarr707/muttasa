import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';

/// حركة واحدة في جلسة «تمرين حركة قصير».
class _Move {
  const _Move(this.title, this.hint, this.icon);
  final String title;
  final String hint;
  final IconData icon;
}

/// حركات خفيفة معروفة لكسر الجلوس، بلا أدوات ولا مجهود عالٍ.
const _moves = [
  _Move(
    'قف ومدّ ذراعيك لفوق',
    'شد جسمك للأعلى ونفَس عميق',
    Icons.accessibility_new,
  ),
  _Move('لفّ كتفيك للخلف', 'ببطء، عشر لفّات', Icons.sync),
  _Move('ميّل رقبتك يمين ويسار', 'بهدوء، بدون ضغط', Icons.face_outlined),
  _Move('امشِ في مكانك', 'ارفع ركبتيك بخفة', Icons.directions_walk),
  _Move('قم واجلس من الكرسي', 'عشر مرات بهدوء', Icons.chair_outlined),
  _Move(
    'مدّ ظهرك للأمام',
    'يداك على الطاولة، وظهرك مستقيم',
    Icons.self_improvement,
  ),
];

/// «تمرين حركة قصير»: نافذة تفاعلية مثل التنفّس، أربع حركات بعدّاد.
/// عند الانتهاء يُسجّل السطر وتنحسب وقفة.
Future<void> showMoveDialog(
  BuildContext context,
  WidgetRef ref,
  Day date, {
  String? lineKey,
  int seed = 0,
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
  pageBuilder: (ctx, _, _) =>
      _MoveDialog(date: date, lineKey: lineKey, seed: seed),
);

class _MoveDialog extends ConsumerStatefulWidget {
  const _MoveDialog({required this.date, this.lineKey, this.seed = 0});
  final Day date;
  final String? lineKey;
  final int seed;
  @override
  ConsumerState<_MoveDialog> createState() => _MoveDialogState();
}

enum _Phase { ready, running, done }

class _MoveDialogState extends ConsumerState<_MoveDialog>
    with SingleTickerProviderStateMixin {
  static const _seconds = 30;

  late final List<_Move> _set = [
    for (var k = 0; k < 4; k++) _moves[(widget.seed + k) % _moves.length],
  ];
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  _Phase _phase = _Phase.ready;
  int _index = 0;
  int _left = _seconds;
  Timer? _timer;

  void _start() {
    HapticFeedback.mediumImpact();
    setState(() {
      _phase = _Phase.running;
      _index = 0;
      _left = _seconds;
    });
    _bob.repeat(reverse: true);
    _tick();
  }

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_left > 1) {
        setState(() => _left--);
      } else {
        _next();
      }
    });
  }

  void _next() {
    if (_index >= _set.length - 1) {
      _finish();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _index++;
      _left = _seconds;
    });
    _tick();
  }

  Future<void> _finish() async {
    _timer?.cancel();
    _bob.stop();
    unawaited(HapticFeedback.heavyImpact());
    setState(() => _phase = _Phase.done);
    final ctrl = ref.read(appDataProvider.notifier);
    await ctrl.countLight(widget.date, 'stand', 1);
    final key = widget.lineKey;
    if (key != null) await ctrl.toggleLine(widget.date, key, true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF1B1630);
    const tint = Color(0xFFF6AD55);
    final m = _set[_index];
    final title = switch (_phase) {
      _Phase.ready => 'حرّك جسمك دقيقتين',
      _Phase.running => m.title,
      _Phase.done => 'أحسنت',
    };
    final sub = switch (_phase) {
      _Phase.ready =>
        '${nums(_set.length)} حركات خفيفة، كل وحدة ${nums('$_seconds')} ثانية.',
      _Phase.running =>
        '${m.hint} · ${nums(_index + 1)} من ${nums(_set.length)}',
      _Phase.done => 'سجّلنا الحركة لليوم.',
    };
    final progress = _phase == _Phase.running
        ? (_seconds - _left) / _seconds
        : (_phase == _Phase.done ? 1.0 : 0.0);
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
                      const Icon(Icons.directions_run, color: tint, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'تمرين حركة',
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
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 8,
                            color: tint,
                            backgroundColor: Colors.white10,
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _bob,
                          builder: (_, child) => Transform.translate(
                            offset: Offset(
                              0,
                              _phase == _Phase.running
                                  ? -10 * math.sin(_bob.value * math.pi)
                                  : 0,
                            ),
                            child: child,
                          ),
                          child: Icon(
                            _phase == _Phase.done ? Icons.check : m.icon,
                            size: 84,
                            color: tint,
                          ),
                        ),
                        if (_phase == _Phase.running)
                          Positioned(
                            bottom: 34,
                            child: Text(
                              nums('$_left'),
                              style: T.section.copyWith(color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      title,
                      key: ValueKey(title),
                      textAlign: TextAlign.center,
                      style: T.section.copyWith(
                        color: Colors.white,
                        fontSize: 20,
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
                  Row(
                    children: [
                      if (_phase == _Phase.running) ...[
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white24),
                                shape: const StadiumBorder(),
                              ),
                              onPressed: _next,
                              child: const Text('التالي'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: tint,
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
                      ),
                    ],
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
