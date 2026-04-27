import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/cinematic_background.dart';

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
    final theme      = Theme.of(context);

    return Scaffold(
      backgroundColor: AionTheme.darkVoid,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AionTheme.gold),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('MITO & PSIQUE', style: GoogleFonts.ptSerif(fontSize: 10, color: AionTheme.silver, letterSpacing: 4)),
            Text('AION', style: GoogleFonts.cormorantGaramond(fontSize: 18, color: AionTheme.gold, letterSpacing: 6, fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: CinematicBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('RELATO DO SONHO'),
                  _card(
                    borderColor: AionTheme.indigo.withOpacity(0.3),
                    backgroundColor: AionTheme.darkAbyss.withOpacity(0.5),
                    child: Text(
                      '"$dream"',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 18,
                        color: AionTheme.dawn,
                        fontStyle: FontStyle.italic,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  _sectionHeader('SÍMBOLOS CHAVE'),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: simbolos.map((s) => _symbolCard(s['termo'] ?? s['elemento'] ?? 'Símbolo', s['significado'] ?? '')).toList(),
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
                          child: _archetypeCard(a['nome'] ?? 'Arquétipo', a['descricao'] ?? a['papel'] ?? ''),
                        );
                      }).toList(),
                    );
                  }),
                  const SizedBox(height: 32),

                  _sectionHeader('ESTÁGIO DA JORNADA'),
                  _card(
                    backgroundColor: AionTheme.darkAbyss.withOpacity(0.3),
                    borderColor: AionTheme.veil,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (analysis['fase_jornada']?['nome'] ?? analysis['jornada_estagio'] ?? 'DESCONHECIDO').toString().toUpperCase(),
                          style: const TextStyle(color: AionTheme.gold, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2),
                        ),
                        const SizedBox(height: 16),
                        _journeyBar(analysis['fase_jornada']?['nome'] ?? analysis['jornada_estagio'] ?? ''),
                        const SizedBox(height: 16),
                        Text(
                          analysis['fase_jornada']?['descricao'] ?? analysis['jornada_analise'] ?? 'Análise da jornada não disponível.',
                          style: const TextStyle(color: AionTheme.silver, fontSize: 11, height: 1.7),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  _sectionHeader('DIMENSÕES PSÍQUICAS'),
                  _card(
                    backgroundColor: AionTheme.darkAbyss.withOpacity(0.2),
                    borderColor: AionTheme.veil,
                    child: Column(
                      children: [
                        _dimensionRow('PERSONA', (analysis['intensidade_heroi'] ?? 5) / 10.0, AionTheme.gold),
                        const SizedBox(height: 20),
                        _dimensionRow('SOMBRA', (analysis['intensidade_sombra'] ?? 5) / 10.0, Colors.redAccent.withOpacity(0.7)),
                        const SizedBox(height: 20),
                        _dimensionRow('TRANSFORMAÇÃO', (analysis['intensidade_transformacao'] ?? 5) / 10.0, AionTheme.amber),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AionTheme.gold,
                        foregroundColor: AionTheme.darkVoid,
                        shape: const RoundedRectangleBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: const Text('INTEGRAR AO DIÁRIO ☽', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                    ),
                  ),
                  const SizedBox(height: 60),
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
        style: GoogleFonts.ptSerif(color: AionTheme.ghost, fontSize: 9, letterSpacing: 5, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _card({required Widget child, Color? backgroundColor, Color? borderColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: backgroundColor ?? AionTheme.darkAbyss.withOpacity(0.4),
        border: Border.all(color: borderColor ?? AionTheme.veil, width: 1),
      ),
      child: child,
    );
  }

  Widget _symbolCard(String term, String meaning) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: AionTheme.darkAbyss.withOpacity(0.5),
        border: Border.all(color: AionTheme.veil),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(width: 3, color: AionTheme.gold),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(term.toUpperCase(), style: const TextStyle(color: AionTheme.gold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 10),
                Text(meaning, style: const TextStyle(color: AionTheme.silver, fontSize: 10, height: 1.4), maxLines: 4, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _archetypeCard(String name, String description) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AionTheme.darkVoid.withOpacity(0.4),
        border: const Border(left: BorderSide(color: AionTheme.gold, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name.toUpperCase(), style: const TextStyle(color: AionTheme.gold, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: AionTheme.ghost, fontSize: 11, height: 1.6)),
        ],
      ),
    );
  }

  Widget _journeyBar(String nomeFase) {
    final idx = _fases.indexWhere((f) => nomeFase.toLowerCase().contains(f.split(' ').first.toLowerCase()));
    final phase = idx >= 0 ? idx : 0;
    final width = (phase + 1) / 12.0;
    return Container(
      height: 6, 
      width: double.infinity,
      decoration: BoxDecoration(
        color: AionTheme.darkAbyss,
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: width,
        child: Container(
          decoration: BoxDecoration(
            color: AionTheme.gold,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(color: AionTheme.gold.withOpacity(0.3), blurRadius: 8, spreadRadius: 1),
            ],
          ),
        ),
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
            Text(label, style: const TextStyle(color: AionTheme.silver, fontSize: 10, letterSpacing: 2)),
            Text('${(value * 100).toInt()}%', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 3, 
          width: double.infinity,
          decoration: BoxDecoration(
            color: AionTheme.darkVoid,
            borderRadius: BorderRadius.circular(1.5),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
