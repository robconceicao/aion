import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/cinematic_background.dart';

// ── TOKENS ───────────────────────────────────────────────────────
const _cVoid   = Color(0xFF070810);
const _cGold   = Color(0xFFC8A84A);
const _cSilver = Color(0xFF9898B8);
const _cVeil   = Color(0xFF1A1B2E);
const _cDeep   = Color(0xFF0D0E1A);
const _cShadow = Color(0xFF05060A);
const _cMist   = Color(0xFF63637E);

class AnalysisResultScreen extends StatelessWidget {
  final Map<String, dynamic> analysis;
  final String? dreamText;

  const AnalysisResultScreen({
    super.key, 
    required this.analysis,
    this.dreamText,
  });

  static const List<String> _fases = [
    'O Chamado à Aventura',
    'Recusa do Chamado',
    'Ajuda Sobrenatural',
    'A Travessia do Limiar',
    'O Ventre da Baleia',
    'A Estrada de Provas',
    'O Encontro com a Deusa',
    'A Mulher como Tentação',
    'A Apoteose',
    'A Benção Última',
    'A Travessia do Limiar de Retorno',
    'O Retorno com o Elixir'
  ];

  @override
  Widget build(BuildContext context) {
    final arquetipos = (analysis['arquetipos'] as List? ?? []);
    final simbolos   = (analysis['simbolos_chave'] as List? ?? []);
    final dream      = dreamText ?? 'Sonho registrado.';

    return Scaffold(
      backgroundColor: _cVoid,
      appBar: AppBar(
        backgroundColor: _cVoid,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _cGold),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('MITO & PSIQUE', style: GoogleFonts.cormorantGaramond(fontSize: 10, color: _cSilver, letterSpacing: 3)),
            Text('AION', style: GoogleFonts.cormorantGaramond(fontSize: 15, color: _cGold, letterSpacing: 6, fontWeight: FontWeight.bold)),
            Text('O Diário do Sonho', style: GoogleFonts.cormorantGaramond(fontSize: 10, color: _cSilver, letterSpacing: 2, fontStyle: FontStyle.italic)),
          ],
        ),
        centerTitle: true,
      ),
      body: CinematicBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('RELATO DO SONHO'),
                  _card(
                    borderColor: const Color(0xFF2E2A5C),
                    backgroundColor: const Color(0xFF0D0C1F),
                    child: Text(
                      '"$dream"',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 18,
                        color: const Color(0xFFB4B4D1),
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
  
                  _sectionHeader('SÍMBOLOS CHAVE'),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: simbolos.map((s) => _symbolCard(s['termo'] ?? 'Símbolo', s['significado'] ?? '')).toList(),
                  ),
                  const SizedBox(height: 32),
  
                  _sectionHeader('FORÇAS ARQUETÍPICAS'),
                  LayoutBuilder(builder: (context, constraints) {
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: arquetipos.map((a) {
                        final w = constraints.maxWidth > 600 ? (constraints.maxWidth / 2) - 8 : constraints.maxWidth;
                        return SizedBox(
                          width: w,
                          child: _archetypeCard(a['nome'] ?? 'Arquétipo', a['papel'] ?? ''),
                        );
                      }).toList(),
                    );
                  }),
                  const SizedBox(height: 32),
  
                  _sectionHeader('ESTÁGIO DA JORNADA'),
                  _card(
                    backgroundColor: _cDeep,
                    borderColor: _cVeil,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          analysis['jornada_estagio']?.toString().toUpperCase() ?? 'DESCONHECIDO',
                          style: const TextStyle(color: _cGold, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2),
                        ),
                        const SizedBox(height: 12),
                        _journeyBar(analysis['jornada_estagio']?.toString() ?? ''),
                        const SizedBox(height: 12),
                        Text(
                          analysis['jornada_analise'] ?? 'Análise da jornada não disponível.',
                          style: TextStyle(color: _cMist, fontSize: 11, height: 1.6),
                        ),
                        const SizedBox(height: 24),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('O Mundo Comum', style: TextStyle(color: _cMist, fontSize: 10)),
                            Text('O Retorno com o Elixir', style: TextStyle(color: _cMist, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
  
                  _sectionHeader('O ESPELHO DO MITO'),
                  _card(
                    borderColor: const Color(0xFF2E2A5C),
                    backgroundColor: const Color(0xFF0D0C1F),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          analysis['mito_comparativo'] ?? 'Mito Ancestral',
                          style: const TextStyle(color: Color(0xFFB4B4D1), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          analysis['interpretacao_mitologica'] ?? 'Interpretação mitológica não disponível.',
                          style: const TextStyle(color: Color(0xFF9898B8), fontSize: 12, height: 1.7),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
  
                  _sectionHeader('DIMENSÕES PSÍQUICAS'),
                  _card(
                    backgroundColor: _cDeep,
                    borderColor: _cVeil,
                    child: Column(
                      children: [
                        _dimensionRow('PERSONA', (analysis['dimensoes']?['persona'] ?? 5) / 10.0, const Color(0xFFE25454)),
                        const SizedBox(height: 16),
                        _dimensionRow('ANIMA/US', (analysis['dimensoes']?['anima'] ?? 5) / 10.0, _cGold),
                        const SizedBox(height: 16),
                        _dimensionRow('SOMBRA',   (analysis['dimensoes']?['sombra'] ?? 5) / 10.0, const Color(0xFF4AC8C1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
  
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _cGold, foregroundColor: _cVoid,
                            shape: const RoundedRectangleBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('SALVAR NO DIÁRIO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent, foregroundColor: _cSilver,
                          side: const BorderSide(color: _cVeil),
                          shape: const RoundedRectangleBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: const Text('Início'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(
        title,
        style: const TextStyle(color: _cMist, fontSize: 9, letterSpacing: 5, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _card({required Widget child, Color? backgroundColor, Color? borderColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor ?? _cDeep,
        border: Border.all(color: borderColor ?? _cVeil, width: 1),
      ),
      child: child,
    );
  }

  Widget _symbolCard(String term, String meaning) {
    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        color: _cDeep,
        border: Border.all(color: _cVeil),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0, top: 20, bottom: 20,
            child: Container(width: 2, color: _cGold),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(term.toUpperCase(), style: const TextStyle(color: _cGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 8),
                Text(meaning, style: TextStyle(color: _cSilver, fontSize: 9, height: 1.4), maxLines: 4, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _archetypeCard(String name, String role) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: _cShadow,
        border: Border(left: BorderSide(color: _cGold, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name.toUpperCase(), style: const TextStyle(color: _cGold, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 4),
          Text(role, style: TextStyle(color: _cMist, fontSize: 10, height: 1.5)),
        ],
      ),
    );
  }

  Widget _journeyBar(String nomeFase) {
    final idx = _fases.indexWhere((f) => nomeFase.toLowerCase().contains(f.split(' ').first.toLowerCase()));
    final phase = idx >= 0 ? idx : 0;
    final width = (phase + 1) / 12.0;
    return Container(
      height: 4, color: _cShadow,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: width,
        child: Container(color: _cGold),
      ),
    );
  }

  Widget _dimensionRow(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: _cSilver, fontSize: 9, letterSpacing: 2)),
            Text('${(value * 100).toInt()}%', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 2, color: _cShadow,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: Container(color: color),
          ),
        ),
      ],
    );
  }
}
