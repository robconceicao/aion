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
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _submit() {
    Navigator.of(context).pushReplacementNamed('/onboarding');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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
                  // LOGO
                  const SizedBox(height: 24),
                  const AionPulseLogo(size: 180),
                  const SizedBox(height: 24),

                  // TITLES
                  Text(
                    'MITO & PSIQUE',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 10,
                      letterSpacing: 4,
                      color: AionTheme.silver,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AION',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 32,
                      letterSpacing: 8,
                      color: AionTheme.gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'O Diário do Sonho',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AionTheme.silver,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // TABS
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isLogin = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _isLogin ? AionTheme.gold : AionTheme.veil,
                                  width: _isLogin ? 2 : 1,
                                ),
                              ),
                            ),
                            child: Text(
                              'ENTRAR',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _isLogin ? AionTheme.gold : AionTheme.silver,
                                fontSize: 12,
                                letterSpacing: 3,
                                fontFamily: 'Georgia',
                                fontWeight: _isLogin ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isLogin = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: !_isLogin ? AionTheme.gold : AionTheme.veil,
                                  width: !_isLogin ? 2 : 1,
                                ),
                              ),
                            ),
                            child: Text(
                              'CRIAR CONTA',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: !_isLogin ? AionTheme.gold : AionTheme.silver,
                                fontSize: 12,
                                letterSpacing: 3,
                                fontFamily: 'Georgia',
                                fontWeight: !_isLogin ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                    const SizedBox(height: 32),

                    // FORM
                    if (!_isLogin) ...[
                      _buildInput(controller: _nameController, hint: 'NOME'),
                      const SizedBox(height: 16),
                    ],
                    _buildInput(controller: _emailController, hint: 'E-MAIL'),
                    const SizedBox(height: 16),
                    _buildInput(controller: _passwordController, hint: 'SENHA', isPassword: true),
                    
                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 32),
                          child: Text(
                            'Esqueci a senha',
                            style: TextStyle(
                              fontSize: 11,
                              color: AionTheme.silver,
                              letterSpacing: 1,
                              fontFamily: 'Georgia',
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 32),

                    // SUBMIT BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AionTheme.gold,
                          foregroundColor: AionTheme.darkVoid,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                          elevation: 4,
                        ),
                        child: Text(
                          _isLogin ? 'ENTRAR' : 'INICIAR JORNADA',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 4,
                            fontFamily: 'Georgia',
                          ),
                        ),
                      ),
                    ),

                    // SOCIAL LOGIN
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        Expanded(child: Container(height: 1, color: AionTheme.veil)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OU',
                            style: TextStyle(
                              fontSize: 10,
                              color: AionTheme.silver,
                              letterSpacing: 2,
                              fontFamily: 'Georgia',
                            ),
                          ),
                        ),
                        Expanded(child: Container(height: 1, color: AionTheme.veil)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.g_mobiledata, color: Colors.white, size: 24),
                        label: const Text(
                          'CONTINUAR COM GOOGLE',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 2,
                            fontFamily: 'Georgia',
                            color: AionTheme.silver,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AionTheme.silver,
                          side: const BorderSide(color: AionTheme.veil),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                        ),
                      ),
                    ),
                ],
              ),
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
        color: AionTheme.darkAbyss,
        border: Border.all(color: AionTheme.veil),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: 'Georgia',
          letterSpacing: 1,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: AionTheme.silver,
            fontSize: 14,
            fontFamily: 'Georgia',
            letterSpacing: 1,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
