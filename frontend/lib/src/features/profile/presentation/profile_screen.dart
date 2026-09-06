import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/cinematic_background.dart';
import '../../../core/api_service.dart';
import '../../../core/constants.dart';
import '../../dream/presentation/widgets/aion_logo.dart';
import '../../dream/presentation/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController(text: 'Explorador do Inconsciente');
  final _emailController = TextEditingController();
  TimeOfDay? _wakeUpTime;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    _emailController.text = user?.email ?? '';
    final metaName = user?.userMetadata?['full_name'] as String?;
    if (metaName != null && metaName.trim().isNotEmpty) {
      _nameController.text = metaName.trim();
    }
    _loadWakeUpTime();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadWakeUpTime() async {
    final time = await AionNotificationService.getSavedWakeUpTime();
    if (mounted) setState(() => _wakeUpTime = time);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final pad = (size.width * 0.06).clamp(16.0, 28.0);

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
                  padding: EdgeInsets.all(pad),
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
                        readOnly: true,
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
                                fontSize: 12, color: AionTheme.silver.withValues(alpha: 0.6), height: 1.6,
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
                                  final ok = await AionNotificationService.requestAndSchedule(picked);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          ok
                                            ? 'Notificação agendada para ${picked.format(context)}'
                                            : 'Permissão negada ou alarme exato indisponível.\nHabilite em Configurações → Apps → Aion → Acesso especial.',
                                          style: GoogleFonts.ptSerif(
                                            color: ok ? AionTheme.darkVoid : AionTheme.ghost,
                                          ),
                                        ),
                                        backgroundColor: ok ? AionTheme.gold : AionTheme.crimson,
                                        duration: Duration(seconds: ok ? 3 : 6),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AionTheme.gold.withValues(alpha: 0.4)),
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
                        onPressed: () async {
                          await Supabase.instance.client.auth.signOut();
                          if (mounted) {
                            // '/' é a rota da AuthScreen (ver routes em main.dart) — '/auth' não existe.
                            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                          }
                        },
                        child: Text(
                          'sair da conta',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AionTheme.silver.withValues(alpha: 0.5),
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(height: 1, color: AionTheme.shadow),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: _isDeletingAccount ? null : _confirmDeleteAccount,
                        child: _isDeletingAccount
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AionTheme.crimson,
                                ),
                              )
                            : Text(
                                'excluir conta e todos os meus dados',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AionTheme.crimson.withValues(alpha: 0.75),
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

  Future<void> _confirmDeleteAccount() async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AionTheme.darkAbyss,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AionTheme.shadow),
          borderRadius: BorderRadius.circular(4),
        ),
        title: Text(
          'Excluir sua conta?',
          style: GoogleFonts.ptSerif(color: AionTheme.dawn, fontSize: 16),
        ),
        content: Text(
          'Isso apaga permanentemente todos os seus sonhos, respostas e a sua conta no Aion. '
          'Essa ação não pode ser desfeita.',
          style: GoogleFonts.ptSerif(color: AionTheme.silver, fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancelar', style: GoogleFonts.ptSerif(color: AionTheme.silver)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Continuar', style: GoogleFonts.ptSerif(color: AionTheme.crimson)),
          ),
        ],
      ),
    );
    if (firstConfirm != true || !mounted) return;

    // Segunda confirmação — ação destrutiva e irreversível.
    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AionTheme.darkAbyss,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AionTheme.crimson),
          borderRadius: BorderRadius.circular(4),
        ),
        title: Text(
          'Tem certeza?',
          style: GoogleFonts.ptSerif(color: AionTheme.crimson, fontSize: 16),
        ),
        content: Text(
          'Não há como recuperar seus sonhos depois disso.',
          style: GoogleFonts.ptSerif(color: AionTheme.silver, fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancelar', style: GoogleFonts.ptSerif(color: AionTheme.silver)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Excluir definitivamente', style: GoogleFonts.ptSerif(color: AionTheme.crimson)),
          ),
        ],
      ),
    );
    if (finalConfirm != true || !mounted) return;

    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    setState(() => _isDeletingAccount = true);
    try {
      await ApiService.client.delete(AionConfig.deleteAccountUrl);
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      // '/' é a rota da AuthScreen (ver routes em main.dart) — '/auth' não existe.
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      debugPrint('[PROFILE] Erro ao excluir conta: $e');
      if (!mounted) return;
      setState(() => _isDeletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível excluir sua conta agora. Tente novamente em instantes.',
            style: GoogleFonts.ptSerif(color: AionTheme.ghost),
          ),
          backgroundColor: AionTheme.crimson,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildProfileField({
    required String label,
    required TextEditingController controller,
    required ThemeData theme,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.ptSerif(
            fontSize: 10,
            letterSpacing: 2,
            color: AionTheme.gold.withValues(alpha: 0.7),
          ),
        ),
        if (readOnly) ...[
          const SizedBox(height: 4),
          Text(
            'Vinculado à sua conta — não editável aqui',
            style: GoogleFonts.ptSerif(
              fontSize: 10,
              color: AionTheme.silver.withValues(alpha: 0.45),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Opacity(
          opacity: readOnly ? 0.6 : 1.0,
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            enableInteractiveSelection: !readOnly,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AionTheme.darkAbyss.withValues(alpha: readOnly ? 0.45 : 0.3),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AionTheme.veil),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: readOnly ? AionTheme.veil : AionTheme.gold,
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            ),
          ),
        ),
      ],
    );
  }
}
