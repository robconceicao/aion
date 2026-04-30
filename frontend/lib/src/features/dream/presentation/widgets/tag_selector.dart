import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';

// ─── CATÁLOGO DE TAGS ──────────────────────────────────────────
class AionTags {
  static const emocoes = {
    'positivas': ['Calmaria', 'Euforia', 'Alívio', 'Curiosidade',
                  'Pertencimento', 'Gratidão', 'Empoderamento'],
    'negativas': ['Ansiedade', 'Pavor', 'Impotência', 'Culpa',
                  'Solidão', 'Vergonha', 'Raiva', 'Nojo'],
    'ambivalentes': ['Confusão', 'Nostalgia', 'Melancolia',
                     'Estranhamento', 'Choque'],
  };

  static const temas = [
    'Perseguição / Fuga',
    'Desempenho / Prova',
    'Natureza / Elementos',
    'Voar / Queda livre',
    'Água / Inundação',
    'Sociais / Relacionamentos',
    'Espaciais / Labirinto',
    'Morte / Renascimento',
  ];

  static const residuos = [
    'Prazo apertado',
    'Decisão difícil',
    'Conflito no trabalho',
    'Luto / Perda',
    'Término / Separação',
    'Paixão nova',
    'Cansaço extremo',
    'Doença / Dor',
    'Tédio / Estagnação',
    'Nova fase de vida',
  ];
}

// ─── WIDGET: SELETOR DE TAGS ───────────────────────────────────
class TagSelector extends StatelessWidget {
  final String label;
  final List<String> options;
  final List<String> selected;
  final Color accentColor;
  final ValueChanged<String> onToggle;
  final int maxSelect;

  const TagSelector({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.accentColor,
    required this.onToggle,
    this.maxSelect = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label.toUpperCase(),
            style: GoogleFonts.ptSerif(
              fontSize: 9,
              letterSpacing: 3,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((tag) {
            final isSelected = selected.contains(tag);
            final canSelect = isSelected || selected.length < maxSelect;
            return GestureDetector(
              onTap: canSelect ? () => onToggle(tag) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withOpacity(0.15)
                      : AionTheme.darkAbyss,
                  border: Border.all(
                    color: isSelected
                        ? accentColor.withOpacity(0.6)
                        : AionTheme.shadow,
                  ),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.ptSerif(
                    fontSize: 11,
                    color: isSelected
                        ? accentColor
                        : AionTheme.silver.withOpacity(canSelect ? 0.7 : 0.3),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
