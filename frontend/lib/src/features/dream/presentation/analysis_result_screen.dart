import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';

class AnalysisResultScreen extends StatelessWidget {
  final Map<String, dynamic> analysis;

  const AnalysisResultScreen({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arquetipos = (analysis['arquetipos'] as List? ?? []);
    final simbolos = (analysis['simbolos_chave'] as List? ?? []);

    return Scaffold(
      backgroundColor: AionTheme.darkVoid,
      appBar: AppBar(
        title: const Text('A REVELAÇÃO'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AionTheme.gold),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                border: Border.all(color: Colors.teal.withOpacity(0.3)),
              ),
              child: Text(
                '⚠ ${analysis['aviso']}',
                style: const TextStyle(color: Colors.tealAccent, fontSize: 11),
              ),
            ),
            const SizedBox(height: 32),
            // Essence
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: AionTheme.gold, width: 4)),
                color: AionTheme.darkAbyss,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text('☽ ESSÊNCIA DO SONHO', 
                    style: TextStyle(fontSize: 9, letterSpacing: 5, color: AionTheme.gold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${analysis['essencia']}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 18, 
                      fontStyle: FontStyle.italic,
                      color: AionTheme.amber,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Intensity Bars
            _buildSectionLabel('DIMENSÕES DA PSIQUE'),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AionTheme.darkAbyss,
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  _buildIntensityBar('Sombra', analysis['intensidade_sombra'] ?? 0, AionTheme.crimson),
                  _buildIntensityBar('Herói', analysis['intensidade_heroi'] ?? 0, AionTheme.gold),
                  _buildIntensityBar('Transformação', analysis['intensidade_transformacao'] ?? 0, Colors.teal),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Archetypes Grid
            _buildSectionLabel('⟁ ARQUÉTIPOS PRESENTES'),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: arquetipos.length,
              itemBuilder: (context, index) {
                final arc = arquetipos[index];
                return _buildGridCard(
                  arc['simbolo'] ?? '⟁',
                  arc['nome'] ?? 'Arquétipo',
                  arc['descricao'] ?? '',
                  AionTheme.gold,
                );
              },
            ),
            const SizedBox(height: 32),
            // Symbols List (2nd Grid or vertical list)
            _buildSectionLabel('⋈ SÍMBOLOS & AMPLIAÇÃO'),
            ...simbolos.map((s) => _buildSymbolRow(s['elemento'] ?? '', s['significado'] ?? '')).toList(),
            const SizedBox(height: 32),
            // Hero's Journey
            if (analysis['fase_jornada'] != null) ...[
              _buildSectionLabel('⊕ JORNADA DO HERÓI'),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AionTheme.darkAbyss,
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${analysis['fase_jornada']['nome']}',
                      style: const TextStyle(fontSize: 16, color: AionTheme.amber),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${analysis['fase_jornada']['descricao']}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
            // Myth Mirror
            if (analysis['mito_espelho'] != null) ...[
              _buildSectionLabel('☽ MITO ESPELHO'),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3870).withOpacity(0.2),
                  border: Border.all(color: const Color(0xFF3A3870).withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${analysis['mito_espelho']['titulo']}',
                      style: const TextStyle(fontSize: 16, color: AionTheme.silver),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${analysis['mito_espelho']['paralelo']}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
            // Question
            Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(color: AionTheme.gold.withOpacity(0.2)),
                  color: AionTheme.darkAbyss,
                ),
                child: Column(
                  children: [
                    const Text('PERGUNTA PARA REFLEXÃO', 
                      style: TextStyle(fontSize: 9, letterSpacing: 4, color: AionTheme.gold),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '"${analysis['pergunta_para_reflexao']}"',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                        color: AionTheme.amber,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 60),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('RETORNAR AO DIÁRIO'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        label,
        style: const TextStyle(fontSize: 9, letterSpacing: 5, color: AionTheme.gold),
      ),
    );
  }

  Widget _buildIntensityBar(String label, dynamic value, Color color) {
    double val = (value is num) ? value.toDouble() : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: val / 10,
              backgroundColor: Colors.white.withOpacity(0.05),
              color: color,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard(String icon, String title, String desc, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AionTheme.darkAbyss,
        border: Border(
          top: BorderSide(color: color, width: 3),
          bottom: BorderSide(color: color.withOpacity(0.2)),
          left: BorderSide(color: color.withOpacity(0.2)),
          right: BorderSide(color: color.withOpacity(0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: color, fontSize: 13, letterSpacing: 1)),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              desc,
              style: const TextStyle(color: AionTheme.silver, fontSize: 11, height: 1.5),
              overflow: TextOverflow.fade,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymbolRow(String element, String meaning) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AionTheme.darkAbyss,
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            padding: const EdgeInsets.only(right: 16),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: AionTheme.mist)),
            ),
            child: Text(element, style: const TextStyle(color: AionTheme.amber, fontSize: 12)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(meaning, style: const TextStyle(color: AionTheme.silver, fontSize: 12, height: 1.6)),
          ),
        ],
      ),
    );
  }
}
