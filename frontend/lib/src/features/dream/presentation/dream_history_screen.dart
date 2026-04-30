import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';
import '../../../core/widgets/cinematic_background.dart';
import 'dream_choice_screen.dart';

class DreamHistoryScreen extends StatefulWidget {
  final String userEmail;

  const DreamHistoryScreen({super.key, required this.userEmail});

  @override
  State<DreamHistoryScreen> createState() => _DreamHistoryScreenState();
}

class _DreamHistoryScreenState extends State<DreamHistoryScreen> {
  List<Map<String, dynamic>> _dreams = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = Dio();
      final response = await dio.get(
        AionConfig.historyUrl,
        queryParameters: {'user_email': widget.userEmail},
      );
      setState(() {
        _dreams = List<Map<String, dynamic>>.from(response.data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Não foi possível carregar o diário.';
        _isLoading = false;
      });
    }
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final months = [
        '', 'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
        'jul', 'ago', 'set', 'out', 'nov', 'dez'
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AionTheme.darkVoid,
      appBar: AppBar(
        backgroundColor: AionTheme.darkVoid,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AionTheme.gold, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'DIÁRIO DO SONHO',
          style: GoogleFonts.ptSerif(
            fontSize: 10,
            letterSpacing: 4,
            color: AionTheme.gold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AionTheme.silver, size: 18),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: CinematicBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: AionTheme.gold,
                strokeWidth: 1,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'ABRINDO O DIÁRIO...',
              style: GoogleFonts.ptSerif(
                fontSize: 10,
                letterSpacing: 4,
                color: AionTheme.silver,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: GoogleFonts.ptSerif(fontSize: 14, color: AionTheme.silver),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _loadHistory,
              child: Text(
                'Tentar novamente',
                style: GoogleFonts.ptSerif(
                  fontSize: 12,
                  color: AionTheme.gold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_dreams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '☽',
              style: TextStyle(fontSize: 48, color: AionTheme.gold.withOpacity(0.3)),
            ),
            const SizedBox(height: 24),
            Text(
              'O DIÁRIO AINDA ESTÁ EM BRANCO',
              style: GoogleFonts.ptSerif(
                fontSize: 10,
                letterSpacing: 4,
                color: AionTheme.silver.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Registre seu primeiro sonho para começar.',
              style: GoogleFonts.ptSerif(
                fontSize: 13,
                color: AionTheme.silver.withOpacity(0.4),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_dreams.length} SONHO${_dreams.length != 1 ? 'S' : ''} REGISTRADO${_dreams.length != 1 ? 'S' : ''}',
                style: GoogleFonts.ptSerif(
                  fontSize: 9,
                  letterSpacing: 3,
                  color: AionTheme.silver.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: _dreams.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final dream = _dreams[index];
              return _DreamHistoryCard(
                dream: dream,
                date: _formatDate(dream['created_at']),
                onTap: () => _openDream(dream),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openDream(Map<String, dynamic> dream) {
    final analysis = dream['interpretacao'] as Map<String, dynamic>? ?? {};
    final narrative = dream['narrativa'] as String? ?? '';
    final relato = dream['relato'] as String? ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DreamChoiceScreen(
          dreamText: relato,
          detailedAnalysis: analysis,
          narrativeText: narrative,
        ),
      ),
    );
  }
}

class _DreamHistoryCard extends StatefulWidget {
  final Map<String, dynamic> dream;
  final String date;
  final VoidCallback onTap;

  const _DreamHistoryCard({
    required this.dream,
    required this.date,
    required this.onTap,
  });

  @override
  State<_DreamHistoryCard> createState() => _DreamHistoryCardState();
}

class _DreamHistoryCardState extends State<_DreamHistoryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final analysis = widget.dream['interpretacao'] as Map<String, dynamic>? ?? {};
    final essencia = analysis['essencia'] as String? ?? '';
    final arquetipos = (analysis['arquetipos'] as List? ?? [])
        .map((a) => (a['nome'] ?? '') as String)
        .where((n) => n.isNotEmpty)
        .take(3)
        .join(' · ');
    final relato = widget.dream['relato'] as String? ?? '';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _hovered ? AionTheme.darkAbyss : AionTheme.darkDeep,
            border: Border.all(
              color: _hovered
                  ? AionTheme.gold.withOpacity(0.35)
                  : AionTheme.shadow,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: data + arquétipos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.date,
                    style: GoogleFonts.ptSerif(
                      fontSize: 10,
                      color: AionTheme.gold.withOpacity(0.6),
                      letterSpacing: 1,
                    ),
                  ),
                  if (arquetipos.isNotEmpty)
                    Expanded(
                      child: Text(
                        arquetipos,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.ptSerif(
                          fontSize: 9,
                          color: AionTheme.silver.withOpacity(0.5),
                          letterSpacing: 1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Relato (preview)
              Text(
                '"${relato.length > 120 ? '${relato.substring(0, 120)}…' : relato}"',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: AionTheme.ghost.withOpacity(0.75),
                  height: 1.6,
                ),
              ),

              if (essencia.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  height: 1,
                  color: AionTheme.shadow,
                ),
                const SizedBox(height: 10),
                Text(
                  essencia,
                  style: GoogleFonts.ptSerif(
                    fontSize: 12,
                    color: AionTheme.silver.withOpacity(0.6),
                    height: 1.6,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'VER LEITURAS',
                    style: GoogleFonts.ptSerif(
                      fontSize: 9,
                      letterSpacing: 2,
                      color: _hovered ? AionTheme.gold : AionTheme.silver.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward,
                    size: 11,
                    color: _hovered ? AionTheme.gold : AionTheme.silver.withOpacity(0.4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
