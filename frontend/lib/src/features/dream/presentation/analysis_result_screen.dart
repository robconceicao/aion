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
        title: Text('A REVELAÇÃO', style: AionTheme.serifStyle(fontSize: 16, color: AionTheme.gold, letterSpacing: 3)),
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
              constraints: const BoxConstraints(maxWidth: 800),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Aviso
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D2E2A),
                        border: Border.all(color: const Color(0xFF1D5A4A), width: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '⚠ ${analysis['aviso'] ?? "Reflexão simbólica baseada em Jung e Campbell."}',
                        style: const TextStyle(color: Color(0xFF5DBFA0), fontSize: 12, height: 1.6),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // O Sonho
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('O SONHO', color: AionTheme.silver),
                          Text(
                            '"$dream"',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                      leftBorderColor: const Color(0xFF888780),
                    ),
                    const SizedBox(height: 16),

                    // Essência
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('☽ ESSÊNCIA', color: AionTheme.gold),
                          Text(
                            '"${analysis['essencia']}"',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: Colors.white,
                              height: 1.9,
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
                          _buildLabel('DIMENSÕES DO SONHO', color: AionTheme.silver),
                          const SizedBox(height: 8),
                          _buildIntensityBar('Sombra', analysis['intensidade_sombra'] ?? 0, AionTheme.crimson),
                          _buildIntensityBar('Herói', analysis['intensidade_heroi'] ?? 0, AionTheme.gold),
                          _buildIntensityBar('Transformação', analysis['intensidade_transformacao'] ?? 0, AionTheme.teal, isLast: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Arquétipos
                    if (arquetipos.isNotEmpty) ...[
                      _buildLabel('⟁ ARQUÉTIPOS PRESENTES', color: AionTheme.gold),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isWide ? 3 : (constraints.maxWidth > 350 ? 2 : 1),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: isWide ? 0.9 : 0.8,
                        ),
                        itemCount: arquetipos.length,
                        itemBuilder: (context, index) {
                          final arc = arquetipos[index];
                          final arcColor = _getArcColor(arc['nome'] ?? '');
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AionTheme.darkAbyss,
                              border: Border(
                                top: BorderSide(color: arcColor, width: 3),
                                bottom: BorderSide(color: AionTheme.veil, width: 0.5),
                                left: BorderSide(color: AionTheme.veil, width: 0.5),
                                right: BorderSide(color: AionTheme.veil, width: 0.5),
                              ),
                              borderRadius: BorderRadius.circular(4),
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
                                    style: const TextStyle(color: AionTheme.silver, fontSize: 12, height: 1.5),
                                    overflow: TextOverflow.fade,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
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
                                  _buildLabel('⊗ FUNÇÃO COMPENSATÓRIA', color: AionTheme.amber),
                                  Text(
                                    analysis['funcao_compensatoria'] ?? '',
                                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.6),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('✦ PROSPECÇÃO', color: AionTheme.silver),
                                  Text(
                                    analysis['prospeccao'] ?? '',
                                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.6),
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
                                _buildLabel('⊗ FUNÇÃO COMPENSATÓRIA', color: AionTheme.amber),
                                Text(
                                  analysis['funcao_compensatoria'] ?? '',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.6),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('✦ PROSPECÇÃO', color: AionTheme.silver),
                                Text(
                                  analysis['prospeccao'] ?? '',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.6),
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
                            _buildLabel('⋈ SÍMBOLOS & AMPLIAÇÃO', color: AionTheme.gold),
                            ...simbolos.asMap().entries.map((entry) {
                              int idx = entry.key;
                              var s = entry.value;
                              bool isLast = idx == simbolos.length - 1;
                              return Container(
                                padding: const EdgeInsets.only(bottom: 12),
                                margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
                                decoration: BoxDecoration(
                                  border: isLast ? null : const Border(bottom: BorderSide(color: AionTheme.veil, width: 0.5)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: isWide ? 150 : 100,
                                      child: Container(
                                        padding: const EdgeInsets.only(right: 14),
                                        decoration: const BoxDecoration(
                                          border: Border(right: BorderSide(color: AionTheme.veil, width: 0.5)),
                                        ),
                                        child: Text(s['elemento'] ?? '', style: const TextStyle(color: AionTheme.amber, fontSize: 12)),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(s['significado'] ?? '', style: const TextStyle(color: AionTheme.silver, fontSize: 12, height: 1.6)),
                                    ),
                                  ],
                                ),
                              );
                            }),
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
                            _buildLabel('⊕ JORNADA DO HERÓI — CAMPBELL', color: AionTheme.gold),
                            Text(
                              analysis['fase_jornada']['nome'] ?? '',
                              style: const TextStyle(color: AionTheme.amber, fontSize: 15),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              height: 4,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AionTheme.veil,
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
                            const SizedBox(height: 10),
                            Text(
                              analysis['fase_jornada']['descricao'] ?? '',
                              style: const TextStyle(color: AionTheme.silver, fontSize: 13, height: 1.6),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Mito Espelho
                    if (analysis['mito_espelho'] != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF12221A),
                          border: Border.all(color: const Color(0xFF1D5A3A), width: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('☽ MITO ESPELHO', color: const Color(0xFF5A9A6A)),
                            Text(
                              analysis['mito_espelho']['titulo'] ?? '',
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              analysis['mito_espelho']['paralelo'] ?? '',
                              style: const TextStyle(color: AionTheme.silver, fontSize: 13, height: 1.6),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Pergunta
                    if (analysis['pergunta_para_reflexao'] != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                        decoration: BoxDecoration(
                          color: AionTheme.darkAbyss,
                          border: Border.all(color: const Color(0xFF3A2E14), width: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          children: [
                            _buildLabel('PERGUNTA PARA REFLEXÃO', color: AionTheme.gold),
                            Text(
                              '"${analysis['pergunta_para_reflexao']}"',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: 17,
                                fontStyle: FontStyle.italic,
                                color: Colors.white,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('NOVO RELATO'),
                      ),
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

  Widget _buildCard({required Widget child, Color? leftBorderColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AionTheme.darkAbyss,
        border: Border.all(color: AionTheme.veil, width: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        decoration: leftBorderColor != null ? BoxDecoration(
          border: Border(left: BorderSide(color: leftBorderColor, width: 3)),
        ) : null,
        padding: leftBorderColor != null ? const EdgeInsets.only(left: 12) : null,
        child: child,
      ),
    );
  }

  Widget _buildLabel(String text, {required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, letterSpacing: 3, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildIntensityBar(String label, dynamic value, Color color, {bool isLast = false}) {
    double val = (value is num) ? value.toDouble() : 0.0;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: AionTheme.silver, fontSize: 12)),
              Text('${val.toInt()}/10', style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AionTheme.veil,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: val / 10.0,
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

