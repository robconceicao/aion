import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';

class NarrativeResultScreen extends StatefulWidget {
  final String dreamText;
  final String narrativeText;
  final String perguntaReflexao;

  const NarrativeResultScreen({
    super.key,
    required this.dreamText,
    required this.narrativeText,
    this.perguntaReflexao = '',
  });

  @override
  State<NarrativeResultScreen> createState() => _NarrativeResultScreenState();
}

class _NarrativeResultScreenState extends State<NarrativeResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> _parseNarrative(String text) {
    return text
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  List<InlineSpan> _buildRichSpans(String text) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(color: AionTheme.amber, fontWeight: FontWeight.w600),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final paragraphs = _parseNarrative(widget.narrativeText);
    return Scaffold(
      backgroundColor: AionTheme.darkVoid,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: FadeTransition(
              opacity: _fadeIn,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back, size: 14,
                                    color: AionTheme.silver.withOpacity(0.5)),
                                const SizedBox(width: 8),
                                Text('VOLTAR',
                                    style: GoogleFonts.ptSerif(
                                      fontSize: 9,
                                      letterSpacing: 3,
                                      color: AionTheme.silver.withOpacity(0.5),
                                    )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            decoration: BoxDecoration(
                              color: AionTheme.tealBg,
                              border: Border.all(color: AionTheme.tealBd),
                            ),
                            child: Text(
                              '⚠ Esta análise é uma reflexão simbólica baseada em Jung e Campbell — não substitui acompanhamento psicológico profissional.',
                              style: GoogleFonts.ptSerif(
                                fontSize: 12,
                                color: AionTheme.tealText,
                                height: 1.7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text('LEITURA SIMBÓLICA',
                              style: GoogleFonts.ptSerif(
                                fontSize: 9, letterSpacing: 4, color: AionTheme.gold,
                              )),
                          const SizedBox(height: 16),
                          Text('Voz do Arquétipo',
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 36, height: 1.2, color: AionTheme.ghost,
                                fontWeight: FontWeight.w300, fontStyle: FontStyle.italic,
                              )),
                          const SizedBox(height: 28),
                          _buildDivider(),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: AionTheme.gold.withOpacity(0.35), width: 2,
                                ),
                              ),
                              color: AionTheme.darkAbyss.withOpacity(0.5),
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(4),
                                bottomRight: Radius.circular(4),
                              ),
                            ),
                            child: Text('"${widget.dreamText}"',
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 15, fontStyle: FontStyle.italic,
                                  color: AionTheme.silver, height: 1.75,
                                )),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _buildParagraph(paragraphs[i]),
                        childCount: paragraphs.length,
                      ),
                    ),
                  ),
                  // Caixa de reflexão sempre presente, vinda do JSON
                  if (widget.perguntaReflexao.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _buildQuestionBlock(widget.perguntaReflexao),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 48, 24, 64),
                      child: Column(
                        children: [
                          _buildDivider(),
                          const SizedBox(height: 32),
                          Text(
                            '"Quem olha para fora, sonha.\nQuem olha para dentro, desperta."',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 14, fontStyle: FontStyle.italic,
                              color: AionTheme.silver.withOpacity(0.4), height: 1.7,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('— C. G. Jung',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.ptSerif(
                                fontSize: 10, letterSpacing: 2,
                                color: AionTheme.silver.withOpacity(0.3),
                              )),
                          const SizedBox(height: 48),
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AionTheme.gold),
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                              shape: const RoundedRectangleBorder(),
                            ),
                            child: Text(
                              'VOLTAR AO DIÁRIO',
                              style: GoogleFonts.ptSerif(
                                fontSize: 12,
                                letterSpacing: 3,
                                color: AionTheme.gold,
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
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.cormorantGaramond(
            fontSize: 18, height: 1.85,
            color: AionTheme.ghost.withOpacity(0.88), fontWeight: FontWeight.w300,
          ),
          children: _buildRichSpans(text),
        ),
      ),
    );
  }

  Widget _buildQuestionBlock(String text) {
    // Remove aspas externas duplicadas se já existirem
    final cleanText = text.startsWith('"') ? text : '"$text"';
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 40),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: AionTheme.darkDeep,
        border: Border.all(color: AionTheme.gold.withOpacity(0.28)),
      ),
      child: Column(
        children: [
          Text(
            'PERGUNTA PARA REFLEXÃO',
            style: GoogleFonts.ptSerif(
              fontSize: 9,
              letterSpacing: 4,
              color: AionTheme.gold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            cleanText,
            textAlign: TextAlign.center,
            style: GoogleFonts.ptSerif(
              fontSize: 18,
              color: AionTheme.dawn,
              fontStyle: FontStyle.italic,
              height: 1.9,
            ),
          ),
        ],
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
          child: Text('✦',
              style: TextStyle(color: AionTheme.gold.withOpacity(0.5), fontSize: 10)),
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
}


