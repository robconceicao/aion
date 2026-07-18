// Smoke tests leves — sem Supabase.instance nem Google Fonts (exigem binding).
import 'package:flutter_test/flutter_test.dart';
import 'package:aion/src/core/constants.dart';
import 'package:aion/src/core/theme.dart';

void main() {
  test('AionConfig aponta para o backend de produção e rotas dual', () {
    expect(AionConfig.apiBaseUrl, contains('onrender.com'));
    expect(AionConfig.analyzeUrl, endsWith('/dreams/'));
    expect(AionConfig.interviewUrl, endsWith('/dreams/interview'));
    expect(AionConfig.historyUrl, endsWith('/dreams/history'));
    expect(AionConfig.audioUrl('abc-123'), endsWith('/interpretacoes/abc-123/audio'));
  });

  test('AionTheme expõe paleta dark base (cores estáticas)', () {
    expect(AionTheme.darkVoid, isNotNull);
    expect(AionTheme.gold, isNotNull);
    expect(AionTheme.ghost, isNotNull);
    expect(AionTheme.crimson, isNotNull);
  });
}
