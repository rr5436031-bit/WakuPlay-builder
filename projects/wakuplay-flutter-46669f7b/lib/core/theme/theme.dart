import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final body = GoogleFonts.robotoTextTheme(base.textTheme).apply(bodyColor: C.text, displayColor: C.text);
  return base.copyWith(
    scaffoldBackgroundColor: C.background,
    colorScheme: const ColorScheme.dark(primary: C.primary, surface: C.surface, error: C.danger),
    textTheme: body.copyWith(
      titleLarge: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.montserrat(fontSize: 17, fontWeight: FontWeight.w700),
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
