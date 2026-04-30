import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/cinematic_background.dart';
import '../../dream/presentation/widgets/aion_logo.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../dream/presentation/notification_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController(text: 'Explorador do Inconsciente');
  final _emailController = TextEditingController(text: 'aluno@mitopsique.com.br');
  TimeOfDay? _wakeUpTime;

  @override
  void initState() {
    super.initState();
    _loadWakeUpTime();
  }

  Future<void> _loadWakeUpTime() async {
    final time = await AionNotificationService.getSavedWakeUpTime();
    if (mounted) setState(() => _wakeUpTime = time);
  }

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
                        label: 'NOME DO SONHADOR',
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
                      
                      const SizedBox(height: 40),

                      // — Seção de Notificações
                      Container(
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AionTheme.darkAbyss,
                          border: Border.all(color: AionTheme.shadow),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('NOTIFICAÇÃO MATINAL',
                                style: GoogleFonts.ptSerif(
                                  fontSize: 9, letterSpacing: 3, color: AionTheme.gold,
                                )),
                            const SizedBox(height: 8),
                            Text(
                              'Defina seu horário de despertar para receber um lembrete de registrar o sonho.',
                              style: GoogleFonts.ptSerif(
                                fontSize: 12, color: AionTheme.silver.withOpacity(0.6), height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: _wakeUpTime ?? const TimeOfDay(hour: 7, minute: 0),
                                  builder: (context, child) => Theme(
                                    data: ThemeData.dark().copyWith(
                                      colorScheme: ColorScheme.dark(
                                        primary: AionTheme.gold,
                                        surface: AionTheme.darkAbyss,
                                      ),
                                    ),
                                    child: child!,
                                  ),
                                );
                                if (picked != null) {
                                  setState(() => _wakeUpTime = picked);
                                  await AionNotificationService.requestAndSchedule(picked);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Notificação agendada para ${picked.format(context)}',
                                          style: GoogleFonts.ptSerif(color: AionTheme.darkVoid),
                                        ),
                                        backgroundColor: AionTheme.gold,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AionTheme.gold.withOpacity(0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.alarm, size: 16, color: AionTheme.gold),
                                    const SizedBox(width: 10),
                                    Text(
                                      _wakeUpTime != null
                                          ? _wakeUpTime!.format(context)
                                          : 'Definir horário',
                                      style: GoogleFonts.ptSerif(
                                        fontSize: 13, color: AionTheme.gold, letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
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
                          'sair da conta',
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
