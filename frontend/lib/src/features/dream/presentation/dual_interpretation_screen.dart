import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/aion_qa_helpers.dart';
import '../../../core/api_service.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/cinematic_background.dart';
import 'widgets/hero_journey_widget.dart';

/// Tela de interpretação dual — exibe os dois formatos em abas (SPEC §7.1).
///
/// Aba 0 "Interpretação": narrativa acessível + narração premium da Leitura
/// Simbólica (MP3 gerado no backend, entregue por URL assinada).
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

// ─── Estados do player de narração ─────────────────────────────
enum _AudioState { idle, loading, playing, paused, error }

/// Taxas de reprodução do MP3 narrado (audioplayers: 1.0 = velocidade original).
const List<({String label, double rate})> _speechRates = [
  (label: '0.8×', rate: 0.8),
  (label: '1×', rate: 1.0),
  (label: '1.2×', rate: 1.2),
];

class _DualInterpretationScreenState extends State<DualInterpretationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Narração premium (ElevenLabs) servida pelo backend como MP3 assinado.
  /// O app não conhece o provedor de voz — só consome a URL do Aion.
  final AudioPlayer _player = AudioPlayer();

  _AudioState _audioState = _AudioState.idle;
  int _rateIndex = 1; // 1× padrão
  /// Progresso 0–1 da reprodução.
  double _speechProgress = 0.0;

  /// URL assinada já obtida — evita novo POST ao pausar/retomar.
  String? _signedUrl;
  Duration _duracao = Duration.zero;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _initPlayer();
  }

  void _initPlayer() {
    _subs.add(_player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duracao = d);
    }));
    _subs.add(_player.onPositionChanged.listen((p) {
      if (!mounted || _duracao.inMilliseconds <= 0) return;
      setState(() {
        _speechProgress =
            (p.inMilliseconds / _duracao.inMilliseconds).clamp(0.0, 1.0);
      });
    }));
    _subs.add(_player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _audioState = _AudioState.idle;
        _speechProgress = 0.0;
      });
    }));
    _subs.add(_player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      // Interrupção externa (chamada telefônica, outro app tomando o foco
      // de áudio): o player pausa sozinho e a UI precisa refletir isso.
      if (s == PlayerState.paused && _audioState == _AudioState.playing) {
        setState(() => _audioState = _AudioState.paused);
      }
    }));
  }


  @override
  void dispose() {
    _tabController.dispose();
    // Narração não continua em segundo plano — para ao sair da tela.
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  /// Texto da Leitura Simbólica. A sanitização para voz é feita no backend;
  /// aqui só verificamos se há conteúdo a narrar.
  String _speechText() => AionQaHelpers.sanitizeSpeechText(widget.narrativeText);

  // ─── Lógica do player de narração ────────────────────────────

  Future<void> _onPlayPause() async {
    if (_audioState == _AudioState.loading) return;

    if (_speechText().isEmpty) {
      _showTtsMessage(
        'Não há texto de leitura simbólica para narrar neste sonho.',
      );
      setState(() => _audioState = _AudioState.error);
      return;
    }

    if (_audioState == _AudioState.playing) {
      await _player.pause();
      if (mounted) setState(() => _audioState = _AudioState.paused);
      return;
    }

    if (_audioState == _AudioState.paused) {
      try {
        await _player.resume();
        if (mounted) setState(() => _audioState = _AudioState.playing);
      } catch (e) {
        debugPrint('[NARRACAO] resume falhou: $e');
        if (mounted) {
          setState(() => _audioState = _AudioState.error);
          _showTtsMessage('Não foi possível retomar a narração. Tente novamente.');
        }
      }
      return;
    }

    // idle ou error — pede a narração ao backend (ou usa a URL já obtida).
    setState(() {
      _audioState = _AudioState.loading;
      _speechProgress = 0.0;
    });

    try {
      final url = _signedUrl ??
          (await ApiService.requestNarracao(widget.dreamId)).signedUrl;
      if (!mounted) return;
      _signedUrl = url;

      await _player.play(UrlSource(url));
      await _player.setPlaybackRate(_speechRates[_rateIndex].rate);
      if (mounted) setState(() => _audioState = _AudioState.playing);
    } on NarracaoException catch (e) {
      // Mensagem já vem legível do ApiService — sem jargão de API.
      if (!mounted) return;
      setState(() => _audioState = _AudioState.error);
      _showTtsMessage(e.message);
    } catch (e) {
      debugPrint('[NARRACAO] Falha ao reproduzir: $e');
      if (!mounted) return;
      setState(() => _audioState = _AudioState.error);
      // URL assinada expira em 1h; descartar força novo pedido (vem do cache).
      _signedUrl = null;
      _showTtsMessage(
        'Não foi possível reproduzir a narração — leia o texto abaixo.',
      );
    }
  }

  Future<void> _onStop() async {
    await _player.stop();
    if (mounted) {
      setState(() {
        _audioState = _AudioState.idle;
        _speechProgress = 0.0;
      });
    }
  }

  Future<void> _cycleSpeechRate() async {
    final next = (_rateIndex + 1) % _speechRates.length;
    setState(() => _rateIndex = next);
    try {
      await _player.setPlaybackRate(_speechRates[next].rate);
    } catch (e) {
      debugPrint('[NARRACAO] setPlaybackRate falhou: $e');
    }
  }

  void _showTtsMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.ptSerif(fontSize: 13, color: AionTheme.ghost),
        ),
        backgroundColor: AionTheme.darkAbyss,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
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
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back_ios, color: AionTheme.gold, size: 18),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          onPressed: () {
            _player.stop();
            Navigator.pop(context);
          },
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
          unselectedLabelColor: AionTheme.silver.withValues(alpha: 0.5),
          indicatorColor: AionTheme.gold,
          indicatorWeight: 1,
          labelStyle: GoogleFonts.ptSerif(fontSize: 9, letterSpacing: 1.5),
          unselectedLabelStyle: GoogleFonts.ptSerif(fontSize: 9, letterSpacing: 1.5),
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
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
    final width = MediaQuery.sizeOf(context).width;
    final padH = (width * 0.05).clamp(16.0, 24.0);
    final titleSize = (width * 0.085).clamp(26.0, 34.0);
    final bodySize = (width * 0.045).clamp(16.0, 18.0);

    return CustomScrollView(
      slivers: [
        if (widget.narrativeText.trim().isNotEmpty)
          // Player TTS só na leitura simbólica (escopo da task).
          SliverToBoxAdapter(child: _buildPlayerBar()),
        SliverToBoxAdapter(child: _buildEthicalWarning()),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(padH, 24, padH, 0),
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
                      fontSize: titleSize, height: 1.2, color: AionTheme.ghost,
                      fontWeight: FontWeight.w300, fontStyle: FontStyle.italic,
                    )),
                const SizedBox(height: 24),
                _buildDivider(),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: AionTheme.gold.withValues(alpha: 0.35), width: 2),
                    ),
                    color: AionTheme.darkAbyss.withValues(alpha: 0.5),
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
        if (paragraphs.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: 24),
              child: Text(
                'A leitura simbólica ainda não está disponível para este sonho.',
                style: GoogleFonts.ptSerif(
                  fontSize: 14,
                  color: AionTheme.silver.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: padH),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _buildParagraph(paragraphs[i], fontSize: bodySize),
                childCount: paragraphs.length,
              ),
            ),
          ),
        if (widget.perguntaReflexao.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padH),
              child: _buildQuestionBlock(widget.perguntaReflexao),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(padH, 40, padH, 64),
            child: Column(
              children: [
                _buildDivider(),
                const SizedBox(height: 28),
                Text(
                  '"Quem olha para fora, sonha.\nQuem olha para dentro, desperta."',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 13, fontStyle: FontStyle.italic,
                    color: AionTheme.silver.withValues(alpha: 0.35), height: 1.7,
                  ),
                ),
                const SizedBox(height: 6),
                Text('— C. G. Jung',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ptSerif(
                      fontSize: 9, letterSpacing: 2,
                      color: AionTheme.silver.withValues(alpha: 0.3),
                    )),
                const SizedBox(height: 48),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    side: const BorderSide(color: AionTheme.gold),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
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
    final isPaused = _audioState == _AudioState.paused;
    final isError = _audioState == _AudioState.error;
    final isActive = isPlaying || isPaused;

    final String label;
    if (isLoading) {
      label = 'PREPARANDO VOZ...';
    } else if (isError) {
      label = 'VOZ INDISPONÍVEL';
    } else if (isPlaying) {
      label = 'NARRANDO LEITURA SIMBÓLICA';
    } else if (isPaused) {
      label = 'PAUSADO — TOQUE PARA CONTINUAR';
    } else {
      label = 'ESCUTAR LEITURA SIMBÓLICA';
    }

    final playLabel = isLoading
        ? 'Preparando narração'
        : isError
            ? 'Tentar narração novamente'
            : isPlaying
                ? 'Pausar narração da leitura simbólica'
                : isPaused
                    ? 'Continuar narração da leitura simbólica'
                    : 'Reproduzir leitura simbólica';

    return Semantics(
      container: true,
      label: 'Controles de áudio da interpretação',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AionTheme.darkAbyss,
          border: const Border(bottom: BorderSide(color: AionTheme.shadow)),
        ),
        child: Row(
          children: [
            // Play / pause
            Semantics(
              button: true,
              enabled: !isLoading,
              label: playLabel,
              child: InkWell(
                onTap: isLoading ? null : _onPlayPause,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isError
                          ? AionTheme.crimson.withValues(alpha: 0.5)
                          : AionTheme.gold.withValues(alpha: 0.6),
                    ),
                  ),
                  child: isLoading
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AionTheme.gold.withValues(alpha: 0.6),
                          ),
                        )
                      : Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 24,
                          color: isError
                              ? AionTheme.crimson.withValues(alpha: 0.6)
                              : AionTheme.gold.withValues(alpha: 0.85),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Stop (só quando ativo)
            if (isActive)
              Semantics(
                button: true,
                label: 'Parar narração',
                child: InkWell(
                  onTap: _onStop,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AionTheme.silver.withValues(alpha: 0.35)),
                    ),
                    child: Icon(
                      Icons.stop,
                      size: 20,
                      color: AionTheme.silver.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ),
            if (isActive) const SizedBox(width: 10),
            // Progresso + label (live region anuncia mudanças de estado)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    liveRegion: true,
                    label: label,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ptSerif(
                        fontSize: 9,
                        letterSpacing: 1.5,
                        color: isError
                            ? AionTheme.crimson.withValues(alpha: 0.7)
                            : AionTheme.gold.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: LinearProgressIndicator(
                      value: isLoading
                          ? null
                          : isActive
                              ? _speechProgress.clamp(0.0, 1.0)
                              : 0.0,
                      minHeight: 2,
                      backgroundColor: AionTheme.shadow,
                      color: isError
                          ? AionTheme.crimson.withValues(alpha: 0.4)
                          : AionTheme.gold.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Velocidade da voz
            Semantics(
              button: true,
              label:
                  'Velocidade da voz ${_speechRates[_rateIndex].label}. Toque para alternar',
              child: InkWell(
                onTap: _cycleSpeechRate,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AionTheme.shadow),
                  ),
                  child: Text(
                    _speechRates[_rateIndex].label,
                    style: GoogleFonts.ptSerif(
                      fontSize: 11,
                      letterSpacing: 0.5,
                      color: AionTheme.gold.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Aba 1: Análise Completa ─────────────────────────────────

  Widget _buildAnalysisTab() {
    if (widget.isLegacy) {
      return _buildLegacyNotice();
    }
    final padH = (MediaQuery.sizeOf(context).width * 0.05).clamp(14.0, 20.0);
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: 20),
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
              minimumSize: const Size(44, 44),
              side: const BorderSide(color: AionTheme.gold),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
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
            Text('◯', style: TextStyle(fontSize: 40, color: AionTheme.gold.withValues(alpha: 0.3))),
            const SizedBox(height: 24),
            Text(
              'ANÁLISE TÉCNICA INDISPONÍVEL',
              style: GoogleFonts.ptSerif(
                fontSize: 10, letterSpacing: 3,
                color: AionTheme.silver.withValues(alpha: 0.5),
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
                fontSize: 13, color: AionTheme.silver.withValues(alpha: 0.5),
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
                        color: AionTheme.silver.withValues(alpha: 0.6),
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
    final padH = (MediaQuery.sizeOf(context).width * 0.05).clamp(14.0, 20.0);
    return Container(
      margin: EdgeInsets.fromLTRB(padH, 12, padH, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

  Widget _buildParagraph(String text, {double fontSize = 18}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.cormorantGaramond(
            fontSize: fontSize, height: 1.85,
            color: AionTheme.ghost.withValues(alpha: 0.88), fontWeight: FontWeight.w300,
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
    final qSize = (MediaQuery.sizeOf(context).width * 0.042).clamp(14.0, 17.0);
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 40),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: AionTheme.darkDeep,
        border: Border.all(color: AionTheme.gold.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          Text('PERGUNTA PARA REFLEXÃO',
              style: GoogleFonts.ptSerif(fontSize: 9, letterSpacing: 3, color: AionTheme.gold)),
          const SizedBox(height: 16),
          Text(
            cleanText,
            textAlign: TextAlign.center,
            style: GoogleFonts.ptSerif(
              fontSize: qSize, color: AionTheme.dawn, fontStyle: FontStyle.italic, height: 1.9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Row(children: [
      Expanded(child: Container(height: 1, decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.transparent, AionTheme.gold.withValues(alpha: 0.3)]),
      ))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('✦', style: TextStyle(color: AionTheme.gold.withValues(alpha: 0.5), fontSize: 10)),
      ),
      Expanded(child: Container(height: 1, decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AionTheme.gold.withValues(alpha: 0.3), Colors.transparent]),
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
