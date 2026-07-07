import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/theme.dart';
import '../../../core/api_service.dart';
import '../../../core/widgets/cinematic_background.dart';
import 'widgets/hero_journey_widget.dart';

/// Tela de interpretação dual — exibe os dois formatos em abas (SPEC §7.1).
///
/// Aba 0 "Interpretação": narrativa acessível + player TTS.
/// Aba 1 "Análise Completa": seções técnicas estruturadas (JSONB).
///
/// [isLegacy]: true quando analise_completa está vazio (sonhos anteriores à
/// migration 003). Nesse caso a aba de análise exibe aviso adequado.
class DualInterpretationScreen extends StatefulWidget {
  final String dreamId;
  final String dreamText;
  final String narrativeText;
  final String perguntaReflexao;
  final Map<String, dynamic> analiseCompleta;
  final int initialTab;

  const DualInterpretationScreen({
    super.key,
    required this.dreamId,
    required this.dreamText,
    required this.narrativeText,
    required this.perguntaReflexao,
    required this.analiseCompleta,
    this.initialTab = 0,
  });

  bool get isLegacy =>
      analiseCompleta.isEmpty ||
      (analiseCompleta['sintese_tecnica'] == null &&
       analiseCompleta['simbolos'] == null);

  @override
  State<DualInterpretationScreen> createState() => _DualInterpretationScreenState();
}

// ─── Estados do player de áudio ────────────────────────────────
enum _AudioState { idle, loading, playing, paused, error }

class _DualInterpretationScreenState extends State<DualInterpretationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  _AudioState _audioState = _AudioState.idle;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() {
        _audioState = _AudioState.idle;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ─── Lógica do player ────────────────────────────────────────

  Future<void> _onPlayPause() async {
    if (_audioState == _AudioState.loading) return;

    if (_audioState == _AudioState.playing) {
      await _audioPlayer.pause();
      setState(() => _audioState = _AudioState.paused);
      return;
    }

    if (_audioState == _AudioState.paused) {
      await _audioPlayer.resume();
      setState(() => _audioState = _AudioState.playing);
      return;
    }

    // idle ou error — requisita áudio ao backend
    setState(() => _audioState = _AudioState.loading);
    try {
      final signedUrl = await ApiService.requestAudio(widget.dreamId);
      await _audioPlayer.play(UrlSource(signedUrl));
      if (mounted) setState(() => _audioState = _AudioState.playing);
    } catch (e) {
      debugPrint('[PLAYER] Falha ao carregar áudio: $e');
      if (mounted) {
        setState(() => _audioState = _AudioState.error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Áudio indisponível no momento — leia o texto abaixo.',
              style: GoogleFonts.ptSerif(fontSize: 13, color: AionTheme.ghost),
            ),
            backgroundColor: AionTheme.darkAbyss,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ─── Build principal ─────────────────────────────────────────

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
          'AION',
          style: GoogleFonts.ptSerif(
            fontSize: 10, letterSpacing: 6, color: AionTheme.gold,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AionTheme.gold,
          unselectedLabelColor: AionTheme.silver.withOpacity(0.5),
          indicatorColor: AionTheme.gold,
          indicatorWeight: 1,
          labelStyle: GoogleFonts.ptSerif(fontSize: 9, letterSpacing: 2),
          unselectedLabelStyle: GoogleFonts.ptSerif(fontSize: 9, letterSpacing: 2),
          tabs: const [
            Tab(text: 'INTERPRETAÇÃO'),
            Tab(text: 'ANÁLISE COMPLETA'),
          ],
        ),
      ),
      body: CinematicBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildNarrativeTab(),
                  _buildAnalysisTab(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Aba 0: Interpretação (narrativa + player) ───────────────

  Widget _buildNarrativeTab() {
    final paragraphs = _parseNarrative(widget.narrativeText);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildPlayerBar()),
        SliverToBoxAdapter(child: _buildEthicalWarning()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LEITURA SIMBÓLICA',
                    style: GoogleFonts.ptSerif(
                      fontSize: 9, letterSpacing: 4, color: AionTheme.gold,
                    )),
                const SizedBox(height: 10),
                Text('Voz do Arquétipo',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 34, height: 1.2, color: AionTheme.ghost,
                      fontWeight: FontWeight.w300, fontStyle: FontStyle.italic,
                    )),
                const SizedBox(height: 24),
                _buildDivider(),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: AionTheme.gold.withOpacity(0.35), width: 2),
                    ),
                    color: AionTheme.darkAbyss.withOpacity(0.5),
                  ),
                  child: Text(
                    '"${widget.dreamText}"',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 14, fontStyle: FontStyle.italic,
                      color: AionTheme.silver, height: 1.75,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
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
        if (widget.perguntaReflexao.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildQuestionBlock(widget.perguntaReflexao),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 64),
            child: Column(
              children: [
                _buildDivider(),
                const SizedBox(height: 28),
                Text(
                  '"Quem olha para fora, sonha.\nQuem olha para dentro, desperta."',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 13, fontStyle: FontStyle.italic,
                    color: AionTheme.silver.withOpacity(0.35), height: 1.7,
                  ),
                ),
                const SizedBox(height: 6),
                Text('— C. G. Jung',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ptSerif(
                      fontSize: 9, letterSpacing: 2,
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
                  child: Text('VOLTAR AO DIÁRIO',
                      style: GoogleFonts.ptSerif(
                        fontSize: 12, letterSpacing: 3, color: AionTheme.gold,
                      )),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerBar() {
    final isLoading = _audioState == _AudioState.loading;
    final isPlaying = _audioState == _AudioState.playing;
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AionTheme.darkAbyss,
        border: const Border(bottom: BorderSide(color: AionTheme.shadow)),
      ),
      child: Row(
        children: [
          // Botão play/pause/loading
          GestureDetector(
            onTap: _onPlayPause,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _audioState == _AudioState.error
                      ? AionTheme.crimson.withOpacity(0.5)
                      : AionTheme.gold.withOpacity(0.6),
                ),
              ),
              child: isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AionTheme.gold.withOpacity(0.6),
                      ),
                    )
                  : Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 20,
                      color: _audioState == _AudioState.error
                          ? AionTheme.crimson.withOpacity(0.6)
                          : AionTheme.gold.withOpacity(0.7),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          // Progresso + label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isLoading
                      ? 'PREPARANDO ÁUDIO...'
                      : _audioState == _AudioState.error
                          ? 'ÁUDIO INDISPONÍVEL'
                          : isPlaying || _audioState == _AudioState.paused
                              ? '${_formatDuration(_position)} / ${_formatDuration(_duration)}'
                              : 'ESCUTAR INTERPRETAÇÃO',
                  style: GoogleFonts.ptSerif(
                    fontSize: 9,
                    letterSpacing: 2,
                    color: _audioState == _AudioState.error
                        ? AionTheme.crimson.withOpacity(0.6)
                        : AionTheme.gold.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(1),
                  child: LinearProgressIndicator(
                    value: isLoading ? null : progress.clamp(0.0, 1.0),
                    minHeight: 2,
                    backgroundColor: AionTheme.shadow,
                    color: _audioState == _AudioState.error
                        ? AionTheme.crimson.withOpacity(0.4)
                        : AionTheme.gold.withOpacity(0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Aba 1: Análise Completa ─────────────────────────────────

  Widget _buildAnalysisTab() {
    if (widget.isLegacy) {
      return _buildLegacyNotice();
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildEthicalWarning(),
          const SizedBox(height: 14),
          _buildDreamSection(),
          const SizedBox(height: 14),
          _buildSymbolsSection(),
          const SizedBox(height: 14),
          _buildArchetypesSection(),
          const SizedBox(height: 14),
          _buildCompensacaoSection(),
          const SizedBox(height: 14),
          _buildFaseJornadaSection(),
          const SizedBox(height: 14),
          _buildSinteseTecnicaSection(),
          const SizedBox(height: 48),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AionTheme.gold),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: const RoundedRectangleBorder(),
            ),
            child: Text('VOLTAR AO DIÁRIO',
                style: GoogleFonts.ptSerif(
                  fontSize: 12, letterSpacing: 3, color: AionTheme.gold,
                )),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildLegacyNotice() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('◯', style: TextStyle(fontSize: 40, color: AionTheme.gold.withOpacity(0.3))),
            const SizedBox(height: 24),
            Text(
              'ANÁLISE TÉCNICA INDISPONÍVEL',
              style: GoogleFonts.ptSerif(
                fontSize: 10, letterSpacing: 3,
                color: AionTheme.silver.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Este sonho foi registrado antes do formato de análise estruturada. '
              'A interpretação narrativa está disponível na aba "Interpretação".\n\n'
              'Registre um novo sonho para acessar a análise técnica completa com '
              'símbolos, arquétipos, compensação e fase da jornada.',
              textAlign: TextAlign.center,
              style: GoogleFonts.ptSerif(
                fontSize: 13, color: AionTheme.silver.withOpacity(0.5),
                height: 1.7, fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSymbolsSection() {
    final simbolos = (widget.analiseCompleta['simbolos'] as List? ?? []);
    if (simbolos.isEmpty) return const SizedBox.shrink();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('⋈ SÍMBOLOS & AMPLIFICAÇÃO', color: AionTheme.gold),
          const SizedBox(height: 4),
          ...simbolos.asMap().entries.map((entry) {
            final s = entry.value as Map<String, dynamic>;
            final isLast = entry.key == simbolos.length - 1;
            return Container(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
              decoration: BoxDecoration(
                border: isLast ? null : const Border(bottom: BorderSide(color: AionTheme.shadow)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (s['elemento'] ?? '').toString(),
                    style: const TextStyle(color: AionTheme.amber, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (s['significado'] ?? '').toString(),
                    style: const TextStyle(color: AionTheme.silver, fontSize: 12, height: 1.6),
                  ),
                  if ((s['amplificacao'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      (s['amplificacao'] ?? '').toString(),
                      style: TextStyle(
                        color: AionTheme.silver.withOpacity(0.6),
                        fontSize: 11, height: 1.5, fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildArchetypesSection() {
    final arquetipos = (widget.analiseCompleta['arquetipos'] as List? ?? []);
    if (arquetipos.isEmpty) return const SizedBox.shrink();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('ARQUÉTIPOS PRESENTES', color: AionTheme.silver),
          const SizedBox(height: 4),
          ...arquetipos.map((a) {
            final arq = a as Map<String, dynamic>;
            final name = (arq['arquetipo'] ?? '').toString();
            final color = AionTheme.getArchetypeColor(name);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AionTheme.darkVoid,
                border: Border(left: BorderSide(color: color, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.toUpperCase(),
                    style: TextStyle(fontSize: 10, color: color, letterSpacing: 1, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (arq['manifestacao'] ?? '').toString(),
                    style: const TextStyle(fontSize: 12, color: AionTheme.silver, height: 1.6),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCompensacaoSection() {
    final compensacao = (widget.analiseCompleta['compensacao'] as String? ?? '');
    if (compensacao.isEmpty) return const SizedBox.shrink();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('⊗ FUNÇÃO COMPENSATÓRIA', color: AionTheme.amber),
          Text(compensacao, style: const TextStyle(fontSize: 12, color: AionTheme.ghost, height: 1.7)),
        ],
      ),
    );
  }

  Widget _buildFaseJornadaSection() {
    final fase = (widget.analiseCompleta['fase_jornada'] as String? ?? '');
    if (fase.isEmpty) return const SizedBox.shrink();
    return HeroJourneyWidget(
      stageName: fase,
      stageDescription: '',
    );
  }

  Widget _buildSinteseTecnicaSection() {
    final sintese = (widget.analiseCompleta['sintese_tecnica'] as String? ?? '');
    if (sintese.isEmpty) return const SizedBox.shrink();
    return _card(
      borderLeft: const BorderSide(color: AionTheme.gold, width: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('☽ SÍNTESE TÉCNICA', color: AionTheme.gold),
          Text(
            sintese,
            style: GoogleFonts.ptSerif(
              fontSize: 14, fontStyle: FontStyle.italic,
              color: AionTheme.dawn, height: 1.85,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Widgets auxiliares compartilhados ───────────────────────

  Widget _buildEthicalWarning() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AionTheme.tealBg,
        border: Border.all(color: AionTheme.tealBd),
      ),
      child: Text(
        '⚠ Esta análise é uma reflexão simbólica baseada em Jung e Campbell — não substitui acompanhamento psicológico profissional.',
        style: GoogleFonts.ptSerif(fontSize: 11, color: AionTheme.tealText, height: 1.6),
      ),
    );
  }

  Widget _buildDreamSection() {
    return _card(
      borderLeft: const BorderSide(color: AionTheme.veil, width: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('O SONHO', color: AionTheme.silver),
          Text(
            '"${widget.dreamText}"',
            style: GoogleFonts.ptSerif(
              fontSize: 13, fontStyle: FontStyle.italic,
              color: AionTheme.ghost, height: 1.85,
            ),
          ),
        ],
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
        style: const TextStyle(color: AionTheme.amber, fontWeight: FontWeight.w600),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    return spans;
  }

  List<String> _parseNarrative(String text) {
    return text
        .split('\n')
        .map((p) => p.trim())
        .map((p) => p.replaceAll(RegExp(r'^\*+|\*+$'), '').trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  Widget _buildQuestionBlock(String text) {
    final cleanText = text.startsWith('"') ? text : '"$text"';
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 40),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: AionTheme.darkDeep,
        border: Border.all(color: AionTheme.gold.withOpacity(0.28)),
      ),
      child: Column(
        children: [
          Text('PERGUNTA PARA REFLEXÃO',
              style: GoogleFonts.ptSerif(fontSize: 9, letterSpacing: 4, color: AionTheme.gold)),
          const SizedBox(height: 16),
          Text(
            cleanText,
            textAlign: TextAlign.center,
            style: GoogleFonts.ptSerif(
              fontSize: 17, color: AionTheme.dawn, fontStyle: FontStyle.italic, height: 1.9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Row(children: [
      Expanded(child: Container(height: 1, decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.transparent, AionTheme.gold.withOpacity(0.3)]),
      ))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('✦', style: TextStyle(color: AionTheme.gold.withOpacity(0.5), fontSize: 10)),
      ),
      Expanded(child: Container(height: 1, decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AionTheme.gold.withOpacity(0.3), Colors.transparent]),
      ))),
    ]);
  }

  Widget _card({required Widget child, EdgeInsets? padding, BorderSide? borderLeft}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AionTheme.darkAbyss,
        border: Border.all(color: AionTheme.shadow),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: borderLeft != null ? Border(left: borderLeft) : null,
        ),
        padding: borderLeft != null ? const EdgeInsets.only(left: 14) : null,
        child: child,
      ),
    );
  }

  Widget _label(String text, {required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(fontSize: 8.5, letterSpacing: 1.5, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
