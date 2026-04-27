import 'package:flutter/material.dart';

class AionTheme {
  // Cores Base da Spec
  static const Color darkVoid   = Color(0xFF070810);
  static const Color darkDeep   = Color(0xFF0D0C18);
  static const Color darkAbyss  = Color(0xFF121120);
  static const Color shadow     = Color(0xFF1A1830);
  static const Color veil       = Color(0xFF252340);
  static const Color mist       = Color(0xFF332F58);

  // Accents
  static const Color gold       = Color(0xFFC8A84A);
  static const Color amber      = Color(0xFFE8C46A);
  static const Color dawn       = Color(0xFFF5DFA0);
  static const Color silver     = Color(0xFF9898B8);
  static const Color ghost      = Color(0xFFCCCCE0);
  static const Color white      = Color(0xFFEEEEF8);

  // Semânticas e Especiais
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

  // Cores de Arquétipos (da Spec)
  static Map<String, Color> archetypeColors = {
    'herói': const Color(0xFFC8A84A),
    'sombra': const Color(0xFFA83030),
    'anima': const Color(0xFF9B6B9B),
    'animus': const Color(0xFF5A7A9B),
    'velho sábio': const Color(0xFF9898B8),
    'grande mãe': const Color(0xFF5A8A5A),
    'trickster': const Color(0xFF2A8070),
    'persona': const Color(0xFF7A7A9B),
    'self': const Color(0xFFE8C46A),
    'eterno jovem': const Color(0xFFC87870),
    'inimigo': const Color(0xFF8B4040),
    'guerreiro': const Color(0xFFA87040),
  };

  static Color getArchetypeColor(String name) {
    final normalized = name.toLowerCase();
    for (var entry in archetypeColors.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    return gold;
  }
}
