import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const brand = Color(0xFF6C3CE1);
  static const brandGradient = LinearGradient(
    colors: [Color(0xFF4C2AD6), Color(0xFF8C3CE6), Color(0xFFF0629A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: brightness,
    );
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: brightness,
    );
    return base.copyWith(
      // Cairo covers Arabic and Latin nicely for the app chrome.
      textTheme: GoogleFonts.cairoTextTheme(base.textTheme),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
