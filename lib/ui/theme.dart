import 'package:flutter/material.dart';

/// Design tokens from the Figma Make mock, with type/contrast scaled up for
/// real phones (min 11sp, body 15sp, muted text ≥ 4.5:1 on cream).
class T {
  static const ink = Color(0xFF17233C);
  static const ink2 = Color(0xFF24314C);
  static const inkLine = Color(0xFF34415A);
  static const inkMuted = Color(0xFFAAB4C6);
  static const lime = Color(0xFFD7EF6E);
  static const cream = Color(0xFFF8F6EF);
  static const card = Colors.white;
  static const line = Color(0xFFE3E1D9);
  static const muted = Color(0xFF5F665F);
  static const faint = Color(0xFF7A807A);
  static const olive = Color(0xFF4F6420);
  static const oliveSoft = Color(0xFFEDF4D5);
  static const oliveLine = Color(0xFFCEDBA8);
  static const streak = Color(0xFFB65A2C);
  static const teal = Color(0xFF2D6B59);
  static const tealSoft = Color(0xFFE2F0EB);
  static const red = Color(0xFFB3412E);
  static const redSoft = Color(0xFFF8E3DE);
  static const amber = Color(0xFF8A5A00);
  static const amberSoft = Color(0xFFFBEFD5);

  static const display = 'Manrope';
  static const body = 'DMSans';

  static const r = 16.0;

  static TextStyle h(double size, {Color color = ink, FontWeight w = FontWeight.w800}) =>
      TextStyle(fontFamily: display, fontSize: size, fontWeight: w, color: color, letterSpacing: -0.4, height: 1.15);

  static TextStyle b(double size, {Color color = ink, FontWeight w = FontWeight.w400, double height = 1.45}) =>
      TextStyle(fontFamily: body, fontSize: size, fontWeight: w, color: color, height: height);

  static TextStyle kicker({Color color = olive}) =>
      TextStyle(fontFamily: body, fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 1.4);

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: body,
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(seedColor: ink, primary: ink, secondary: lime, surface: cream),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink, fontFamily: body),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF4F3EE),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: oliveLine, width: 1.5)),
        hintStyle: b(15, color: faint),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: b(14, color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
