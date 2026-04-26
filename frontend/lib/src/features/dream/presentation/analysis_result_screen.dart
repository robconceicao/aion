import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';

class AnalysisResultScreen extends StatelessWidget {
  final Map<String, dynamic> analysis;
  final String? dreamText; // Passing the original dream text if possible

  const AnalysisResultScreen({super.key, required this.analysis, this.dreamText});

  Color _getArcColor(String name) {
    name = name.toLowerCase();
    if (name.contains('mãe')) return const Color(0xFF5A8A5A);
    if (name.contains('self')) return AionTheme.amber;
    if (name.contains('sombra')) return AionTheme.crimson;
    if (name.contains('anima') && !name.contains('animus')) return const Color(0xFF9B6B9B);
    if (name.contains('animus')) return const Color(0xFF5A7A9B);
    if (name.contains('sábio')) return AionTheme.silver;
    if (name.contains('trickster')) return AionTheme.teal;
    if (name.contains('persona')) return const Color(0xFF7A7A9B);
    if (name.contains('jovem')) return const Color(0xFFC87870);
    return AionTheme.mist;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arquetipos = (analysis['arquetipos'] as List? ?? []);
    final simbolos = (analysis['simbolos_chave'] as List? ?? []);
    final dream = dreamText ?? "Sonho registrado.";

    return Scaffold(
      backgroundColor: AionTheme.darkVoid,
      appBar: AppBar(
        title: Text('Significado segundo o contexto do sonhador', style: AionTheme.serifStyle(fontSize: 14, color: AionTheme.gold, letterSpacing: 1)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AionTheme.gold),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Aviso
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 22),
                      decoration: BoxDecoration(
                        color: AionTheme.teal.withOpacity(0.18),
                        border: Border.all(color: AionTheme.teal.withOpacity(0.4), width: 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '⚠ ${analysis['aviso'] ?? "Reflexão simbólica baseada em Jung e Campbell."}',
                        style: const TextStyle(color: Color(0xFF88C0C8), fontSize: 12, height: 1.7),
                      ),
                    ),

                    // O Sonho
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('O Sonho', color: AionTheme.silver),
                          Text(
                            '"$dream"',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: AionTheme.ghost,
                              height: 1.85,
                            ),
                          ),
                        ],
                      ),
                      leftBorderColor: AionTheme.veil,
                    ),
                    const SizedBox(height: 16),

                    // Essência
                    _buildCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('☽ Essência', color: AionTheme.gold),
                          Text(
                            '"${analysis['essencia']}"',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 17,
                              fontStyle: FontStyle.italic,
                              color: AionTheme.dawn,
                              height: 2.0,
                            ),
                          ),
                        ],
                      ),
                      leftBorderColor: AionTheme.gold,
                    ),
                    const SizedBox(height: 16),

                    // Dimensões
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Dimensões do sonho', color: AionTheme.silver),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildIntensityBar('Sombra', analysis['intensidade_sombra'] ?? 0, AionTheme.crimson, isLast: true)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildIntensityBar('Herói', analysis['intensidade_heroi'] ?? 0, AionTheme.gold, isLast: true)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildIntensityBar('Transform.', analysis['intensidade_transformacao'] ?? 0, AionTheme.teal, isLast: true)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Arquétipos
                    if (arquetipos.isNotEmpty) ...[
                      _buildLabel('⟁ Arquétipos Presentes', color: AionTheme.gold),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: arquetipos.map<Widget>((arc) {
                            final arcColor = _getArcColor(arc['nome'] ?? '');
                            return Expanded(
                              child: Container(
                                margin: EdgeInsets.only(right: arc == arquetipos.last ? 0 : 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AionTheme.darkAbyss,
                                  border: Border(
                                    top: BorderSide(color: arcColor, width: 3),
                                    bottom: const BorderSide(color: AionTheme.shadow, width: 1),
                                    left: const BorderSide(color: AionTheme.shadow, width: 1),
                                    right: const BorderSide(color: AionTheme.shadow, width: 1),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(arc['simbolo'] ?? '⌘', style: const TextStyle(fontSize: 22)),
                                    const SizedBox(height: 8),
                                    Text(arc['nome'] ?? '', style: TextStyle(color: arcColor, fontSize: 13)),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Text(
                                        arc['descricao'] ?? '',
                                        style: const TextStyle(color: AionTheme.silver, fontSize: 12, height: 1.7),
                                        overflow: TextOverflow.fade,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 2-Col: Função e Prospecção
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('⊗ Função Compensatória', color: AionTheme.amber),
                                  Text(
                                    analysis['funcao_compensatoria'] ?? '',
                                    style: const TextStyle(color: AionTheme.ghost, fontSize: 13, height: 1.8),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('✦ Prospecção', color: AionTheme.silver),
                                  Text(
                                    analysis['prospeccao'] ?? '',
                                    style: const TextStyle(color: AionTheme.ghost, fontSize: 13, height: 1.8),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('⊗ Função Compensatória', color: AionTheme.amber),
                                Text(
                                  analysis['funcao_compensatoria'] ?? '',
                                  style: const TextStyle(color: AionTheme.ghost, fontSize: 13, height: 1.8),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('✦ Prospecção', color: AionTheme.silver),
                                Text(
                                  analysis['prospeccao'] ?? '',
                                  style: const TextStyle(color: AionTheme.ghost, fontSize: 13, height: 1.8),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),

                    // Símbolos
                    if (simbolos.isNotEmpty)
                      _buildCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('⋈ Símbolos & Ampliação', color: AionTheme.gold),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: simbolos.map<Widget>((s) {
                                return Container(
                                  width: isWide ? 300 : constraints.maxWidth / 2 - 28,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AionTheme.darkAbyss,
                                    border: Border.all(color: AionTheme.shadow, width: 1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s['elemento'] ?? '', style: const TextStyle(color: AionTheme.amber, fontSize: 13, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text(s['significado'] ?? '', style: const TextStyle(color: AionTheme.silver, fontSize: 12, height: 1.7)),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Jornada
                    if (analysis['fase_jornada'] != null)
                      _buildCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('⊕ Jornada do Herói — Campbell', color: AionTheme.gold),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AionTheme.darkVoid,
                                border: Border.all(color: AionTheme.shadow, width: 1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    analysis['fase_jornada']['nome'] ?? '',
                                    style: const TextStyle(color: AionTheme.amber, fontSize: 15),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 4,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: AionTheme.shadow,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: 0.3, // Mock progression
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(colors: [AionTheme.gold, AionTheme.amber]),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    analysis['fase_jornada']['descricao'] ?? '',
                                    style: const TextStyle(color: AionTheme.silver, fontSize: 13, height: 1.8),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Mito Espelho
                    if (analysis['mito_espelho'] != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111D15), // Fundo esverdeado escuro
                          border: Border.all(color: const Color(0xFF2A5A3A).withOpacity(0.6), width: 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text('☽ MITO ESPELHO', style: GoogleFonts.cormorantGaramond(color: const Color(0xFF6B9B7B), fontSize: 14, letterSpacing: 4, fontWeight: FontWeight.bold)),
                            ),
                            Text(
                              analysis['mito_espelho']['titulo'] ?? 'Yggdrasil — a Árvore do Mundo',
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              analysis['mito_espelho']['paralelo'] ?? '',
                              style: const TextStyle(color: AionTheme.silver, fontSize: 13, height: 1.8),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Pergunta
                    if (analysis['pergunta_para_reflexao'] != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1815), // Fundo amarronzado escuro
                          border: Border.all(color: AionTheme.gold.withOpacity(0.15), width: 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Text('PERGUNTA PARA REFLEXÃO', style: GoogleFonts.cormorantGaramond(color: AionTheme.gold, fontSize: 14, letterSpacing: 5, fontWeight: FontWeight.bold)),
                            ),
                            Text(
                              '"${analysis['pergunta_para_reflexao']}"',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: 18,
                                fontStyle: FontStyle.italic,
                                color: Colors.white,
                                height: 1.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Episódios Recomendados
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111D15),
                        border: Border.all(color: const Color(0xFF2A5A3A).withOpacity(0.6), width: 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text('▶ EPISÓDIOS RECOMENDADOS — MITO & PSIQUE', style: GoogleFonts.cormorantGaramond(color: const Color(0xFF6B9B7B), fontSize: 14, letterSpacing: 4, fontWeight: FontWeight.bold)),
                          ),
                          const Text(
                            'Baseado nos arquétipos identificados neste sonho:',
                            style: TextStyle(color: Color(0xFF4A7A5A), fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AionTheme.darkVoid,
                              border: Border.all(color: const Color(0xFF6B9B7B).withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(width: 4, decoration: BoxDecoration(color: const Color(0xFF6B9B7B), borderRadius: BorderRadius.circular(4))),
                                  const SizedBox(width: 16),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text('EP07', style: TextStyle(color: Color(0xFF6B9B7B), fontSize: 18, fontFamily: 'Georgia')),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Text('A Grande Deusa', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                        SizedBox(height: 4),
                                        Text('Magna Mater — o arquétipo que as civilizações temeram e veneraram', style: TextStyle(color: AionTheme.silver, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AionTheme.darkVoid,
                              border: Border.all(color: AionTheme.gold.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(width: 4, decoration: BoxDecoration(color: AionTheme.gold, borderRadius: BorderRadius.circular(4))),
                                  const SizedBox(width: 16),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text('EP08', style: TextStyle(color: AionTheme.gold, fontSize: 18, fontFamily: 'Georgia')),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Text('O Retorno do Herói', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                        SizedBox(height: 4),
                                        Text('A individuação — tornar-se quem você sempre foi', style: TextStyle(color: AionTheme.silver, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AionTheme.gold,
                            foregroundColor: AionTheme.darkVoid,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          child: const Text('+ Novo Sonho'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: AionTheme.silver,
                            side: const BorderSide(color: AionTheme.veil),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          );
        },
      ),
    );
  }

  Widget _buildCard({required Widget child, Color? leftBorderColor, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AionTheme.darkAbyss,
        border: Border(
          top: const BorderSide(color: AionTheme.shadow, width: 1),
          bottom: const BorderSide(color: AionTheme.shadow, width: 1),
          right: const BorderSide(color: AionTheme.shadow, width: 1),
          left: BorderSide(
            color: leftBorderColor ?? AionTheme.shadow,
            width: leftBorderColor != null ? 3 : 1,
          ),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _buildLabel(String text, {required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: GoogleFonts.cormorantGaramond(
          fontSize: 16,
          color: color,
        ),
      ),
    );
  }

  Widget _buildIntensityBar(String label, dynamic valueDynamic, Color color, {bool isLast = false}) {
    double value = 0;
    if (valueDynamic is num) value = valueDynamic.toDouble();
    if (valueDynamic is String) value = double.tryParse(valueDynamic) ?? 0;
    
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: AionTheme.silver, fontSize: 12),
              ),
              Text(
                '${(value * 10).toInt()}/10',
                style: TextStyle(color: color, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AionTheme.shadow,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value > 1 ? value / 10.0 : value,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
