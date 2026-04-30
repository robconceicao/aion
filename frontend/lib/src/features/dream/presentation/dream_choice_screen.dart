import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import 'analysis_result_screen.dart';
import 'narrative_result_screen.dart';
import 'record_dream_screen.dart';
import 'dream_history_screen.dart';
import '../../auth/presentation/auth_screen.dart';

class DreamChoiceScreen extends StatefulWidget {
  final String dreamText;
  final Map<String, dynamic> detailedAnalysis;
  final String narrativeText;

  const DreamChoiceScreen({
    super.key,
    required this.dreamText,
    required this.detailedAnalysis,
    required this.narrativeText,
  });

  @override
  State<DreamChoiceScreen> createState() => _DreamChoiceScreenState();
}

class _DreamChoiceScreenState extends State<DreamChoiceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AionTheme.darkVoid,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildNav(context),
                      const SizedBox(height: 30),
                      _buildDivider(),
                      const SizedBox(height: 40),
                      Text(
                        'O SONHO FOI RECEBIDO',
                        style: GoogleFonts.ptSerif(
                          fontSize: 10,
                          letterSpacing: 4,
                          color: AionTheme.gold,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Como você deseja\nolhar para ele?',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 34,
                          height: 1.25,
                          color: AionTheme.ghost,
                          fontWeight: FontWeight.w300,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: AionTheme.gold.withOpacity(0.35),
                              width: 2,
                            ),
                          ),
                          color: AionTheme.darkAbyss.withOpacity(0.6),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(6),
                            bottomRight: Radius.circular(6),
                          ),
                        ),
                        child: Text(
                          '"${widget.dreamText}"',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: AionTheme.silver,
                            height: 1.7,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 36),
                      _buildDivider(),
                      const SizedBox(height: 36),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _ChoiceCard(
                              icon: '☽',
                              label: 'LEITURA SIMBÓLICA',
                              title: 'Voz do\nArquétipo',
                              description:
                                  'Uma interpretação direta e acessível — Jung e Campbell em diálogo com o seu sonho.',
                              accentColor: AionTheme.gold,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NarrativeResultScreen(
                                    dreamText: widget.dreamText,
                                    narrativeText: widget.narrativeText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _ChoiceCard(
                              icon: '⊕',
                              label: 'ANÁLISE COMPLETA',
                              title: 'Mapa\nArquetípico',
                              description:
                                  'Arquétipos, símbolos, Jornada do Herói, Mito Espelho e dimensões psíquicas detalhadas.',
                              accentColor: AionTheme.teal,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AnalysisResultScreen(
                                    dreamText: widget.dreamText,
                                    analysis: widget.detailedAnalysis,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      Text(
                        'Você pode acessar a outra leitura a qualquer momento.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.ptSerif(
                          fontSize: 11,
                          color: AionTheme.silver.withOpacity(0.4),
                          letterSpacing: 0.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, AionTheme.gold.withOpacity(0.3)],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '✦',
            style: TextStyle(color: AionTheme.gold.withOpacity(0.5), fontSize: 10),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AionTheme.gold.withOpacity(0.3), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNav(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('M I T O  &  P S I Q U E', style: TextStyle(fontSize: 8, letterSpacing: 4, color: AionTheme.gold)),
                const SizedBox(height: 4),
                Text('A I O N', style: GoogleFonts.cormorantGaramond(fontSize: 28, fontWeight: FontWeight.bold, color: AionTheme.gold, letterSpacing: 2)),
                Text('O Diário do Sonho', style: GoogleFonts.cormorantGaramond(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.white70)),
              ],
            ),
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 6,
                children: [
                  _navBtn(context, '← NOVO SONHO', false, () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const RecordDreamScreen()),
                    );
                  }),
                  _navBtn(context, 'HISTÓRICO', false, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DreamHistoryScreen(userEmail: 'usuario@aion.app')),
                    );
                  }),
                  _navBtn(context, 'SAIR', false, () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _navBtn(BuildContext context, String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AionTheme.gold : Colors.transparent,
          border: Border.all(color: isActive ? AionTheme.gold : AionTheme.veil),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AionTheme.darkVoid : AionTheme.silver,
            fontSize: 10,
            letterSpacing: 2,
            fontFamily: 'Georgia',
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatefulWidget {
  final String icon;
  final String label;
  final String title;
  final String description;
  final Color accentColor;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon,
    required this.label,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<_ChoiceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _hovered ? AionTheme.darkAbyss : AionTheme.darkDeep,
            border: Border.all(
              color: _hovered ? widget.accentColor.withOpacity(0.5) : AionTheme.shadow,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.icon, style: TextStyle(fontSize: 22, color: widget.accentColor)),
              const SizedBox(height: 16),
              Text(
                widget.label,
                style: GoogleFonts.ptSerif(
                  fontSize: 9,
                  letterSpacing: 3,
                  color: widget.accentColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  height: 1.2,
                  color: AionTheme.ghost,
                  fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 1,
                width: 32,
                color: widget.accentColor.withOpacity(0.35),
                margin: const EdgeInsets.only(bottom: 12),
              ),
              Text(
                widget.description,
                style: GoogleFonts.ptSerif(fontSize: 12, height: 1.7, color: AionTheme.silver),
              ),
              const SizedBox(height: 20),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _hovered ? widget.accentColor : Colors.transparent,
                  border: Border.all(color: widget.accentColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'VER ESTA LEITURA',
                      style: GoogleFonts.ptSerif(
                        fontSize: 9,
                        letterSpacing: 2,
                        color: _hovered ? AionTheme.darkVoid : widget.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color: _hovered ? AionTheme.darkVoid : widget.accentColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
