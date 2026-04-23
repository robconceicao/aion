import 'package:flutter/material.dart';
import '../../../../src/core/theme.dart';
import 'record_dream_screen.dart';

class DreamDiaryScreen extends StatelessWidget {
  const DreamDiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: AionTheme.darkVoid,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 60),
              const Center(
                child: Text('☽', 
                  style: TextStyle(fontSize: 50, color: Colors.white, fontWeight: FontWeight.w100)
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'MITO & PSIQUE',
                style: theme.textTheme.displayLarge?.copyWith(fontSize: 10, letterSpacing: 8),
              ),
              const SizedBox(height: 24),
              Text(
                'DIÁRIO DE SONHOS',
                style: theme.textTheme.displayLarge?.copyWith(fontSize: 32),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Text(
                  '"Os sonhos são autorretratos espontâneos da psique — mensagens do inconsciente que buscam o equilíbrio."',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic, color: Colors.white70),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '— Carl Gustav Jung',
                style: theme.textTheme.bodyMedium?.copyWith(color: AionTheme.mist, fontSize: 12),
              ),
              const SizedBox(height: 60),
              // Grid of 3 Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    _buildNavCard(theme, '⟁', 'Arquétipos', 'Identificados no seu sonho'),
                    const SizedBox(width: 12),
                    _buildNavCard(theme, '⊕', 'Jornada', 'Fase da Jornada do Herói'),
                    const SizedBox(width: 12),
                    _buildNavCard(theme, '✦', 'Símbolos', 'Ampliação junguiana'),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              // CTA Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () async {
                      final transcription = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(builder: (context) => const RecordDreamScreen()),
                      );
                      
                      if (transcription != null && transcription.isNotEmpty) {
                        // Handle transition to loading/analysis
                        debugPrint('Relato recebido: $transcription');
                      }
                    },
                    child: const Text('REGISTRAR SONHO'),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              // Footer disclaimer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Text(
                  '⚠ Esta ferramenta oferece reflexão simbólica baseada nas teorias de Jung e Campbell. Não é terapia, não é diagnóstico psicológico.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10, height: 1.6),
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavCard(ThemeData theme, String icon, String title, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        decoration: BoxDecoration(
          color: AionTheme.darkAbyss,
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24, color: AionTheme.gold)),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.displayMedium?.copyWith(fontSize: 14, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}
