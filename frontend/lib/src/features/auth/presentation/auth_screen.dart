import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../dream/presentation/widgets/aion_logo.dart';
import '../../../core/widgets/cinematic_background.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String _selectedGender = 'Prefiro não informar';

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
                    const SizedBox(height: 48),
                    
                    // Login/Register Toggle
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AionTheme.veil, width: 1)),
                      ),
                      child: Row(
                        children: [
                          _buildTab(context, 'ENTRAR', _isLogin, () => setState(() => _isLogin = true)),
                          _buildTab(context, 'CADASTRAR', !_isLogin, () => setState(() => _isLogin = false)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (!_isLogin) ...[
                      _buildInput(
                        controller: _nameController,
                        hint: 'NOME COMPLETO',
                      ),
                      const SizedBox(height: 16),
                      _buildGenderDropdown(),
                      const SizedBox(height: 16),
                    ],

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
                        onPressed: _isLoading ? null : _handleEmailAuth,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AionTheme.gold,
                          foregroundColor: AionTheme.darkVoid,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: _isLoading 
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: AionTheme.darkVoid, strokeWidth: 2))
                            : Text(_isLogin ? 'ENTRAR' : 'CADASTRAR'),
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
                        onPressed: _handleGoogleSignIn,
                        icon: Text(
                          'G',
                          style: GoogleFonts.roboto(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        label: Text(
                          _isLogin ? 'ENTRAR COM GOOGLE' : 'CADASTRAR COM GOOGLE',
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

  Widget _buildGenderDropdown() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AionTheme.darkAbyss.withOpacity(0.3),
        border: Border.all(color: AionTheme.veil),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedGender,
          dropdownColor: AionTheme.darkAbyss,
          icon: const Icon(Icons.keyboard_arrow_down, color: AionTheme.silver),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'Prefiro não informar', child: Text('GÊNERO: PREFIRO NÃO INFORMAR')),
            DropdownMenuItem(value: 'Feminino', child: Text('GÊNERO: FEMININO')),
            DropdownMenuItem(value: 'Masculino', child: Text('GÊNERO: MASCULINO')),
            DropdownMenuItem(value: 'Não-binário', child: Text('GÊNERO: NÃO-BINÁRIO')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedGender = val);
          },
        ),
      ),
    );
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha E-mail e Senha.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // Fluxo de Login
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (mounted) Navigator.pushReplacementNamed(context, '/home'); // Vai direto para o diário
      } else {
        // Fluxo de Cadastro
        if (name.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Por favor, preencha seu Nome Completo.')),
          );
          setState(() => _isLoading = false);
          return;
        }
        
        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {
            'nome': name,
            'sexo': _selectedGender,
          },
        );
        if (mounted) {
          // Após cadastro, envia para a tela de Onboarding para a saudação
          Navigator.pushReplacementNamed(context, '/onboarding');
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: ${e.message}'), backgroundColor: AionTheme.crimson),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro inesperado: $e'), backgroundColor: AionTheme.crimson),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
      );
      // O Supabase importará nome, email e foto do usuário Google automaticamente.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro de conexão com o Google: $e'),
            backgroundColor: AionTheme.crimson,
          ),
        );
      }
    }
  }
}
