import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../dream/presentation/dream_diary_screen.dart';
import '../../dream/presentation/widgets/aion_logo.dart';
import '../../../core/widgets/cinematic_background.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 1;
  final int _totalSteps = 2;
  final _nameController = TextEditingController();
  
  // Simulação do dado que virá do Supabase (masculino ou feminino)
  final String _userGender = 'masculino';

  void _nextStep() {
    if (_currentStep < _totalSteps) {
      setState(() => _currentStep++);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DreamDiaryScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String nome = _nameController.text.trim();
    final String bemVindoStr = _userGender == 'feminino' ? 'Bem-Vinda' : 'Bem-Vindo';

    return Scaffold(
      backgroundColor: AionTheme.darkVoid,
      body: CinematicBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Column(
                              children: [
                                const SizedBox(height: 60),
                                const AionPulseLogo(size: 180),
                                const SizedBox(height: 16),
                                
                                // HEADER PADRÃO
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
                                const SizedBox(height: 24),
                                
                                // BEM-VINDO DINÂMICO
                                if (_currentStep == 2)
                                  Text(
                                    '$bemVindoStr, $nome',
                                    style: GoogleFonts.cormorantGaramond(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w600,
                                      color: AionTheme.dawn,
                                      letterSpacing: 3,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  
                                const SizedBox(height: 32),
                                
                                // Progress Bar
                                Row(
                                  children: List.generate(_totalSteps, (index) {
                                    final isActive = index < _currentStep;
                                    return Expanded(
                                      child: Container(
                                        height: 4,
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                        decoration: BoxDecoration(
                                          color: isActive ? AionTheme.gold : AionTheme.darkAbyss,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  '$_currentStep DE $_totalSteps',
                                  style: GoogleFonts.ptSerif(fontSize: 10, letterSpacing: 4, color: AionTheme.ghost),
                                ),
                                const Spacer(),
                                const SizedBox(height: 32),
                                
                                if (_currentStep == 1) _buildStepOne(theme),
                                if (_currentStep == 2) _buildStepTwo(theme),
                                
                                const SizedBox(height: 32),
                                const Spacer(),
                                SizedBox(
                                  width: double.infinity,
                                  child: Row(
                                    children: [
                                      if (_currentStep > 1) ...[
                                        Expanded(
                                          flex: 2,
                                          child: OutlinedButton(
                                            onPressed: () => setState(() => _currentStep--),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: AionTheme.veil),
                                              foregroundColor: AionTheme.silver,
                                              padding: const EdgeInsets.symmetric(vertical: 16),
                                              shape: const RoundedRectangleBorder(),
                                            ),
                                            child: const Text('← VOLTAR', style: TextStyle(fontFamily: 'Georgia', letterSpacing: 2, fontSize: 11)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Expanded(
                                        flex: 4,
                                        child: ElevatedButton(
                                          onPressed: (_currentStep == 1 && _nameController.text.trim().isEmpty) ? null : _nextStep,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AionTheme.gold,
                                            foregroundColor: AionTheme.darkVoid,
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: const RoundedRectangleBorder(),
                                          ),
                                          child: Text(
                                            _currentStep == _totalSteps ? 'INICIAR JORNADA ☽' : 'CONTINUAR →',
                                            style: const TextStyle(fontFamily: 'Georgia', letterSpacing: 2, fontSize: 11),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStepOne(ThemeData theme) {
    return Column(
      children: [
        Text(
          'Como posso te chamar?',
          style: theme.textTheme.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _nameController,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'SEU NOME OU ESSÊNCIA',
            hintStyle: TextStyle(color: AionTheme.silver.withOpacity(0.3), fontSize: 12, letterSpacing: 2),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AionTheme.veil)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AionTheme.gold)),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildStepTwo(ThemeData theme) {
    final isFem = _userGender == 'feminino';
    final titulo = isFem ? 'Pronta para começar?' : 'Pronto para começar?';

    return Column(
      children: [
        Text(
          titulo,
          style: theme.textTheme.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Sua jornada pelo inconsciente está prestes a começar. Prepare-se para encontrar seus arquétipos.',
          style: theme.textTheme.bodyMedium?.copyWith(color: AionTheme.silver, height: 1.6),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
