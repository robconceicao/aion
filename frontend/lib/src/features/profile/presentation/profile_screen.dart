import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/cinematic_background.dart';
import '../../dream/presentation/widgets/aion_logo.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController(text: 'Explorador do Inconsciente');
  final _emailController = TextEditingController(text: 'aluno@mitopsique.com.br');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AionTheme.darkVoid,
      body: CinematicBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: AionTheme.gold, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  'PERFIL',
                  style: GoogleFonts.ptSerif(
                    fontSize: 12,
                    letterSpacing: 4,
                    color: AionTheme.gold,
                  ),
                ),
                centerTitle: true,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      const AionSpinLogo(size: 100),
                      const SizedBox(height: 40),
                      
                      _buildProfileField(
                        label: 'NOME DA ESSÊNCIA',
                        controller: _nameController,
                        theme: theme,
                      ),
                      const SizedBox(height: 24),
                      _buildProfileField(
                        label: 'E-MAIL',
                        controller: _emailController,
                        theme: theme,
                        enabled: false,
                      ),
                      
                      const SizedBox(height: 60),
                      
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Alterações salvas no seu diário.'),
                                backgroundColor: AionTheme.gold,
                              ),
                            );
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AionTheme.gold,
                            foregroundColor: AionTheme.darkVoid,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: const RoundedRectangleBorder(),
                          ),
                          child: const Text(
                            'SALVAR ALTERAÇÕES',
                            style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
                        },
                        child: Text(
                          'desconectar essência',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AionTheme.silver.withOpacity(0.5),
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileField({
    required String label,
    required TextEditingController controller,
    required ThemeData theme,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.ptSerif(
            fontSize: 10,
            letterSpacing: 2,
            color: AionTheme.gold.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: AionTheme.darkAbyss.withOpacity(0.3),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AionTheme.veil),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AionTheme.gold),
            ),
            disabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AionTheme.veil, style: BorderStyle.none),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
          ),
        ),
      ],
    );
  }
}
