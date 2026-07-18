// QA-01 / QA-02 / QA-03 — asserts automatizáveis (sem device físico).
import 'package:flutter_test/flutter_test.dart';
import 'package:aion/src/core/aion_qa_helpers.dart';
import 'package:aion/src/core/theme.dart';

void main() {
  group('QA-02 — busca no diário (normalização e bordas)', () {
    test('trim e colapso de espaços', () {
      expect(AionQaHelpers.normalizeSearchQuery('  perda   de  algo  '), 'perda de algo');
    });

    test('vazio / só whitespace → string vazia', () {
      expect(AionQaHelpers.normalizeSearchQuery(''), isEmpty);
      expect(AionQaHelpers.normalizeSearchQuery('   \t  '), isEmpty);
    });

    test('acentos e caracteres especiais preservados', () {
      expect(
        AionQaHelpers.normalizeSearchQuery('coração & "sombra" — à noite'),
        'coração & "sombra" — à noite',
      );
    });

    test('termos muito longos são truncados', () {
      final long = 'a' * 500;
      final out = AionQaHelpers.normalizeSearchQuery(long);
      expect(out.length, AionQaHelpers.maxSearchQueryLength);
      expect(out, 'a' * AionQaHelpers.maxSearchQueryLength);
    });

    test('não há histórico embutido no helper (campo limpo)', () {
      // Contrato: normalize nunca injeta sugestões como "perda"/"voo".
      final out = AionQaHelpers.normalizeSearchQuery('x');
      expect(out, 'x');
      expect(out.contains('perda'), isFalse);
      expect(out.contains('voo'), isFalse);
    });
  });

  group('QA-03 — TTS (sanitização da Leitura Simbólica)', () {
    test('remove marcadores markdown ** e colapsa espaços', () {
      const raw = '  O **Herói** atravessa\n\na  **noite**.  ';
      expect(
        AionQaHelpers.sanitizeSpeechText(raw),
        'O Herói atravessa a noite.',
      );
    });

    test('texto vazio permanece vazio (player deve falhar com mensagem)', () {
      expect(AionQaHelpers.sanitizeSpeechText('   '), isEmpty);
      expect(AionQaHelpers.sanitizeSpeechText('***'), isEmpty);
    });
  });

  group('QA-01 — contraste tema escuro (WCAG AA texto normal)', () {
    // ARGB opacos do AionTheme (evita Color.value deprecado).
    const voidBg = 0xFF070810; // darkVoid
    const abyssBg = 0xFF121120; // darkAbyss
    const gold = 0xFFC8A84A;
    const amber = 0xFFE8C46A;
    const ghost = 0xFFCCCCE0;
    const silver = 0xFF9898B8;

    test('gold sobre darkVoid passa AA', () {
      expect(AionQaHelpers.meetsWcagAaContrast(gold, voidBg), isTrue);
      expect(AionTheme.gold.toARGB32(), gold);
    });

    test('ghost sobre darkVoid passa AA', () {
      expect(AionQaHelpers.meetsWcagAaContrast(ghost, voidBg), isTrue);
      expect(AionTheme.ghost.toARGB32(), ghost);
    });

    test('amber sobre darkVoid passa AA', () {
      expect(AionQaHelpers.meetsWcagAaContrast(amber, voidBg), isTrue);
      expect(AionTheme.amber.toARGB32(), amber);
    });

    test('silver sobre darkVoid (texto secundário) — documentar razão', () {
      final ratio = AionQaHelpers.contrastRatio(silver, voidBg);
      // silver é secundário; se < 4.5, ainda é legível como UI auxiliar.
      expect(ratio, greaterThan(3.0));
      expect(AionQaHelpers.contrastRatio(silver, abyssBg), greaterThan(3.0));
      expect(AionTheme.silver.toARGB32(), silver);
    });
  });
}
