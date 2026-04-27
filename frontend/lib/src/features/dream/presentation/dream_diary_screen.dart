import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../src/core/theme.dart';
import 'record_dream_screen.dart';
import 'archetypes_screen.dart';
import 'canal_screen.dart';
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
            constraints: const BoxConstraints(maxWidth: 820),
            child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Center(
                child: AionPulseLogo(size: 180.0),
              ),
              const SizedBox(height: 16),
              Text(
                'MITO & PSIQUE',
                style: GoogleFonts.ptSerif(
                  fontSize: 10,
                  letterSpacing: 6,
                  color: AionTheme.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AION',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 32,
                  letterSpacing: 8,
                  color: AionTheme.amber,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'O Diário do Sonho',
                style: GoogleFonts.ptSerif(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: AionTheme.ghost,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 32),
              
              // Stats Row Mock
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatItem('12', 'SONHOS'),
                  const SizedBox(width: 24),
                  _buildStatItem('3', 'FAVORITOS'),
                  const SizedBox(width: 24),
                  _buildStatItem('2', 'ESTE MÊS'),
                  const SizedBox(width: 24),
                  _buildStatItem('Sábio', 'ARQUÉTIPO'),
                ],
              ),
              const SizedBox(height: 32),

              // Action Buttons Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildBtn(context, 'REGISTRAR SONHO', isPrimary: true),
                    _buildBtn(context, 'ARQUÉTIPOS', isPrimary: false),
                    _buildBtn(context, 'CANAL', isPrimary: false),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              TextButton(
                onPressed: () {},
                child: Text(
                  'editar perfil',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AionTheme.silver,
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
              ),

              const SizedBox(height: 32),
              // Footer disclaimer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Text(
                  '⚠ Reflexão simbólica baseada em Jung & Campbell. Não é terapia, não é diagnóstico. Para suporte clínico, procure um psicólogo.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 10, 
                    color: AionTheme.silver,
                    height: 1.8
                  ),
                ),
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

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            color: AionTheme.amber,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: AionTheme.silver,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildBtn(BuildContext context, String text, {required bool isPrimary}) {
    return ElevatedButton(
      onPressed: () async {
        if (text == 'REGISTRAR SONHO') {
          final transcription = await Navigator.push<String>(
            context,
            MaterialPageRoute(builder: (context) => const RecordDreamScreen()),
          );
          if (transcription != null && transcription.isNotEmpty) {
            debugPrint('Relato recebido: $transcription');
          }
        } else if (text == 'ARQUÉTIPOS') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ArchetypesScreen()),
          );
        } else if (text == 'CANAL') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CanalScreen()),
          );
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? AionTheme.gold : Colors.transparent,
        foregroundColor: isPrimary ? AionTheme.darkVoid : AionTheme.silver,
        side: BorderSide(
          color: isPrimary ? AionTheme.gold : AionTheme.veil,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), // Using padding comparable to JSX
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4), // very slight curve or zero
        ),
        elevation: 0,
        textStyle: const TextStyle(
          fontFamily: 'Georgia', // using serif matching
          fontSize: 12,
        ),
      ),
      child: Text(text),
    );
  }
}
