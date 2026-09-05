import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../core/aion_qa_helpers.dart';
import '../../../core/api_service.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';
import '../../../core/widgets/cinematic_background.dart';
import 'dual_interpretation_screen.dart';
import 'widgets/hero_journey_widget.dart';

class DreamHistoryScreen extends StatefulWidget {
  final String userEmail;
  final String? filtroEmocao;
  final String? filtroFase;

  const DreamHistoryScreen({
    super.key, 
    required this.userEmail,
    this.filtroEmocao,
    this.filtroFase,
  });

  @override
  State<DreamHistoryScreen> createState() => _DreamHistoryScreenState();
}

class _DreamHistoryScreenState extends State<DreamHistoryScreen> {
  List<Map<String, dynamic>> _dreams = [];
  bool _isLoading = true;
  String? _error;

  // Busca semântica + filtros por categoria — exclusivos desta tela
  final _searchController = TextEditingController();
  bool _isSearching = false;
  String? _filtroEmocao;
  String? _filtroFase;

  static const _fases = [
    'O Mundo Comum', 'O Chamado', 'A Travessia do Limiar',
    'Provas e Aliados', 'O Abismo', 'A Recompensa', 'O Retorno',
  ];

  static const _emocoesFilter = [
    'Ansiedade', 'Calmaria', 'Pavor', 'Euforia',
    'Impotência', 'Alívio', 'Confusão', 'Nostalgia',
  ];

  @override
  void initState() {
    super.initState();
    _filtroEmocao = widget.filtroEmocao;
    _filtroFase = widget.filtroFase;
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _buscarSemantico(String query) async {
    final normalized = AionQaHelpers.normalizeSearchQuery(query);
    if (normalized.isEmpty) {
      await _loadHistory();
      return;
    }
    // Mantém o campo com o texto do usuário, mas envia só o trecho normalizado.
    setState(() => _isSearching = true);
    try {
      final session = await ApiService.ensureFreshSession();
      // Mesma guarda que _loadHistory ja fazia. Sem ela, a busca seguia com
      // sessao null e caia no fail-closed do interceptor, produzindo um 401
      // fabricado no proprio aparelho.
      if (session == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Sua sessão expirou (sem token local). '
              'Feche e reabra o app e entre novamente.';
          _isSearching = false;
        });
        return;
      }
      final response = await ApiService.client.post(
        AionConfig.searchUrl,
        data: {
          'query': normalized,
          'threshold': 0.60,
          'max_results': 8,
        },
        options: ApiService.authOptions(session: session),
      );
      final results = List<Map<String, dynamic>>.from(
        (response.data['results'] as List).map((e) => e as Map<String, dynamic>),
      );
      if (mounted) setState(() => _dreams = results);
    } catch (e) {
      debugPrint('[HISTORY] Erro busca semântica: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Não foi possível buscar no diário. Tente novamente.',
              style: GoogleFonts.ptSerif(fontSize: 13, color: AionTheme.ghost),
            ),
            backgroundColor: AionTheme.darkAbyss,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Garante token antes do fetch (evita 403 por request sem Bearer)
    final session = await ApiService.ensureFreshSession();
    if (session == null) {
      if (!mounted) return;
      setState(() {
        _error =
            'Sua sessão expirou (sem token local). Feche e reabra o app e entre novamente.';
        _isLoading = false;
      });
      return;
    }

    try {
      final dio = ApiService.client;
      Response response;

      final authOpts = ApiService.authOptions(session: session);
      if (_filtroEmocao != null || _filtroFase != null) {
        response = await dio.get(
          AionConfig.filterUrl,
          queryParameters: {
            if (_filtroEmocao != null) 'emocao': _filtroEmocao,
            if (_filtroFase != null) 'fase': _filtroFase,
          },
          options: authOpts,
        );
        if (!mounted) return;
        setState(() {
          _dreams = List<Map<String, dynamic>>.from(response.data['dreams'] ?? []);
          _isLoading = false;
        });
      } else {
        response = await dio.get(AionConfig.historyUrl, options: authOpts);
        if (!mounted) return;
        setState(() {
          _dreams = List<Map<String, dynamic>>.from(response.data);
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      final detail = e.response?.data is Map
          ? (e.response!.data['detail']?.toString() ?? '')
          : '';
      final String msg;
      if (detail == ApiService.clientMissingTokenCode) {
        // Bloqueio do proprio app: a request nem chegou a sair. Dizer isso
        // explicitamente evita a confusao com rejeicao do servidor.
        msg = 'O app não tinha uma sessão válida para enviar '
            '(HTTP $status [$detail] — bloqueado no aparelho, sem chegar ao servidor). '
            'Entre novamente.';
      } else if (status == 401 || status == 403) {
        final hint = detail.isNotEmpty ? ' [$detail]' : '';
        msg =
            'Sua sessão expirou (HTTP $status$hint). Feche e reabra o app e tente de novo.';
      } else if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        msg = 'O servidor demorou a responder. Toque em Tentar novamente.';
      } else if (status != null && status >= 500) {
        msg = 'Erro no servidor ao carregar o diário (HTTP $status). Tente novamente.';
      } else if (status != null) {
        msg = 'Não foi possível carregar o diário (HTTP $status).';
      } else {
        msg = 'Não foi possível carregar o diário. Verifique a conexão.';
      }
      setState(() {
        _error = msg;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar o diário.';
        _isLoading = false;
      });
    }
  }

  Widget _buildFilterChip(String label, bool isActive, Color color, VoidCallback onTap) {
    return Semantics(
      button: true,
      selected: isActive,
      label: 'Filtro $label${isActive ? ', selecionado' : ''}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          // Hit target mínimo ~44pt (toque mobile)
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.15) : Colors.transparent,
            border: Border.all(color: isActive ? color.withOpacity(0.6) : AionTheme.shadow),
          ),
          child: Text(label, style: GoogleFonts.ptSerif(
            fontSize: 11, letterSpacing: 1,
            color: isActive ? color : AionTheme.silver.withOpacity(0.7),
          )),
        ),
      ),
    );
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
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back_ios, color: AionTheme.gold, size: 18),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'DIÁRIO DO SONHO',
          style: GoogleFonts.ptSerif(
            fontSize: 10,
            letterSpacing: 3,
            color: AionTheme.gold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Atualizar diário',
            icon: const Icon(Icons.refresh, color: AionTheme.silver, size: 20),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
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

    final padH = (MediaQuery.sizeOf(context).width * 0.05).clamp(12.0, 20.0);
    final hasActiveQuery = _searchController.text.isNotEmpty ||
        _filtroEmocao != null ||
        _filtroFase != null;

    if (_dreams.isEmpty && !hasActiveQuery) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padH),
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
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(padH, 16, padH, 8),
          child: Container(
            decoration: BoxDecoration(
              color: AionTheme.darkAbyss,
              border: Border.all(color: AionTheme.shadow),
            ),
            // Campo limpo: sem histórico, sem sugestões de teclado/OS e sem
            // exemplos no placeholder (evita parecer “palavras sugeridas”).
            child: Semantics(
              textField: true,
              label: 'Buscar no diário do sonho',
              hint: 'Digite um termo e pressione buscar',
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.ptSerif(fontSize: 14, color: AionTheme.ghost),
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                textInputAction: TextInputAction.search,
                keyboardType: TextInputType.text,
                autofillHints: const <String>[],
                decoration: InputDecoration(
                  // Label acessível via Semantics wrapper; hint visual limpo.
                  hintText: 'Buscar no diário...',
                  hintStyle: GoogleFonts.ptSerif(
                      color: AionTheme.silver.withOpacity(0.45), fontSize: 13),
                  prefixIcon: Icon(Icons.search,
                      color: AionTheme.silver.withOpacity(0.5), size: 20,
                      semanticLabel: 'Ícone de busca'),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ))
                      : _searchController.text.isNotEmpty
                          ? IconButton(
                              tooltip: 'Limpar busca',
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              icon: Icon(Icons.close,
                                  size: 18, color: AionTheme.silver.withOpacity(0.5)),
                              onPressed: () {
                                _searchController.clear();
                                _loadHistory();
                              },
                            )
                          : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                onSubmitted: _buscarSemantico,
                onChanged: (v) {
                  setState(() {});
                  if (v.isEmpty) _loadHistory();
                },
              ),
            ),
          ),
        ),
        // Filtros por emoção / fase da jornada (centralizados no Histórico)
        Padding(
          padding: EdgeInsets.fromLTRB(padH, 4, padH, 0),
          child: Text(
            'FILTRAR POR EMOÇÃO OU JORNADA',
            style: GoogleFonts.ptSerif(
              fontSize: 9,
              letterSpacing: 2,
              color: AionTheme.gold.withOpacity(0.8),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: padH),
          child: Row(children: [
            _buildFilterChip(
              'Todos',
              _filtroEmocao == null && _filtroFase == null,
              AionTheme.gold,
              () {
                setState(() {
                  _filtroEmocao = null;
                  _filtroFase = null;
                });
                _loadHistory();
              },
            ),
            const SizedBox(width: 6),
            ..._emocoesFilter.map((e) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _buildFilterChip(
                    e,
                    _filtroEmocao == e,
                    AionTheme.silver,
                    () {
                      setState(() {
                        _filtroEmocao = _filtroEmocao == e ? null : e;
                        _filtroFase = null;
                      });
                      _loadHistory();
                    },
                  ),
                )),
            Container(
              width: 1,
              height: 20,
              color: AionTheme.shadow,
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),
            ..._fases.map((f) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _buildFilterChip(
                    f.split(' ').last,
                    _filtroFase == f,
                    HeroJourneyMapper.getColor(f),
                    () {
                      setState(() {
                        _filtroFase = _filtroFase == f ? null : f;
                        _filtroEmocao = null;
                      });
                      _loadHistory();
                    },
                  ),
                )),
          ]),
        ),
        if (_filtroEmocao != null || _filtroFase != null)
          Padding(
            padding: EdgeInsets.fromLTRB(padH, 10, padH, 0),
            child: Wrap(
              spacing: 8,
              children: [
                if (_filtroEmocao != null)
                  _buildActiveFilterBadge(_filtroEmocao!, AionTheme.silver),
                if (_filtroFase != null)
                  _buildActiveFilterBadge(_filtroFase!, AionTheme.gold),
              ],
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(padH, 24, padH, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${_dreams.length} SONHO${_dreams.length != 1 ? 'S' : ''} ENCONTRADO${_dreams.length != 1 ? 'S' : ''}',
                  style: GoogleFonts.ptSerif(
                    fontSize: 9,
                    letterSpacing: 3,
                    color: AionTheme.silver.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _dreams.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: padH),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        hasActiveQuery
                            ? 'Nenhum sonho encontrado para esta busca ou filtro.'
                            : 'O diário ainda está em branco.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.ptSerif(
                          fontSize: 14,
                          color: AionTheme.silver.withOpacity(0.55),
                          fontStyle: FontStyle.italic,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: padH, vertical: 8),
                  itemCount: _dreams.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final dream = _dreams[index];
                    return Semantics(
                      button: true,
                      label:
                          'Sonho de ${_formatDate(dream['created_at'])}. Toque para abrir interpretação.',
                      child: _DreamHistoryCard(
                        dream: dream,
                        date: _formatDate(dream['created_at']),
                        onTap: () => _openDream(dream),
                        onDelete: () => _confirmDeleteDream(dream),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildActiveFilterBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_list, size: 10, color: color),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.ptSerif(fontSize: 8, color: color, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  void _openDream(Map<String, dynamic> dream) {
    final dreamId = dream['id'] as String? ?? '';
    final relato = dream['relato'] as String? ?? '';

    // Novos campos (migration 003) — disponíveis em sonhos criados após a Fase 1
    final narrativa = (dream['interpretacao_narrativa'] as String?)?.isNotEmpty == true
        ? dream['interpretacao_narrativa'] as String
        : (dream['interpretacao'] as Map<String, dynamic>?)?['narrative'] as String? ?? '';

    final pergunta = (dream['pergunta_reflexao'] as String?)?.isNotEmpty == true
        ? dream['pergunta_reflexao'] as String
        : (dream['interpretacao'] as Map<String, dynamic>?)?['pergunta_para_reflexao'] as String? ?? '';

    final analiseCompleta =
        (dream['analise_completa'] as Map<String, dynamic>?)?.isNotEmpty == true
            ? dream['analise_completa'] as Map<String, dynamic>
            : <String, dynamic>{};

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DualInterpretationScreen(
          dreamId: dreamId,
          dreamText: relato,
          narrativeText: narrativa,
          perguntaReflexao: pergunta,
          analiseCompleta: analiseCompleta,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteDream(Map<String, dynamic> dream) async {
    final dreamId = dream['id'] as String?;
    if (dreamId == null || dreamId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AionTheme.darkAbyss,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AionTheme.shadow),
          borderRadius: BorderRadius.circular(4),
        ),
        title: Text(
          'Excluir este sonho?',
          style: GoogleFonts.ptSerif(color: AionTheme.dawn, fontSize: 16),
        ),
        content: Text(
          'Essa ação não pode ser desfeita. O relato e a leitura simbólica deste sonho serão apagados permanentemente.',
          style: GoogleFonts.ptSerif(color: AionTheme.silver, fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancelar', style: GoogleFonts.ptSerif(color: AionTheme.silver)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Excluir', style: GoogleFonts.ptSerif(color: AionTheme.crimson)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _deleteDream(dreamId);
  }

  Future<void> _deleteDream(String dreamId) async {
    // Remoção otimista com rollback em caso de falha.
    final index = _dreams.indexWhere((d) => d['id'] == dreamId);
    if (index == -1) return;
    final removed = _dreams[index];
    setState(() => _dreams.removeAt(index));

    try {
      await ApiService.client.delete(AionConfig.deleteDreamUrl(dreamId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sonho excluído.', style: GoogleFonts.ptSerif(color: AionTheme.ghost)),
          backgroundColor: AionTheme.darkAbyss,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('[HISTORY] Erro ao excluir sonho: $e');
      if (!mounted) return;
      setState(() => _dreams.insert(index, removed));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível excluir o sonho. Tente novamente.',
            style: GoogleFonts.ptSerif(color: AionTheme.ghost),
          ),
          backgroundColor: AionTheme.crimson,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _DreamHistoryCard extends StatefulWidget {
  final Map<String, dynamic> dream;
  final String date;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DreamHistoryCard({
    required this.dream,
    required this.date,
    required this.onTap,
    required this.onDelete,
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
                  Semantics(
                    button: true,
                    label: 'Excluir este sonho',
                    child: IconButton(
                      tooltip: 'Excluir sonho',
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: AionTheme.silver.withOpacity(0.4),
                      ),
                      onPressed: widget.onDelete,
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
