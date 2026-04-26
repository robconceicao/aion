import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../dream/presentation/dream_diary_screen.dart';
import '../../dream/presentation/widgets/aion_logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  int _currentStep = 1;
  final int _totalSteps = 3;
  final TextEditingController _nameController = TextEditingController();
  late AnimationController _pulseController;
  bool _isNameValid = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    
    _nameController.addListener(() {
      setState(() {
        _isNameValid = _nameController.text.trim().length >= 2;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

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

    return Scaffold(
      backgroundColor: AionTheme.darkVoid,
      body: SafeArea(
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
                              // Aion Logo with Pulse
                              const AionPulseLogo(size: 180),
                        const SizedBox(height: 20),
                        Text(
                          'MITO & PSIQUE',
                          style: theme.textTheme.displayLarge?.copyWith(fontSize: 10, letterSpacing: 8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'BEM-VINDO(A)',
                          style: theme.textTheme.displayLarge?.copyWith(fontSize: 32),
                        ),
                        const SizedBox(height: 48),
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
                          style: GoogleFonts.ptSerif(fontSize: 10, letterSpacing: 4, color: AionTheme.silver),
                        ),
                        const Spacer(),
                        const SizedBox(height: 32),
                        // Dynamic Content
                        if (_currentStep == 1) _buildStepOne(theme),
                        if (_currentStep == 2) _buildStepTwo(theme),
                        if (_currentStep == 3) _buildStepThree(theme),
                        const SizedBox(height: 32),
                        const Spacer(),
                        // Footer
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
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                                    ),
                                    child: const Text('← VOLTAR', style: TextStyle(fontFamily: 'Georgia', letterSpacing: 2, fontSize: 11)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                flex: 4,
                                child: ElevatedButton(
                                  onPressed: (_currentStep == 1 && _nameController.text.trim().isEmpty) || (_currentStep == 2 && _selectedIntention.isEmpty) ? null : _nextStep,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AionTheme.gold,
                                    foregroundColor: AionTheme.darkVoid,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
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
                        if (_currentStep == 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: TextButton(
                              onPressed: _nextStep,
                              child: Text(
                                'pular esta etapa',
                                style: GoogleFonts.ptSerif(fontSize: 11, letterSpacing: 2, color: AionTheme.mist),
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
              ),
              ),
            );
          },
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
            hintText: 'Seu nome ou como prefere ser chamado...',
            hintStyle: theme.textTheme.bodyMedium?.copyWith(color: AionTheme.mist),
            contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
            fillColor: AionTheme.deep,
            filled: true,
            border: OutlineInputBorder(
              borderSide: BorderSide(color: _nameController.text.isNotEmpty ? AionTheme.gold.withOpacity(0.6) : AionTheme.veil),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _nameController.text.isNotEmpty ? AionTheme.gold.withOpacity(0.6) : AionTheme.veil),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AionTheme.gold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Usado para personalizar sua experiência. Nunca compartilhado.',
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11, color: AionTheme.mist),
        ),
      ],
    );
  }

  String _selectedIntention = '';
  final List<String> _intentions = [
    "Autoconhecimento",
    "Compreender padrões repetitivos",
    "Lidar com sonhos perturbadores",
    "Conexão com o simbólico",
    "Acompanhar meu processo terapêutico",
    "Curiosidade e exploração"
  ];

  Widget _buildStepTwo(ThemeData theme) {
    return Column(
      children: [
        Text(
          'O que te traz ao Diário de Sonhos?',
          style: theme.textTheme.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Column(
          children: _intentions.map((int) {
            final isSelected = _selectedIntention == int;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedIntention = int;
                _isNameValid = true; // Temporary reuse of state variable for continuing
              }),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  color: isSelected ? AionTheme.gold.withOpacity(0.12) : AionTheme.deep,
                  border: Border.all(color: isSelected ? AionTheme.gold : AionTheme.veil),
                ),
                child: Text(
                  int,
                  style: TextStyle(
                    color: isSelected ? AionTheme.amber : AionTheme.silver,
                    fontSize: 14,
                    fontFamily: 'Georgia',
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _selectedPhase = '';
  final List<String> _lifePhases = [
    "Transição de carreira", "Fim de relacionamento",
    "Início de relacionamento", "Luto",
    "Crise de identidade", "Crescimento pessoal",
    "Maternidade / Paternidade", "Busca espiritual",
    "Isolamento", "Fase criativa",
    "Doença ou recuperação", "Outro"
  ];

  Widget _buildStepThree(ThemeData theme) {
    return Column(
      children: [
        Text(
          'Em que fase da vida você está?',
          style: theme.textTheme.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Column(
          children: _lifePhases.map((ph) {
            final isSelected = _selectedPhase == ph;
            return GestureDetector(
              onTap: () => setState(() => _selectedPhase = ph),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  color: isSelected ? AionTheme.gold.withOpacity(0.12) : AionTheme.deep,
                  border: Border.all(color: isSelected ? AionTheme.gold : AionTheme.veil),
                ),
                child: Text(
                  ph,
                  style: TextStyle(
                    color: isSelected ? AionTheme.amber : AionTheme.silver,
                    fontSize: 14,
                    fontFamily: 'Georgia',
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
