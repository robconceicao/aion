import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _submit() {
    // Para o beta local, fazemos um bypass ou usamos o Supabase
    // Por enquanto, navegamos para o Onboarding
    Navigator.of(context).pushReplacementNamed('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AionTheme.darkVoid,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              AionTheme.darkAbyss,
              AionTheme.darkVoid,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Simbolo do Portal
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AionTheme.gold.withOpacity(0.5)),
                  ),
                  child: Icon(Icons.blur_on, color: AionTheme.gold, size: 40),
                ),
                const SizedBox(height: 40),
                Text(
                  _isLogin ? 'ENTRAR NO PORTAL' : 'CRIAR ESSÊNCIA',
                  style: AionTheme.serifStyle(
                    fontSize: 24,
                    color: AionTheme.gold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isLogin ? 'Seu inconsciente te aguarda.' : 'Inicie sua jornada psicológica.',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                ),
                const SizedBox(height: 50),
                
                // Form Fields
                _buildField(
                  controller: _emailController,
                  label: 'E-MAIL',
                  icon: Icons.alternate_email,
                ),
                const SizedBox(height: 20),
                _buildField(
                  controller: _passwordController,
                  label: 'CHAVE',
                  icon: Icons.vpn_key_outlined,
                  isPassword: true,
                ),
                const SizedBox(height: 40),
                
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: Text(_isLogin ? 'ENTRAR' : 'CRIAR'),
                  ),
                ),
                
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin ? 'AINDA NÃO TENHO ESSÊNCIA' : 'JÁ POSSUO PORTAL',
                    style: AionTheme.serifStyle(color: AionTheme.gold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: AionTheme.gold.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: GoogleFonts.inter(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: AionTheme.gold.withOpacity(0.5), fontSize: 10, letterSpacing: 2),
          prefixIcon: Icon(icon, color: AionTheme.gold.withOpacity(0.3), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }
}
