import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../dream/presentation/widgets/aion_logo.dart';
import '../../../core/widgets/cinematic_background.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: AionTheme.darkVoid,
      body: CinematicBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                    Text(
                      'Bem-Vindo(a)',
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        color: AionTheme.dawn,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    // Login/Register Toggle
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AionTheme.veil, width: 1)),
                      ),
                      child: Row(
                        children: [
                          _buildTab(context, 'ENTRAR', _isLogin, () => setState(() => _isLogin = true)),
                          _buildTab(context, 'CRIAR ESSÊNCIA', !_isLogin, () => setState(() => _isLogin = false)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    _buildInput(
                      controller: _emailController,
                      hint: 'E-MAIL',
                    ),
                    const SizedBox(height: 16),
                    _buildInput(
                      controller: _passwordController,
                      hint: 'SENHA',
                      isPassword: true,
                    ),
                    
                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: Text(
                            'Esqueci a senha',
                            style: theme.textTheme.bodySmall?.copyWith(color: AionTheme.silver),
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/onboarding');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AionTheme.gold,
                          foregroundColor: AionTheme.darkVoid,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: Text(_isLogin ? 'ENTRAR' : 'COMEÇAR'),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    const Row(
                      children: [
                        Expanded(child: Divider(color: AionTheme.veil)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('OU', style: TextStyle(color: AionTheme.silver, fontSize: 10, letterSpacing: 2)),
                        ),
                        Expanded(child: Divider(color: AionTheme.veil)),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: Text(
                          _isLogin ? 'ENTRAR COM GOOGLE' : 'REGISTRAR COM GOOGLE',
                          style: const TextStyle(fontSize: 11, letterSpacing: 1),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AionTheme.silver,
                          side: const BorderSide(color: AionTheme.veil),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(BuildContext context, String text, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? AionTheme.gold : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? AionTheme.gold : AionTheme.silver,
              fontSize: 11,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AionTheme.darkAbyss.withOpacity(0.3),
        border: Border.all(color: AionTheme.veil),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AionTheme.silver.withOpacity(0.5), fontSize: 11, letterSpacing: 2),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
