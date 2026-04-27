import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AionTheme {
  // --- NOVAS CORES (SPEC HTML) ---
  static const Color darkVoid   = Color(0xFF070810);
  static const Color darkDeep   = Color(0xFF0D0C18);
  static const Color darkAbyss  = Color(0xFF121120);
  static const Color shadow     = Color(0xFF1A1830);
  static const Color veil       = Color(0xFF252340);
  static const Color mist       = Color(0xFF332F58);

  static const Color gold       = Color(0xFFC8A84A);
  static const Color amber      = Color(0xFFE8C46A);
  static const Color dawn       = Color(0xFFF5DFA0);
  static const Color silver     = Color(0xFF9898B8);
  static const Color ghost      = Color(0xFFCCCCE0);
  static const Color white      = Color(0xFFEEEEF8);

  static const Color crimson    = Color(0xFFA83030);
  static const Color teal       = Color(0xFF2A8070);
  static const Color indigo     = Color(0xFF3A3870);
  
  static const Color indigoBg   = Color(0x2E3A3870);
  static const Color indigoBd   = Color(0x8C3A3870);
  static const Color greenBg    = Color(0x2E2A5A3A);
  static const Color greenBd    = Color(0x662A5A3A);
  static const Color greenText  = Color(0xFF5A9A6A);
  static const Color tealBg     = Color(0x2E2A8070);
  static const Color tealBd     = Color(0x662A8070);
  static const Color tealText   = Color(0xFF88C0C8);

  // --- COMPATIBILIDADE (MEMBROS FALTANTES) ---
  static const Color deep = darkDeep; // Alias para compatibilidade
  static const Color rose = Color(0xFFC87870);
  static const Color green = Color(0xFF5A8A5A);
  static const Color blood = Color(0xFF8B4040);
  static const Color midnight = darkVoid;

  // Estilo utilitário para telas que usam serifStyle
  static TextStyle serifStyle({double? fontSize, Color? color, FontWeight? fontWeight}) {
    return GoogleFonts.ptSerif(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
    );
  }

  // Cores de Arquétipos (da Spec)
  static Map<String, Color> archetypeColors = {
    'herói': gold,
    'sombra': crimson,
    'anima': const Color(0xFF9B6B9B),
    'animus': const Color(0xFF5A7A9B),
    'velho sábio': silver,
    'grande mãe': green,
    'trickster': teal,
    'persona': const Color(0xFF7A7A9B),
    'self': amber,
    'eterno jovem': rose,
    'inimigo': blood,
    'guerreiro': const Color(0xFFA87040),
  };

  static Color getArchetypeColor(String name) {
    final normalized = name.toLowerCase();
    for (var entry in archetypeColors.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    return gold;
  }

  // --- THEME DATA PARA O APP ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkVoid,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: amber,
        surface: darkAbyss,
        background: darkVoid,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.cormorantGaramond(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: gold,
          letterSpacing: 4,
        ),
        displayMedium: GoogleFonts.ptSerif(
          fontSize: 24,
          color: dawn,
        ),
        bodyLarge: GoogleFonts.ptSerif(
          fontSize: 16,
          color: white,
        ),
        bodyMedium: GoogleFonts.ptSerif(
          fontSize: 14,
          color: ghost,
        ),
      ),
    );
  }
}
