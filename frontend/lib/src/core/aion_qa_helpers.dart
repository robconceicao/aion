import 'dart:math' as math;

/// Helpers puros usados pela UX (busca / TTS) e pelos testes de QA.
///
/// Mantidos sem dependência de Flutter widgets para rodar em unit tests.
class AionQaHelpers {
  AionQaHelpers._();

  /// Limite seguro de caracteres enviados à busca semântica.
  static const int maxSearchQueryLength = 200;

  /// Normaliza o termo de busca: trim + colapsa espaços + corta tamanho.
  /// Retorna string vazia se só houver whitespace.
  static String normalizeSearchQuery(String raw) {
    final collapsed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.isEmpty) return '';
    if (collapsed.length <= maxSearchQueryLength) return collapsed;
    return collapsed.substring(0, maxSearchQueryLength);
  }

  /// Prepara a Leitura Simbólica para TTS (remove markdown e ruído).
  static String sanitizeSpeechText(String raw) {
    return raw
        .replaceAll(RegExp(r'\*+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Indica se o contraste aproximado entre [fg] e [bg] passa WCAG AA
  /// para texto normal (4.5:1). Cores em ARGB 0xAARRGGBB.
  static bool meetsWcagAaContrast(int fgArgb, int bgArgb) {
    return contrastRatio(fgArgb, bgArgb) >= 4.5;
  }

  /// Razão de contraste WCAG 2.x entre duas cores opacas.
  static double contrastRatio(int fgArgb, int bgArgb) {
    final l1 = _relativeLuminance(fgArgb);
    final l2 = _relativeLuminance(bgArgb);
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  static double _relativeLuminance(int argb) {
    final r = ((argb >> 16) & 0xFF) / 255.0;
    final g = ((argb >> 8) & 0xFF) / 255.0;
    final b = (argb & 0xFF) / 255.0;
    double lin(double c) =>
        c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
  }
}
