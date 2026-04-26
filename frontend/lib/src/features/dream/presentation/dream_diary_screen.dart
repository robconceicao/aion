import 'package:flutter/material.dart';
import '../../../../src/core/theme.dart';
import 'record_dream_screen.dart';
import 'widgets/aion_logo.dart';

class DreamDiaryScreen extends StatelessWidget {
  const DreamDiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: AionTheme.darkVoid,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 60),
              const Center(
                child: AionPulseLogo(size: 160),
              ),
              const SizedBox(height: 24),
              Text(
                'AION',
                style: theme.textTheme.displayLarge?.copyWith(fontSize: 32, letterSpacing: 12, fontWeight: FontWeight.w300),
              ),
              const SizedBox(height: 8),
              Text(
                'MITO & PSIQUE',
                style: theme.textTheme.displayLarge?.copyWith(fontSize: 12, letterSpacing: 8, color: AionTheme.gold),
              ),
              const SizedBox(height: 60),
              
              // Grid of Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    // Main Record Button
                    GestureDetector(
                      onTap: () async {
                        final transcription = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(builder: (context) => const RecordDreamScreen()),
                        );
                        if (transcription != null && transcription.isNotEmpty) {
                          debugPrint('Relato recebido: $transcription');
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
                        decoration: BoxDecoration(
                          color: AionTheme.darkAbyss,
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          children: [
                            const Text('✧', style: TextStyle(fontSize: 32, color: AionTheme.gold)),
                            const SizedBox(height: 12),
                            Text(
                              'REGISTRAR SONHO',
                              style: theme.textTheme.displayMedium?.copyWith(fontSize: 14, color: Colors.white),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Áudio ou Texto',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12, color: Colors.white38),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildNavCard(theme, '⟁', 'ARQUÉTIPOS', null),
                        const SizedBox(width: 16),
                        _buildNavCard(theme, '◯', 'A JORNADA', null),
                      ],
                    ),
                  ],
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
              style: theme.textTheme.displayMedium?.copyWith(fontSize: 12, color: Colors.white),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10, color: Colors.white38),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
