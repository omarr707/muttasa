import 'package:flutter/material.dart';

/// ألوان التطبيق فوق Material 3، مأخوذة من النموذج، مع رموز حالات البطاقة.
@immutable
class MColors extends ThemeExtension<MColors> {
  const MColors({
    required this.bg,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.accent,
    required this.accent2,
    required this.accentInk,
    required this.card,
    required this.line,
    required this.kid,
    required this.nowCard,
    required this.breakBg,
    required this.pill,
    required this.pillInk,
    required this.good,
    required this.warn,
  });

  final Color bg,
      ink,
      ink2,
      muted,
      accent,
      accent2,
      accentInk,
      card,
      line,
      kid,
      nowCard,
      breakBg,
      pill,
      pillInk,
      good,
      warn;

  static const light = MColors(
    bg: Color(0xFFFFFFFF),
    ink: Color(0xFF15171C),
    ink2: Color(0xFF4A5266),
    muted: Color(0xFF7A87A8),
    accent: Color(0xFF97B4E3),
    accent2: Color(0xFF5F86CC),
    accentInk: Color(0xFF0F1A33),
    card: Color(0xFFF1F5FC),
    line: Color(0xFFD6E1F4),
    kid: Color(0xFFE7E9EF),
    nowCard: Color(0xFFDDE7F8),
    breakBg: Color(0xFFF7FAFF),
    pill: Color(0xFF0E0F12),
    pillInk: Color(0xFFFFFFFF),
    good: Color(0xFF3A9D57),
    warn: Color(0xFFC7792B),
  );

  static const dark = MColors(
    bg: Color(0xFF0F131B),
    ink: Color(0xFFEEF1F7),
    ink2: Color(0xFFB9C2D6),
    muted: Color(0xFF97A6C6),
    accent: Color(0xFF7F9FD6),
    accent2: Color(0xFFA9C2EE),
    accentInk: Color(0xFF0B1222),
    card: Color(0xFF18202E),
    line: Color(0xFF273349),
    kid: Color(0xFF1D2431),
    nowCard: Color(0xFF1F2C45),
    breakBg: Color(0xFF141B27),
    pill: Color(0xFFF1F4FA),
    pillInk: Color(0xFF0E0F12),
    good: Color(0xFF5CC27A),
    warn: Color(0xFFE0A160),
  );

  @override
  MColors copyWith() => this;

  @override
  MColors lerp(ThemeExtension<MColors>? other, double t) =>
      (other is MColors && t > .5) ? other : this;
}

extension MColorsX on BuildContext {
  MColors get c => Theme.of(this).extension<MColors>()!;
}

const fontBody = 'IBMPlexSansArabic';
const fontDisplay = 'ReadexPro';

ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.light ? MColors.light : MColors.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: c.accent2,
    brightness: b,
    surface: c.bg,
    primary: c.accent2,
    onPrimary: b == Brightness.light ? Colors.white : c.accentInk,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: fontBody,
    brightness: b,
  );
  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    extensions: [c],
    textTheme: base.textTheme.apply(
      bodyColor: c.ink,
      displayColor: c.ink,
      fontFamily: fontBody,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: fontDisplay,
        fontWeight: FontWeight.w700,
        fontSize: 20,
        color: c.ink,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.bg,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.bg,
      indicatorColor: c.card,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: fontBody,
          fontSize: 12.5,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? c.ink : c.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? c.ink : c.muted,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: c.card,
      selectedColor: c.accent,
      side: BorderSide(color: c.line),
      labelStyle: TextStyle(
        fontFamily: fontBody,
        color: c.ink,
        fontWeight: FontWeight.w600,
      ),
      shape: const StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c.accent2, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.pill,
      contentTextStyle: TextStyle(fontFamily: fontBody, color: c.pillInk),
      actionTextColor: c.accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(color: c.line, space: 1),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.accent2 : c.line,
      ),
    ),
  );
}
