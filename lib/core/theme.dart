import 'package:flutter/material.dart';

/// ألوان دليل التصميم (tokens.json) فوق Material 3.
@immutable
class MColors extends ThemeExtension<MColors> {
  const MColors({
    required this.page,
    required this.card,
    required this.sunk,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.amber,
    required this.amberSoft,
    required this.good,
    required this.goodSoft,
    required this.water,
    required this.waterSoft,
    required this.scrim,
  });

  final Color page,
      card,
      sunk,
      line,
      lineStrong,
      ink,
      ink2,
      muted,
      accent,
      accentSoft,
      onAccent,
      amber,
      amberSoft,
      good,
      goodSoft,
      water,
      waterSoft,
      scrim;

  // أسماء قديمة تشير إلى الرموز الجديدة.
  Color get bg => page;
  Color get accent2 => accent;
  Color get accentInk => onAccent;
  Color get kid => sunk;
  Color get nowCard => accentSoft;
  Color get breakBg => sunk;
  Color get pill => accent;
  Color get pillInk => onAccent;
  Color get warn => amber;
  Color get doneBg => sunk;
  Color get doneInk => muted;
  Color get amberBg => amberSoft;
  Color get amberLine => amber.withValues(alpha: .35);

  static const light = MColors(
    page: Color(0xFFF6F7FA),
    card: Color(0xFFFFFFFF),
    sunk: Color(0xFFEEF1F6),
    line: Color(0xFFE2E6EE),
    lineStrong: Color(0xFF878FA3),
    ink: Color(0xFF171B24),
    ink2: Color(0xFF475066),
    muted: Color(0xFF646D84),
    accent: Color(0xFF3D64AB),
    accentSoft: Color(0xFFE5ECF8),
    onAccent: Color(0xFFFFFFFF),
    amber: Color(0xFF95570B),
    amberSoft: Color(0xFFFBF1E1),
    good: Color(0xFF2A7745),
    goodSoft: Color(0xFFE3F3E8),
    water: Color(0xFF186C88),
    waterSoft: Color(0xFFE1F1F6),
    scrim: Color(0x660F131B),
  );

  static const dark = MColors(
    page: Color(0xFF0E1219),
    card: Color(0xFF171D28),
    sunk: Color(0xFF202838),
    line: Color(0xFF2A3345),
    lineStrong: Color(0xFF646F87),
    ink: Color(0xFFEEF1F7),
    ink2: Color(0xFFBCC4D6),
    muted: Color(0xFF8E99B2),
    accent: Color(0xFF9DB8E6),
    accentSoft: Color(0xFF1F2B42),
    onAccent: Color(0xFF0E1A33),
    amber: Color(0xFFF0B462),
    amberSoft: Color(0xFF2B2216),
    good: Color(0xFF6FCB8C),
    goodSoft: Color(0xFF16271C),
    water: Color(0xFF6CC3DE),
    waterSoft: Color(0xFF13282F),
    scrim: Color(0x99000000),
  );

  @override
  MColors copyWith() => this;

  @override
  MColors lerp(ThemeExtension<MColors>? other, double t) =>
      (other is MColors && t > .5) ? other : this;
}

/// سلم الخطوط من الدليل. الحجم النهائي يُضرب في إعداد «حجم الخط».
abstract final class T {
  static const brand = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 19,
    height: 26 / 19,
    fontWeight: FontWeight.w600,
  );
  static const stat = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w500,
  );
  static const onboardTitle = TextStyle(
    fontFamily: fontDisplay,
    fontSize: 22,
    height: 32 / 22,
    fontWeight: FontWeight.w600,
  );
  static const screenTitle = TextStyle(
    fontFamily: fontBody,
    fontSize: 17,
    height: 26 / 17,
    fontWeight: FontWeight.w600,
  );
  static const section = TextStyle(
    fontFamily: fontBody,
    fontSize: 14,
    height: 22 / 14,
    fontWeight: FontWeight.w600,
  );
  static const cardTitle = TextStyle(
    fontFamily: fontBody,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w500,
  );
  static const body = TextStyle(
    fontFamily: fontBody,
    fontSize: 14,
    height: 22 / 14,
  );
  static const meta = TextStyle(
    fontFamily: fontBody,
    fontSize: 12,
    height: 18 / 12,
  );
  static const label = TextStyle(
    fontFamily: fontBody,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );
  static const micro = TextStyle(
    fontFamily: fontBody,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w500,
  );
}

/// المسافات والزوايا.
abstract final class R {
  static const sm = 8.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const sheet = 28.0;
}

const shadowFloat = [
  BoxShadow(color: Color(0x29171B24), blurRadius: 16, offset: Offset(0, 6)),
];

extension MColorsX on BuildContext {
  MColors get c => Theme.of(this).extension<MColors>()!;
}

const fontBody = 'IBMPlexSansArabic';
const fontDisplay = 'ReadexPro';

ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.light ? MColors.light : MColors.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: c.accent,
    brightness: b,
    surface: c.page,
    primary: c.accent,
    onPrimary: c.onAccent,
    surfaceContainerLow: c.card,
    surfaceContainerHighest: c.sunk,
    outline: c.lineStrong,
    outlineVariant: c.line,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: fontBody,
    brightness: b,
  );
  return base.copyWith(
    scaffoldBackgroundColor: c.page,
    extensions: [c],
    textTheme: base.textTheme
        .apply(bodyColor: c.ink, displayColor: c.ink, fontFamily: fontBody)
        .copyWith(
          bodyMedium: T.body.copyWith(color: c.ink),
          bodyLarge: T.body.copyWith(color: c.ink, fontSize: 15),
          bodySmall: T.meta.copyWith(color: c.muted),
          titleMedium: T.cardTitle.copyWith(color: c.ink),
          titleLarge: T.screenTitle.copyWith(color: c.ink),
          labelLarge: T.section.copyWith(color: c.ink),
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.page,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: T.screenTitle.copyWith(color: c.ink),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.card,
      modalBarrierColor: c.scrim,
      showDragHandle: true,
      dragHandleColor: c.line,
      dragHandleSize: const Size(36, 4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.sheet)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.lg)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.card,
      indicatorColor: c.accentSoft,
      height: 64,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => T.micro.copyWith(
          fontSize: 11.5,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? c.ink : c.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 22,
          color: s.contains(WidgetState.selected) ? c.accent : c.muted,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: c.card,
      selectedColor: c.accentSoft,
      side: BorderSide(color: c.line),
      labelStyle: T.label.copyWith(color: c.ink, fontSize: 13),
      shape: const StadiumBorder(),
      checkmarkColor: c.accent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.card,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: T.body.copyWith(color: c.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.md),
        borderSide: BorderSide(color: c.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.md),
        borderSide: BorderSide(color: c.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(R.md),
        borderSide: BorderSide(color: c.accent, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      contentTextStyle: T.body.copyWith(color: c.page),
      actionTextColor: b == Brightness.light
          ? MColors.dark.accent
          : MColors.light.accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.md)),
    ),
    dividerTheme: DividerThemeData(color: c.line, space: 1, thickness: 1),
    listTileTheme: ListTileThemeData(
      titleTextStyle: T.body.copyWith(
        color: c.ink,
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle: T.meta.copyWith(color: c.muted),
      iconColor: c.ink2,
      minVerticalPadding: 10,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.onAccent : c.lineStrong,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.accent : c.sunk,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.accent : c.line,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.accent,
      foregroundColor: c.onAccent,
    ),
  );
}
