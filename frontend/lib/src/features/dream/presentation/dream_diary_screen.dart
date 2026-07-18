import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../src/core/theme.dart';
import 'record_dream_screen.dart';
import 'archetypes_screen.dart';
import 'canal_screen.dart';
import 'dream_history_screen.dart';
import 'widgets/aion_logo.dart';
import '../../../core/widgets/cinematic_background.dart';
import '../../profile/presentation/profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DreamDiaryScreen extends StatefulWidget {
  const DreamDiaryScreen({super.key});

  @override
  State<DreamDiaryScreen> createState() => _DreamDiaryScreenState();
}

class _DreamDiaryScreenState extends State<DreamDiaryScreen> {
  int _totalDreams = 0;
  int _thisMonth = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final String userEmail =
          Supabase.instance.client.auth.currentUser?.email ?? '';
      final data = await Supabase.instance.client
          .from('dreams')
          .select('created_at')
          .eq('user_email', userEmail);

      int month = 0;
      final now = DateTime.now();

      for (var dream in data) {
        if (dream['created_at'] != null) {
          final createdAt = DateTime.parse(dream['created_at']);
          if (createdAt.year == now.year && createdAt.month == now.month) {
            month++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalDreams = data.length;
          _thisMonth = month;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar as estatísticas do banco: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final padH = (size.width * 0.04).clamp(12.0, 24.0);
    final logoSize = (size.width * 0.42).clamp(120.0, 180.0);

    return Scaffold(
      backgroundColor: AionTheme.darkVoid,
      body: CinematicBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: padH, vertical: 16),
                child: Column(
                  children: [
                    SizedBox(height: size.height * 0.04),
                    Center(child: AionPulseLogo(size: logoSize)),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 32),
                    _isLoading
                        ? const SizedBox(
                            height: 50,
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: AionTheme.gold),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildStatItem('$_totalDreams', 'SONHOS'),
                              const SizedBox(width: 24),
                              _buildStatItem('$_thisMonth', 'ESTE MÊS'),
                            ],
                          ),
                    const SizedBox(height: 32),
                    // Busca e filtros ficam exclusivamente no Histórico
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildBtn(context, 'REGISTRAR SONHO', isPrimary: true),
                        _buildBtn(context, 'HISTÓRICO', isPrimary: false),
                        _buildBtn(context, 'ARQUÉTIPOS', isPrimary: false),
                        _buildBtn(context, 'CANAL', isPrimary: false),
                      ],
                    ),
                    const SizedBox(height: 32),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProfileScreen()),
                        );
                      },
                      child: Text(
                        'ajustes e despertar',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AionTheme.silver,
                          fontSize: 11,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: (size.width * 0.06).clamp(16.0, 40.0)),
                      child: Text(
                        '⚠ Reflexão simbólica baseada em Jung & Campbell. Não é terapia, não é diagnóstico. Para suporte clínico, procure um psicólogo.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 10,
                          color: AionTheme.silver,
                          height: 1.8,
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
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            color: AionTheme.amber,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: AionTheme.silver,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildBtn(BuildContext context, String text,
      {required bool isPrimary}) {
    return ElevatedButton(
      onPressed: () async {
        if (text == 'REGISTRAR SONHO') {
          final transcription = await Navigator.push<String>(
            context,
            MaterialPageRoute(builder: (context) => const RecordDreamScreen()),
          );
          if (transcription != null && transcription.isNotEmpty) {
            debugPrint('Relato recebido: $transcription');
          }
          _loadStats();
        } else if (text == 'HISTÓRICO') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DreamHistoryScreen(
                userEmail:
                    Supabase.instance.client.auth.currentUser?.email ?? '',
              ),
            ),
          );
        } else if (text == 'ARQUÉTIPOS') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ArchetypesScreen()),
          );
        } else if (text == 'CANAL') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CanalScreen()),
          );
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? AionTheme.gold : Colors.transparent,
        foregroundColor: isPrimary ? AionTheme.darkVoid : AionTheme.silver,
        side: BorderSide(
          color: isPrimary ? AionTheme.gold : AionTheme.veil,
        ),
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: const RoundedRectangleBorder(),
        elevation: 0,
        textStyle: const TextStyle(
          fontFamily: 'Georgia',
          fontSize: 12,
        ),
      ),
      child: Text(text),
    );
  }
}
