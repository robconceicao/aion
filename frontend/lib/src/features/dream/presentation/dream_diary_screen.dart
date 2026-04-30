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
  int _favorites = 0;
  int _thisMonth = 0;
  String _topArchetype = '-';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Busca os sonhos do usuário
      final data = await Supabase.instance.client
          .from('dreams')
          .select('created_at, is_favorite, main_archetype');

      int favs = 0;
      int month = 0;
      final now = DateTime.now();
      Map<String, int> archetypesCount = {};

      for (var dream in data) {
        if (dream['is_favorite'] == true) favs++;
        
        if (dream['created_at'] != null) {
          final createdAt = DateTime.parse(dream['created_at']);
          if (createdAt.year == now.year && createdAt.month == now.month) {
            month++;
          }
        }

        final arch = dream['main_archetype'];
        if (arch != null && arch.toString().trim().isNotEmpty) {
          archetypesCount[arch] = (archetypesCount[arch] ?? 0) + 1;
        }
      }

      String topArch = '-';
      if (archetypesCount.isNotEmpty) {
        var entry = archetypesCount.entries.reduce((a, b) => a.value > b.value ? a : b);
        topArch = entry.key; // O arquétipo com maior contagem
      }

      if (mounted) {
        setState(() {
          _totalDreams = data.length;
          _favorites = favs;
          _thisMonth = month;
          _topArchetype = topArch;
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
    
    return Scaffold(
      backgroundColor: AionTheme.darkVoid,
      body: CinematicBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    const Center(
                      child: AionPulseLogo(size: 180.0),
                    ),
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
                      ? const SizedBox(height: 50, child: Center(child: CircularProgressIndicator(color: AionTheme.gold)))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStatItem('$_totalDreams', 'SONHOS'),
                            const SizedBox(width: 24),
                            _buildStatItem('$_favorites', 'FAVORITOS'),
                            const SizedBox(width: 24),
                            _buildStatItem('$_thisMonth', 'ESTE MÊS'),
                            const SizedBox(width: 24),
                            _buildStatItem(_topArchetype, 'ARQUÉTIPO'),
                          ],
                        ),
                    const SizedBox(height: 32),
  
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Wrap(
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
                    ),
  
                    const SizedBox(height: 32),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        );
                      },
                      child: Text(
                        'editar perfil',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AionTheme.silver,
                          fontSize: 11,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
  
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: Text(
                        '⚠ Reflexão simbólica baseada em Jung & Campbell. Não é terapia, não é diagnóstico. Para suporte clínico, procure um psicólogo.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 10, 
                          color: AionTheme.silver,
                          height: 1.8
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

  Widget _buildBtn(BuildContext context, String text, {required bool isPrimary}) {
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
          // Recarrega as estatísticas caso o usuário volte de um registro de novo sonho
          _loadStats();
        } else if (text == 'HISTÓRICO') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DreamHistoryScreen(userEmail: 'usuario@aion.app')),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
