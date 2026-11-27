import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule_core/schedule_core.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import 'item_sheet.dart';

/// عرض «ساعات»: شبكة الساعات من الاستيقاظ إلى النوم. المرن له مقبض
/// تسحبه لفوق أو تحت؛ المدة ثابتة، وعند الإفلات نفحص الثابت ونسأل عن الزحزحة.
class HourGrid extends ConsumerStatefulWidget {
  const HourGrid({super.key, required this.date, required this.plan});
  final Day date;
  final DayPlan plan;
  @override
  ConsumerState<HourGrid> createState() => _HourGridState();
}

class _HourGridState extends ConsumerState<HourGrid> {
  static const _pxPerMin = 1.8;
  static const _minH = 18.0;

  /// النهاية المرئية: العنصر القصير ياخذ ارتفاعًا أدنى، فنحسب تداخله به.
  int _visEnd(PlanItem i) => i.end > i.start + (_minH / _pxPerMin).ceil()
      ? i.end
      : i.start + (_minH / _pxPerMin).ceil();
  static const _gutter = 44.0;

  String? _dragKey;
  double _dragDy = 0;

  /// التمرير التلقائي أثناء السحب قرب حافة الشاشة.
  Timer? _edge;
  double _pointerY = 0;
  final _nowKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // اليوم الحالي: ننزل لخط «الآن».
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _nowKey.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(
          ctx,
          alignment: .3,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
  }

  @override
  void dispose() {
    _edge?.cancel();
    super.dispose();
  }

  void _startEdgeScroll() {
    _edge?.cancel();
    _edge = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted || _dragKey == null) return;
      final pos = Scrollable.maybeOf(context)?.position;
      if (pos == null) return;
      final h = MediaQuery.of(context).size.height;
      const zone = 110.0;
      double v = 0;
      if (_pointerY > h - zone - 80) {
        v = 10 * ((_pointerY - (h - zone - 80)) / zone).clamp(0.2, 1.0);
      } else if (_pointerY < zone + 60) {
        v = -10 * (((zone + 60) - _pointerY) / zone).clamp(0.2, 1.0);
      }
      if (v == 0) return;
      final to = (pos.pixels + v).clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      );
      final moved = to - pos.pixels;
      if (moved == 0) return;
      pos.jumpTo(to);
      setState(() => _dragDy += moved);
    });
  }

  /// يبدأ من الاستيقاظ، أو من أول التزام لو كان أبكر (مثل وردية ليلية).
  int get _from {
    final first = [
      widget.plan.wake,
      for (final i in widget.plan.items)
        if (i.kind != ItemKind.work || i.start >= 0) i.start,
    ].reduce((a, b) => a < b ? a : b);
    return ((first.clamp(0, minutesPerDay) ~/ 5) * 5);
  }

  int get _to {
    final last = [
      widget.plan.bedtime.clamp(0, minutesPerDay),
      for (final i in widget.plan.items) i.end.clamp(0, minutesPerDay),
    ].reduce((a, b) => a > b ? a : b);
    return ((last + 59) ~/ 60) * 60;
  }

  double _y(int m) => (m - _from) * _pxPerMin;

  /// أعمدة للعناصر المتداخلة: كل عنصر يأخذ أول عمود فاضي.
  Map<String, (int, int)> _columns(List<PlanItem> items) {
    final cols = <int>[];
    final out = <String, int>{};
    for (final i in items) {
      var k = cols.indexWhere((end) => end <= i.start);
      if (k == -1) {
        cols.add(_visEnd(i));
        k = cols.length - 1;
      } else {
        cols[k] = _visEnd(i);
      }
      out[i.key] = k;
    }
    // عدد الأعمدة لكل عنصر = أكبر عمود بين المتداخلين معه + 1.
    return {
      for (final i in items)
        i.key: (
          out[i.key]!,
          items
                  .where((j) => j.start < _visEnd(i) && i.start < _visEnd(j))
                  .map((j) => out[j.key]!)
                  .reduce((a, b) => a > b ? a : b) +
              1,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final today = ref.watch(todayProvider);
    final now = ref.watch(nowMinuteProvider);
    final items = widget.plan.items
        .where((i) => i.kind != ItemKind.work)
        .toList();
    final work = widget.plan.items.where((i) => i.kind == ItemKind.work);
    final cols = _columns(items);
    final height = _y(_to) + 8;
    final canDrag = !widget.date.isBefore(today);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: _gutter,
              bottom: 8,
            ),
            child: Text(
              canDrag
                  ? 'اسحب المرن من المقبض لتغيير وقته. الثابت عليه قفل.'
                  : 'يوم مضى: للعرض فقط.',
              style: T.meta.copyWith(color: c.muted),
            ),
          ),
          LayoutBuilder(
            builder: (context, cons) {
              final w = cons.maxWidth - _gutter;
              return SizedBox(
                height: height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (
                      var h = ((_from + 59) ~/ 60) * 60;
                      h <= _to;
                      h += 60
                    ) ...[
                      PositionedDirectional(
                        start: 0,
                        top: _y(h) - 7,
                        width: _gutter - 6,
                        child: Text(
                          fmtHour(h),
                          textAlign: TextAlign.center,
                          style: T.micro.copyWith(
                            color: c.muted,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        start: _gutter,
                        end: 0,
                        top: _y(h),
                        child: Container(height: 1, color: c.line),
                      ),
                    ],
                    // الدوام خلفية خفيفة، والاستراحة فاضية فيه.
                    for (final wk in work)
                      PositionedDirectional(
                        start: _gutter,
                        end: 0,
                        top: _y(wk.start),
                        height: wk.duration * _pxPerMin,
                        child: Container(
                          decoration: BoxDecoration(
                            color: c.sunk.withValues(alpha: .7),
                            borderRadius: BorderRadius.circular(R.sm),
                          ),
                          alignment: AlignmentDirectional.topEnd,
                          padding: const EdgeInsets.all(6),
                          child: Text(
                            wk.title,
                            style: T.micro.copyWith(color: c.muted),
                          ),
                        ),
                      ),
                    if (widget.date == today && now >= _from && now <= _to)
                      PositionedDirectional(
                        key: _nowKey,
                        start: _gutter - 4,
                        end: 0,
                        top: _y(now) - 1,
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: c.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Container(height: 2, color: c.accent),
                            ),
                          ],
                        ),
                      ),
                    for (final i in items)
                      _block(context, i, cols[i.key]!, w, canDrag),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _block(
    BuildContext context,
    PlanItem i,
    (int, int) col,
    double w,
    bool canDrag,
  ) {
    final c = context.c;
    final dragging = _dragKey == i.key;
    final movable = canDrag && isMovable(i) && !i.isDoneLike;
    final colW = w / col.$2;
    final top = _y(i.start) + (dragging ? _dragDy : 0);
    final h = (i.duration * _pxPerMin).clamp(_minH, double.infinity);
    final previewStart = i.start + ((_dragDy / _pxPerMin) / 5).round() * 5;
    final done = i.isDoneLike;
    return PositionedDirectional(
      key: ValueKey(i.key),
      start: _gutter + col.$1 * colW + 2,
      width: colW - 4,
      top: top,
      height: h,
      child: Material(
        elevation: dragging ? 6 : 0,
        color: done
            ? c.sunk
            : (i.fixed && !isMovable(i) ? c.card : c.accentSoft),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(R.sm),
          side: BorderSide(color: dragging ? c.accent : c.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showItemSheet(context, ref, i, widget.date),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(6, 1, 2, 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(iconFor(i.icon), size: 14, color: c.ink2),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    dragging
                        ? '${i.title} · ${fmtTime(previewStart)}'
                        : '${i.title} · ${fmtRange(i.start, i.end % minutesPerDay)}',
                    maxLines: h > 40 ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.micro.copyWith(
                      color: done ? c.muted : c.ink,
                      fontWeight: FontWeight.w500,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (movable)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (d) {
                      HapticFeedback.selectionClick();
                      _pointerY = d.globalPosition.dy;
                      setState(() {
                        _dragKey = i.key;
                        _dragDy = 0;
                      });
                      _startEdgeScroll();
                    },
                    onVerticalDragUpdate: (d) {
                      _pointerY = d.globalPosition.dy;
                      setState(() => _dragDy += d.delta.dy);
                    },
                    onVerticalDragCancel: () {
                      _edge?.cancel();
                      setState(() {
                        _dragKey = null;
                        _dragDy = 0;
                      });
                    },
                    onVerticalDragEnd: (_) async {
                      _edge?.cancel();
                      final t = previewStart.clamp(
                        0,
                        minutesPerDay - i.duration,
                      );
                      setState(() {
                        _dragKey = null;
                        _dragDy = 0;
                      });
                      if (t == i.start) return;
                      await moveItemTo(context, ref, i, widget.date, t);
                    },
                    child: Semantics(
                      label: 'اسحب لتغيير وقت ${i.title}',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.drag_indicator,
                          size: 18,
                          color: c.accent,
                        ),
                      ),
                    ),
                  )
                else if (i.fixed && !done)
                  Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.lock_outline, size: 12, color: c.muted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
