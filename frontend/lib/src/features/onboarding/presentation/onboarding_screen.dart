import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../dream/presentation/dream_diary_screen.dart';

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Moon Icon with Pulse
              FadeTransition(
                opacity: Tween(begin: 0.4, end: 1.0).animate(_pulseController),
                child: const Text('☽', 
                  style: TextStyle(fontSize: 80, color: Colors.white, fontWeight: FontWeight.w100)
                ),
              ),
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
              const Expanded(child: SizedBox()),
              // Dynamic Content
              if (_currentStep == 1) _buildStepOne(theme),
              if (_currentStep == 2) _buildStepTwo(theme),
              if (_currentStep == 3) _buildStepThree(theme),
              const Expanded(child: SizedBox()),
              // Footer
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_currentStep == 1 && !_isNameValid) ? null : _nextStep,
                  child: Text(_currentStep == _totalSteps ? 'COMEÇAR' : 'CONTINUAR →'),
                ),
              ),
              const SizedBox(height: 40),
            ],
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
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Seu nome ou como prefere ser chamado...',
            hintStyle: theme.textTheme.bodyMedium?.copyWith(color: AionTheme.mist),
            contentPadding: const EdgeInsets.symmetric(vertical: 24),
            border: const OutlineInputBorder(
              borderSide: BorderSide(color: AionTheme.darkAbyss),
            ),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AionTheme.darkAbyss),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AionTheme.gold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Usado para personalizar sua experiência. Nunca compartilhado.',
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildStepTwo(ThemeData theme) {
    return Column(
      children: [
        Text(
          'Simbologia Pura',
          style: theme.textTheme.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Text(
          'Aion não julga. Ele amplifica seus sonhos através de arquétipos universais e mitos ancestrais.',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStepThree(ThemeData theme) {
    return Column(
      children: [
        Text(
          'Pronto para a Jornada?',
          style: theme.textTheme.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Text(
          'A revelação está em suas mãos. Registre seus sonhos por voz ou texto e descubra os padrões da sua psique.',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
