import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';

class NarrativeResultScreen extends StatefulWidget {
  final String dreamText;
  final String narrativeText;

  const NarrativeResultScreen({
    super.key,
    required this.dreamText,
    required this.narrativeText,
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

  List<_TextBlock> _parseNarrative(String text) {
    final paragraphs = text
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final blocks = <_TextBlock>[];
    for (int i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i];
      final isQuestion = p.endsWith('?') && i == paragraphs.length - 1;
      blocks.add(_TextBlock(text: p, isQuestion: isQuestion));
    }
    return blocks;
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
    final blocks = _parseNarrative(widget.narrativeText);
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
                          const SizedBox(height: 40),
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
                        (context, i) {
                          final block = blocks[i];
                          return block.isQuestion
                              ? _buildQuestionBlock(block.text)
                              : _buildParagraph(block.text);
                        },
                        childCount: blocks.length,
                      ),
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
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 40),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        border: Border.all(color: AionTheme.gold.withOpacity(0.2)),
        color: AionTheme.darkAbyss,
      ),
      child: Column(
        children: [
          Text('PERGUNTA PARA REFLEXÃO',
              style: GoogleFonts.ptSerif(
                fontSize: 9, letterSpacing: 4,
                color: AionTheme.gold.withOpacity(0.6),
              )),
          const SizedBox(height: 16),
          Text(text,
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 20, height: 1.6, color: AionTheme.ghost,
                fontStyle: FontStyle.italic, fontWeight: FontWeight.w300,
              )),
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

class _TextBlock {
  final String text;
  final bool isQuestion;
  const _TextBlock({required this.text, required this.isQuestion});
}
