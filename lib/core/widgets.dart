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
    final bg = soft ? c.card : c.accent;
    final fg = soft ? c.ink : c.onAccent;
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
            style: T.label.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: dense ? 13 : 14,
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
            constraints: BoxConstraints(minHeight: dense ? 34 : 44),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: dense ? 14 : 18,
                vertical: dense ? 4 : 8,
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
      height: 50,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.line,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(R.md),
          ),
          textStyle: T.section.copyWith(fontSize: 15),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

/// مفتاح تبديل كبسولي (الجدول الزمني | الإحصائيات).
/// تبويبات بخط سفلي، مثل «الجدول الزمني | الإحصائيات» في النموذج.
class UnderlineTabs<V> extends StatelessWidget {
  const UnderlineTabs({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });
  final List<V> values;
  final List<String> labels;
  final V selected;
  final ValueChanged<V> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 18),
          Semantics(
            selected: values[i] == selected,
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(values[i]),
              child: Container(
                padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      width: 2,
                      color: values[i] == selected
                          ? c.accent
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Text(
                  labels[i],
                  style: T.label.copyWith(
                    fontSize: 13,
                    fontWeight: values[i] == selected
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: values[i] == selected ? c.ink : c.muted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class Segmented<V> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.small = false,
  });
  final List<V> values;
  final List<String> labels;
  final V selected;
  final ValueChanged<V> onChanged;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: EdgeInsets.all(small ? 3 : 3),
      decoration: BoxDecoration(
        color: c.sunk,
        borderRadius: BorderRadius.circular(small ? 999 : R.md - 2),
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
                      vertical: small ? 4 : 8,
                      horizontal: small ? 12 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: values[i] == selected
                          ? c.card
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        small ? 999 : R.sm + 2,
                      ),
                      border: values[i] == selected
                          ? Border.all(color: c.line)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.label.copyWith(
                        fontWeight: values[i] == selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        fontSize: 13,
                        color: values[i] == selected ? c.ink : c.muted,
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
    padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
    child: Row(
      children: [
        Expanded(child: Text(text, style: T.section)),
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
        borderRadius: BorderRadius.circular(R.md),
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
                  nums(s),
                  style: T.screenTitle.copyWith(
                    fontSize: 19,
                    color: c.ink,
                    fontWeight: FontWeight.w500,
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
              Text(title, style: T.screenTitle),
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
      borderRadius: BorderRadius.circular(R.md),
      onTap: () async {
        final v = await pickTime(context, initial: value, title: label);
        if (v != null) onChanged(v);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: T.body.copyWith(color: c.ink2)),
            ),
            Text(
              fmtTime(value),
              style: T.body.copyWith(fontWeight: FontWeight.w600),
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
class ChoiceChips<V> extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.values,
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final List<V> values;
  final String Function(V) label;
  final bool Function(V) selected;
  final ValueChanged<V> onSelected;

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
    child: Text(text, style: T.label.copyWith(color: context.c.muted)),
  );
}

/// مجموعة إعدادات: عنوان صغير فوق بطاقة بزوايا كبيرة وصفوف مفصولة بخط.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.children});
  final String? title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 20, 4, 8),
            child: Text(title!, style: T.label.copyWith(color: c.muted)),
          ),
        Container(
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(R.lg),
            border: Border.all(color: c.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, indent: 16, endIndent: 16, color: c.line),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// صف إعداد: عنوان، وصف أو قيمة، وسهم أو مفتاح.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.icon,
    this.onTap,
    this.toggle,
    this.onToggle,
    this.trailing,
    this.danger = false,
  });
  final String title;
  final String? subtitle;
  final String? value;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool? toggle;
  final ValueChanged<bool>? onToggle;
  final Widget? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tap = toggle != null ? () => onToggle?.call(!toggle!) : onTap;
    return Semantics(
      button: tap != null,
      toggled: toggle,
      child: InkWell(
        onTap: tap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (icon != null) ...[
                  IconSquare(icon!, size: 32, fg: danger ? c.amber : c.ink2),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.body.copyWith(
                          color: danger ? c.amber : c.ink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: T.meta.copyWith(color: c.muted),
                        ),
                    ],
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.meta.copyWith(color: c.muted, fontSize: 13),
                    ),
                  ),
                ],
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                if (toggle != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: Transform.scale(
                      scale: .85,
                      child: Switch(value: toggle!, onChanged: onToggle),
                    ),
                  )
                else if (onTap != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 4),
                    child: Icon(Icons.chevron_left, size: 20, color: c.muted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// مربع الأيقونة في البطاقات: ٣٤ بخلفية غائرة.
class IconSquare extends StatelessWidget {
  const IconSquare(this.icon, {super.key, this.bg, this.fg, this.size = 34});
  final IconData icon;
  final Color? bg;
  final Color? fg;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg ?? c.sunk,
        borderRadius: BorderRadius.circular(R.sm + 2),
      ),
      child: Icon(icon, size: size * .55, color: fg ?? c.ink2),
    );
  }
}

/// عنوان ورقة سفلية مع وصف اختياري.
class SheetHeader extends StatelessWidget {
  const SheetHeader(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: T.screenTitle),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: T.meta.copyWith(color: c.muted, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// زر صغير محدد الإطار داخل البطاقات والأوراق.
class SmallButton extends StatelessWidget {
  const SmallButton({
    super.key,
    required this.label,
    this.onTap,
    this.primary = false,
    this.icon,
    this.selected = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool selected;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bg = primary ? c.accent : (selected ? c.accentSoft : c.card);
    final fg = primary ? c.onAccent : (selected ? c.accent : c.ink);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: primary
              ? BorderSide.none
              : BorderSide(color: selected ? c.accent : c.line),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 4),
                ],
                Text(label, style: T.label.copyWith(color: fg, fontSize: 12.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
