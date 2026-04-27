import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';
import 'record_dream_screen.dart';
import 'archetypes_screen.dart';

// ─── Modelo de Episódio ────────────────────────────────────────────────────
class Episode {
  final int number;
  final String titleMain;
  final String titleSecondary;
  final List<String> mythsSymbols;
  final String? description;

  Episode({
    required this.number,
    required this.titleMain,
    required this.titleSecondary,
    required this.mythsSymbols,
    this.description,
  });

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
        number: json['number'] as int,
        titleMain: json['title_main'] as String,
        titleSecondary: json['title_secondary'] as String,
        mythsSymbols: List<String>.from(json['myths_symbols'] ?? []),
        description: json['description'] as String?,
      );
}

// ─── Tela: Canal Mito & Psique ────────────────────────────────────────────
class CanalScreen extends StatefulWidget {
  const CanalScreen({super.key});

  @override
  State<CanalScreen> createState() => _CanalScreenState();
}

class _CanalScreenState extends State<CanalScreen> {
  List<Episode> _episodes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchEpisodes();
  }

  Future<void> _fetchEpisodes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = Dio();
      final response = await dio.get(AionConfig.episodesUrl);
      final List<dynamic> data = response.data as List<dynamic>;
      setState(() {
        _episodes = data.map((e) => Episode.fromJson(e as Map<String, dynamic>)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _episodes = [];
        _isLoading = false;
        // Se o servidor retornar 404 ou lista vazia, é estado válido (sem episódios ainda)
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AionTheme.darkVoid,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNav(),
                  Expanded(child: _buildBody()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Barra de navegação ────────────────────────────────────────────────
  Widget _buildNav() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'M I T O  &  P S I Q U E',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 5,
                    color: AionTheme.gold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'O Canal',
                  style: TextStyle(
                    fontSize: 22,
                    letterSpacing: 2,
                    fontFamily: 'Georgia',
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _navBtn('INÍCIO', false, () => Navigator.pop(context)),
                _navBtn('+ SONHO', false, () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RecordDreamScreen(),
                    ),
                  );
                }),
                _navBtn('ARQUÉTIPOS', false, () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ArchetypesScreen(),
                    ),
                  );
                }),
                _navBtn('CANAL', true, () {}),
              ],
            ),
          ],
        ),
        const SizedBox(height: 28),
        Container(height: 1, color: AionTheme.veil),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _navBtn(String label, bool isActive, VoidCallback onTap) {
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

  // ── Corpo principal ───────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AionTheme.gold, strokeWidth: 1),
            SizedBox(height: 20),
            Text(
              'Buscando episódios...',
              style: TextStyle(
                color: AionTheme.silver,
                fontSize: 12,
                fontFamily: 'Georgia',
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      );
    }

    if (_episodes.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: AionTheme.gold,
      backgroundColor: AionTheme.deep,
      onRefresh: _fetchEpisodes,
      child: ListView.separated(
        itemCount: _episodes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _buildEpisodeCard(_episodes[i]),
      ),
    );
  }

  // ── Estado vazio ──────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '☽',
            style: TextStyle(
              fontSize: 56,
              color: AionTheme.veil,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Nenhum episódio ainda',
            style: TextStyle(
              fontSize: 18,
              color: AionTheme.silver,
              fontFamily: 'Georgia',
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Os episódios do canal Mito & Psique\naparecerão aqui assim que forem publicados.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AionTheme.silver,
              fontFamily: 'Georgia',
              height: 1.8,
            ),
          ),
          const SizedBox(height: 32),
          InkWell(
            onTap: _fetchEpisodes,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AionTheme.veil),
              ),
              child: const Text(
                'ATUALIZAR',
                style: TextStyle(
                  color: AionTheme.silver,
                  fontSize: 10,
                  letterSpacing: 3,
                  fontFamily: 'Georgia',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card de episódio ──────────────────────────────────────────────────
  Widget _buildEpisodeCard(Episode ep) {
    return Container(
      decoration: BoxDecoration(
        color: AionTheme.deep,
        border: Border(
          top: BorderSide(color: AionTheme.gold.withOpacity(0.5), width: 1),
          left: BorderSide(color: AionTheme.shadow),
          right: BorderSide(color: AionTheme.shadow),
          bottom: BorderSide(color: AionTheme.shadow),
        ),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Número do episódio
          Text(
            'EP. ${ep.number.toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontSize: 9,
              color: AionTheme.gold,
              letterSpacing: 4,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 10),
          // Título principal
          Text(
            ep.titleMain,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontFamily: 'Georgia',
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          // Título secundário
          Text(
            ep.titleSecondary,
            style: const TextStyle(
              fontSize: 13,
              color: AionTheme.silver,
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          if (ep.description != null && ep.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              ep.description!,
              style: const TextStyle(
                fontSize: 12,
                color: AionTheme.silver,
                fontFamily: 'Georgia',
                height: 1.6,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (ep.mythsSymbols.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: AionTheme.shadow),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ep.mythsSymbols
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: AionTheme.gold.withOpacity(0.4)),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: AionTheme.amber,
                          fontSize: 10,
                          letterSpacing: 1,
                          fontFamily: 'Georgia',
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
