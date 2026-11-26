import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:schedule_core/schedule_core.dart';

import 'theme.dart';

/// حلقة الإنجاز. نرسمها بـ CustomPainter.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 118,
    this.stroke = 9,
    this.color,
    this.child,
  });

  final double progress;
  final double size;
  final double stroke;
  final Color? color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0, 1)),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
        builder: (context, v, _) => CustomPaint(
          painter: _RingPainter(v, c.line, color ?? c.ink, stroke),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.bg, this.fg, this.stroke);
  final double v;
  final Color bg;
  final Color fg;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (size.shortestSide - stroke) / 2;
    final center = size.center(Offset.zero);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, r, p..color = bg);
    if (v > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        -math.pi / 2,
        2 * math.pi * v,
        false,
        p..color = fg,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.fg != fg || o.bg != bg;
}

/// زر داكن كبسولي مثل «+ إضافة».
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.soft = false,
    this.dense = false,
    this.expand = false,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool soft;
  final bool dense;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bg = soft ? c.card : c.pill;
    final fg = soft ? c.ink : c.pillInk;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: dense ? 16 : 18, color: fg),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: dense ? 13 : 15,
            ),
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: onPressed == null ? bg.withValues(alpha: .5) : bg,
        shape: StadiumBorder(
          side: soft ? BorderSide(color: c.line) : BorderSide.none,
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: dense ? 36 : 48),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: dense ? 14 : 20,
                vertical: dense ? 6 : 10,
              ),
              child: Center(widthFactor: expand ? null : 1, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// زر رئيسي عريض بلون التطبيق، مثل «ابدأ» و«التالي».
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.accentInk,
          disabledBackgroundColor: c.line,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontDisplay,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

/// مفتاح تبديل كبسولي (الجدول الزمني | الإحصائيات).
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.small = false,
  });
  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.line),
      ),
      child: Row(
        mainAxisSize: small ? MainAxisSize.min : MainAxisSize.max,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              flex: small ? 0 : 1,
              child: Semantics(
                selected: values[i] == selected,
                button: true,
                child: GestureDetector(
                  onTap: () => onChanged(values[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(
                      vertical: small ? 6 : 9,
                      horizontal: small ? 14 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: values[i] == selected
                          ? c.accent
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: small ? 12.5 : 13.5,
                        color: values[i] == selected ? c.accentInk : c.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: fontDisplay,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// بطاقة عامة بنفس شكل النموذج.
class MCard extends StatelessWidget {
  const MCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.color,
    this.border,
    this.dashed = false,
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;
  final Color? border;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: color ?? c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: border ?? c.line, width: dashed ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// منتقي وقت بأرقام لاتينية و«ص/م»، بدل منتقي Material الذي قد يعرض أرقامًا هندية.
Future<int?> pickTime(
  BuildContext context, {
  required int initial,
  String title = 'اختر الوقت',
}) {
  var h12 = (initial ~/ 60) % 12;
  if (h12 == 0) h12 = 12;
  var minute = (initial % 60) ~/ 5 * 5;
  var pm = (initial ~/ 60) >= 12;
  return showModalBottomSheet<int>(
    useRootNavigator: true,
    context: context,
    builder: (ctx) {
      final c = ctx.c;
      Widget wheel(
        List<String> items,
        int initialIndex,
        ValueChanged<int> onChanged,
      ) => Expanded(
        child: CupertinoPicker(
          scrollController: FixedExtentScrollController(
            initialItem: initialIndex,
          ),
          itemExtent: 40,
          onSelectedItemChanged: onChanged,
          children: [
            for (final s in items)
              Center(
                child: Text(
                  s,
                  style: TextStyle(
                    fontSize: 20,
                    color: c.ink,
                    fontFamily: fontDisplay,
                  ),
                ),
              ),
          ],
        ),
      );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    children: [
                      wheel(
                        [for (var i = 1; i <= 12; i++) '$i'],
                        h12 - 1,
                        (i) => h12 = i + 1,
                      ),
                      wheel(
                        [
                          for (var m = 0; m < 60; m += 5)
                            m.toString().padLeft(2, '0'),
                        ],
                        minute ~/ 5,
                        (i) => minute = i * 5,
                      ),
                      wheel(const ['ص', 'م'], pm ? 1 : 0, (i) => pm = i == 1),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'تم',
                onPressed: () {
                  final h24 = (h12 % 12) + (pm ? 12 : 0);
                  Navigator.pop(ctx, h24 * 60 + minute);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// زر اختيار وقت يعرض «5:30 م».
class TimeField extends StatelessWidget {
  const TimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final v = await pickTime(context, initial: value, title: label);
        if (v != null) onChanged(v);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: TextStyle(color: c.ink2)),
            ),
            Text(
              fmtTime(value),
              style: const TextStyle(
                fontFamily: fontDisplay,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.schedule, size: 18, color: c.muted),
          ],
        ),
      ),
    );
  }
}

/// شرائح اختيار من قائمة.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.values,
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final List<T> values;
  final String Function(T) label;
  final bool Function(T) selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final v in values)
        ChoiceChip(
          label: Text(label(v)),
          selected: selected(v),
          showCheckmark: false,
          onSelected: (_) => onSelected(v),
        ),
    ],
  );
}

/// أيام الأسبوع بالترتيب من السبت.
class WeekdayPicker extends StatelessWidget {
  const WeekdayPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) => ChoiceChips<int>(
    values: weekOrder,
    label: (d) => arabicWeekdays[d]!,
    selected: selected.contains,
    onSelected: (d) => onChanged(
      selected.contains(d) ? ({...selected}..remove(d)) : {...selected, d},
    ),
  );
}

void toast(
  BuildContext context,
  String msg, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 4),
      action: actionLabel == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ),
  );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      text,
      style: TextStyle(fontWeight: FontWeight.w700, color: context.c.ink2),
    ),
  );
}
