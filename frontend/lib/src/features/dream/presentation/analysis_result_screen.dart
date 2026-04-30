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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AionTheme.darkVoid,
      appBar: AppBar(
        backgroundColor: AionTheme.darkVoid,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AionTheme.gold, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'MAPA ARQUETÍPICO',
          style: GoogleFonts.ptSerif(
            fontSize: 10,
            letterSpacing: 4,
            color: AionTheme.gold,
          ),
        ),
        centerTitle: true,
      ),
      body: CinematicBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildEthicalWarning(),
                    const SizedBox(height: 14),
                    _buildDreamSection(),
                    const SizedBox(height: 14),
                    _buildEssenceSection(),
                    const SizedBox(height: 14),
                    _buildDimensionsSection(),
                    const SizedBox(height: 14),
                    _buildArchetypesSection(),
                    const SizedBox(height: 14),
                    _buildTwoColumnSection(),
                    const SizedBox(height: 14),
                    _buildSymbolsSection(),
                    const SizedBox(height: 14),
                    _buildHeroJourneySection(),
                    const SizedBox(height: 14),
                    _buildMirrorMythSection(),
                    const SizedBox(height: 14),
                    _buildReflectionQuestionSection(),
                    const SizedBox(height: 14),
                    _buildRecommendedEpisodesSection(),
                    const SizedBox(height: 48),
                    _buildNavigationButtons(context),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(BuildContext context) {
    return Center(
      child: Column(
        children: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AionTheme.gold),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: const RoundedRectangleBorder(),
            ),
            child: Text(
              'VOLTAR AO DIÁRIO',
              style: GoogleFonts.ptSerif(
                fontSize: 12,
                letterSpacing: 3,
                color: AionTheme.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }


  // ① AVISO ÉTICO
  Widget _buildEthicalWarning() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AionTheme.tealBg,
        border: Border.all(color: AionTheme.tealBd),
      ),
      child: Text(
        '⚠ Esta análise é uma reflexão simbólica baseada em Jung e Campbell — não substitui acompanhamento psicológico profissional.',
        style: GoogleFonts.ptSerif(
          fontSize: 12,
          color: AionTheme.tealText,
          height: 1.7,
        ),
      ),
    );
  }

  // ② O SONHO
  Widget _buildDreamSection() {
    return _card(
      borderLeft: const BorderSide(color: AionTheme.veil, width: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('O SONHO', color: AionTheme.silver),
          Text(
            '"${dreamText ?? 'Sonho registrado.'}"',
            style: GoogleFonts.ptSerif(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AionTheme.ghost,
              height: 1.85,
            ),
          ),
        ],
      ),
    );
  }

  // ③ ESSÊNCIA
  Widget _buildEssenceSection() {
    return _card(
      borderLeft: const BorderSide(color: AionTheme.gold, width: 3),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('☽ ESSÊNCIA', color: AionTheme.gold),
          Text(
            '"${analysis['essencia'] ?? 'A essência do seu sonho está sendo tecida...'}"',
            style: GoogleFonts.ptSerif(
              fontSize: 17,
              fontStyle: FontStyle.italic,
              color: AionTheme.dawn,
              height: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  // ④ DIMENSÕES DO SONHO
  Widget _buildDimensionsSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('DIMENSÕES DO SONHO', color: AionTheme.silver),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(width: 100, child: _buildDimItem('Sombra', (analysis['intensidade_sombra'] ?? 5).toDouble(), AionTheme.crimson)),
              SizedBox(width: 100, child: _buildDimItem('Herói', (analysis['intensidade_heroi'] ?? 5).toDouble(), AionTheme.gold)),
              SizedBox(width: 120, child: _buildDimItem('Transformação', (analysis['intensidade_transformacao'] ?? 5).toDouble(), AionTheme.teal)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDimItem(String name, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: const TextStyle(fontSize: 12, color: AionTheme.silver)),
            Text('${value.toInt()}/10', style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          height: 4,
          width: double.infinity,
          color: AionTheme.shadow,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value / 10,
            child: Container(color: color),
          ),
        ),
      ],
    );
  }

  // ⑤ ARQUÉTIPOS PRESENTES
  Widget _buildArchetypesSection() {
    final arquetipos = (analysis['arquetipos'] as List? ?? []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: arquetipos.map((a) {
            final name = a['nome'] ?? 'Arquétipo';
            final color = AionTheme.getArchetypeColor(name);
            return Container(
              width: (MediaQuery.of(context).size.width - 52) / 2,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AionTheme.darkAbyss,
                border: Border.all(color: AionTheme.shadow),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 3, width: double.infinity, color: color),
                  const SizedBox(height: 12),
                  Text(a['simbolo'] ?? '◯', style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 8),
                  Text(
                    name.toUpperCase(),
                    style: TextStyle(fontSize: 11, color: color, letterSpacing: 1, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    a['descricao'] ?? '',
                    style: const TextStyle(fontSize: 11, color: AionTheme.silver, height: 1.5),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ⑥ FUNÇÃO COMPENSATÓRIA + PROSPECÇÃO
  Widget _buildTwoColumnSection() {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        SizedBox(
          width: (MediaQuery.of(context).size.width - 54) / 2,
          child: _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('⊗ FUNÇÃO COMPENSATÓRIA', color: AionTheme.amber),
                Text(
                  analysis['funcao_compensatoria'] ?? '',
                  style: const TextStyle(fontSize: 12, color: AionTheme.ghost, height: 1.7),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: (MediaQuery.of(context).size.width - 54) / 2,
          child: _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('✦ PROSPECÇÃO', color: AionTheme.silver),
                Text(
                  analysis['prospeccao'] ?? '',
                  style: const TextStyle(fontSize: 12, color: AionTheme.ghost, height: 1.7),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ⑦ SÍMBOLOS & AMPLIAÇÃO
  Widget _buildSymbolsSection() {
    final simbolos = (analysis['simbolos_chave'] as List? ?? []);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('⋈ SÍMBOLOS & AMPLIAÇÃO', color: AionTheme.gold),
          const SizedBox(height: 4),
          ...simbolos.asMap().entries.map((entry) {
            final s = entry.value;
            final isLast = entry.key == simbolos.length - 1;
            return Container(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
              decoration: BoxDecoration(
                border: isLast ? null : const Border(bottom: BorderSide(color: AionTheme.shadow)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 130,
                    padding: const EdgeInsets.only(right: 14),
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: AionTheme.veil)),
                    ),
                    child: Text(
                      (s['elemento'] ?? s['termo'] ?? '').toString(),
                      style: const TextStyle(color: AionTheme.amber, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      (s['significado'] ?? '').toString(),
                      style: const TextStyle(color: AionTheme.silver, fontSize: 12, height: 1.7),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ⑧ JORNADA DO HERÓI
  Widget _buildHeroJourneySection() {
    final fase = analysis['fase_jornada'] ?? {};
    final nome = fase['nome'] ?? 'O Mundo Comum';
    
    // Lista de fases para cálculo de progresso
    const fasesOrder = [
      'Mundo Comum', 'Chamado', 'Recusa', 'Mentor', 'Travessia', 
      'Testes', 'Caverna', 'Provação', 'Recompensa', 'Caminho', 
      'Ressurreição', 'Retorno'
    ];
    int index = fasesOrder.indexWhere((f) => nome.toString().contains(f));
    if (index == -1) index = 0;
    double progress = (index + 1) / 12;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('⊕ JORNADA DO HERÓI — CAMPBELL', color: AionTheme.gold),
          Text(nome, style: const TextStyle(fontSize: 15, color: AionTheme.amber)),
          const SizedBox(height: 8),
          Container(
            height: 4,
            width: double.infinity,
            color: AionTheme.shadow,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(color: AionTheme.gold),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('O Mundo Comum', style: TextStyle(fontSize: 10, color: AionTheme.mist)),
              Text('O Retorno com o Elixir', style: TextStyle(fontSize: 10, color: AionTheme.mist)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            fase['descricao'] ?? '',
            style: const TextStyle(fontSize: 13, color: AionTheme.silver, height: 1.8),
          ),
        ],
      ),
    );
  }

  // ⑨ MITO ESPELHO
  Widget _buildMirrorMythSection() {
    final mito = analysis['mito_espelho'] ?? {};
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AionTheme.indigoBg,
        border: Border.all(color: AionTheme.indigoBd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('☽ MITO ESPELHO', color: const Color(0xFF8888C8)),
          Text(
            mito['titulo'] ?? '',
            style: const TextStyle(fontSize: 14, color: AionTheme.ghost, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            mito['paralelo'] ?? '',
            style: const TextStyle(fontSize: 13, color: AionTheme.silver, height: 1.8),
          ),
        ],
      ),
    );
  }

  // ⑩ PERGUNTA PARA REFLEXÃO
  Widget _buildReflectionQuestionSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: AionTheme.darkDeep,
        border: Border.all(color: AionTheme.gold.withOpacity(0.28)),
      ),
      child: Column(
        children: [
          _label('PERGUNTA PARA REFLEXÃO', color: AionTheme.gold, center: true),
          const SizedBox(height: 16),
          Text(
            '"${analysis['pergunta_para_reflexao'] ?? ''}"',
            textAlign: TextAlign.center,
            style: GoogleFonts.ptSerif(
              fontSize: 18,
              color: AionTheme.dawn,
              fontStyle: FontStyle.italic,
              height: 1.9,
            ),
          ),
        ],
      ),
    );
  }

  // ⑪ EPISÓDIOS RECOMENDADOS
  Widget _buildRecommendedEpisodesSection() {
    final episodios = analysis['episodios_recomendados'] as List?;
    if (episodios == null || episodios.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AionTheme.greenBg,
        border: Border.all(color: AionTheme.greenBd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('▶ EPISÓDIOS RECOMENDADOS — MITO & PSIQUE', color: AionTheme.greenText),
          Text(
            'Baseado nos arquétipos identificados neste sonho:',
            style: TextStyle(fontSize: 12, color: AionTheme.mist),
          ),
          const SizedBox(height: 16),
          ...episodios.map((ep) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _buildEpisodeCard(
                ep['numero'] ?? 'EP--', 
                ep['titulo'] ?? '', 
                ep['subtitulo'] ?? '', 
                AionTheme.getArchetypeColor(ep['arquetipo_relacionado'] ?? '')
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEpisodeCard(String num, String title, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AionTheme.darkAbyss,
        border: Border.all(color: AionTheme.shadow),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 3, height: 40, color: color),
          const SizedBox(width: 16),
          Text(num, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300, color: color, letterSpacing: 1)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, color: AionTheme.dawn)),
                const SizedBox(height: 3),
                Text(sub, style: const TextStyle(fontSize: 11, color: AionTheme.silver)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // WIDGETS AUXILIARES
  Widget _card({required Widget child, EdgeInsets? padding, BorderSide? borderLeft}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AionTheme.darkAbyss,
        border: Border.all(color: AionTheme.shadow),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: borderLeft != null ? Border(left: borderLeft) : null,
        ),
        padding: borderLeft != null ? const EdgeInsets.only(left: 14) : null,
        child: child,
      ),
    );
  }

  Widget _label(String text, {required Color color, bool center = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Text(
            text,
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontSize: 8.5,
              letterSpacing: 1.5,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
