import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AionTheme {
  // Palette from Mito & Psique
  static const Color darkVoid = Color(0xFF070810);
  static const Color deep = Color(0xFF0D0C18);
  static const Color darkAbyss = Color(0xFF121120);
  static const Color shadow = Color(0xFF1A1830);
  static const Color veil = Color(0xFF252340);
  static const Color mist = Color(0xFF332F58);
  static const Color gold = Color(0xFFC8A84A);
  static const Color amber = Color(0xFFE8C46A);
  static const Color dawn = Color(0xFFF5DFA0);
  static const Color blood = Color(0xFF7A1E1E);
  static const Color crimson = Color(0xFFA83030);
  static const Color silver = Color(0xFF9898B8);
  static const Color ghost = Color(0xFFCCCCE0);
  static const Color teal = Color(0xFF2A8070);
  static const Color indigo = Color(0xFF3A3870);
  static const Color green = Color(0xFF2A5A3A);
  static const Color rose = Color(0xFF8A3050);

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkVoid,
    primaryColor: gold,
    colorScheme: const ColorScheme.dark(
      primary: gold,
      secondary: amber,
      surface: darkAbyss,
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.cormorantGaramond(
        fontSize: 42,
        fontWeight: FontWeight.w400,
        letterSpacing: 4.0,
        color: gold,
      ),
      displayMedium: GoogleFonts.cormorantGaramond(
        fontSize: 32,
        fontWeight: FontWeight.w300,
        letterSpacing: 2.0,
        color: Colors.white,
      ),
      bodyLarge: GoogleFonts.ptSerif(
        fontSize: 16,
        height: 1.8,
        color: Colors.white.withOpacity(0.9),
      ),
      bodyMedium: GoogleFonts.ptSerif(
        fontSize: 14,
        color: silver,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.cormorantGaramond(
        fontSize: 20,
        letterSpacing: 4.0,
        color: gold,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: darkVoid,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        textStyle: GoogleFonts.ptSerif(
          fontSize: 12,
          letterSpacing: 4.0,
          fontWeight: FontWeight.bold,
        ),
        shape: const BeveledRectangleBorder(
          borderRadius: BorderRadius.zero, // Sharp edges for premium look
        ),
      ),
    ),
  );

  static TextStyle serifStyle({
    double? fontSize,
    Color? color,
    double? letterSpacing,
    FontWeight? fontWeight,
  }) {
    return GoogleFonts.cormorantGaramond(
      fontSize: fontSize,
      color: color,
      letterSpacing: letterSpacing,
      fontWeight: fontWeight,
    );
  }
}
