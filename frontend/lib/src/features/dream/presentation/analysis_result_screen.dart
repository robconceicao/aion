import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/cinematic_background.dart';

// ── TOKENS ───────────────────────────────────────────────────────
const _cVoid   = Color(0xFF070810);
const _cDeep   = Color(0xFF0d0c18);
const _cAbyss  = Color(0xFF121120);
const _cShadow = Color(0xFF1a1830);
const _cVeil   = Color(0xFF252340);
const _cMist   = Color(0xFF332f58);

const _cGold   = Color(0xFFc8a84a);
const _cAmber  = Color(0xFFe8c46a);
const _cDawn   = Color(0xFFf5dfa0);
const _cSilver = Color(0xFF9898b8);
const _cGhost  = Color(0xFFcccce0);
const _cWhite  = Color(0xFFeeeef8);
const _cCrimson= Color(0xFFa83030);
const _cTeal   = Color(0xFF2a8070);

// Mito Espelho
const _cIndigoBg = Color(0x2E3A3870);
const _cIndigoBd = Color(0x8C3A3870);
const _cIndigoLabel = Color(0xFF8888c8);

// Episódios / Aviso
const _cGreenBg   = Color(0x2E2a5a3a);
const _cGreenBd   = Color(0x662a5a3a);
const _cGreenText = Color(0xFF5a9a6a);
const _cTealBg    = Color(0x2E2a8070);
const _cTealBd    = Color(0x662a8070);
const _cTealText  = Color(0xFF88c0c8);

class AnalysisResultScreen extends StatelessWidget {
  final Map<String, dynamic> analysis;
  final String? dreamText;

  const AnalysisResultScreen({super.key, required this.analysis, this.dreamText});

  Color _arcColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('mãe'))    return const Color(0xFF5a8a5a);
    if (n.contains('self'))   return _cAmber;
    if (n.contains('herói') || n.contains('heroi')) return _cGold;
    if (n.contains('sombra')) return _cCrimson;
    if (n.contains('anima') && !n.contains('animus')) return const Color(0xFF9b6b9b);
    if (n.contains('animus')) return const Color(0xFF5a7a9b);
    if (n.contains('sábio') || n.contains('sabio')) return _cSilver;
    if (n.contains('trickster')) return _cTeal;
    if (n.contains('persona'))   return const Color(0xFF7a7a9b);
    if (n.contains('jovem'))     return const Color(0xFFc87870);
    if (n.contains('inimigo'))   return const Color(0xFF8b4040);
    if (n.contains('guerreiro')) return const Color(0xFFa87040);
    return _cSilver;
  }

  // Índice da fase da jornada (0-11)
  static const _fases = [
    'o mundo comum','o chamado da aventura','a recusa do chamado',
    'o encontro com o mentor','a travessia do primeiro limiar',
    'testes, aliados e inimigos','a aproximação da caverna oculta',
    'a provação suprema','a recompensa','o caminho de volta',
    'a ressurreição','o retorno com o elixir',
  ];

  @override
  Widget build(BuildContext context) {
    final arquetipos = (analysis['arquetipos'] as List? ?? []);
    final simbolos   = (analysis['simbolos_chave'] as List? ?? []);
    final dream      = dreamText ?? 'Sonho registrado.';

    return CinematicBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _cGold),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('MITO & PSIQUE', style: GoogleFonts.cormorantGaramond(fontSize: 10, color: _cSilver, letterSpacing: 3)),
            Text('AION', style: GoogleFonts.cormorantGaramond(fontSize: 15, color: _cGold, letterSpacing: 6, fontWeight: FontWeight.bold)),
            Text('O Diário do Sonho', style: GoogleFonts.cormorantGaramond(fontSize: 10, color: _cSilver, letterSpacing: 2, fontStyle: FontStyle.italic)),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _cGold.withOpacity(0.2)),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 36, 20, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ① AVISO ÉTICO
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: _cTealBg,
                    border: Border.all(color: _cTealBd),
                  ),
                  child: const Text(
                    '⚠ Esta análise é uma reflexão simbólica baseada em Jung e Campbell — não substitui acompanhamento psicológico profissional.',
                    style: TextStyle(color: _cTealText, fontSize: 12, height: 1.7),
                  ),
                ),
                const SizedBox(height: 14),

                // ② O SONHO
                _Card(
                  leftBorder: BorderSide(color: _cVeil, width: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('O SONHO', color: _cSilver),
                      Text('"$dream"',
                        style: const TextStyle(color: _cGhost, fontSize: 14, fontStyle: FontStyle.italic, height: 1.85)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ③ ESSÊNCIA
                _Card(
                  padding: const EdgeInsets.all(24),
                  leftBorder: const BorderSide(color: _cGold, width: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('☽  ESSÊNCIA', color: _cGold),
                      Text('"${analysis['essencia'] ?? ''}"',
                        style: const TextStyle(color: _cDawn, fontSize: 17, fontStyle: FontStyle.italic, height: 2.0)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ④ DIMENSÕES
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('DIMENSÕES DO SONHO', color: _cSilver),
                      const SizedBox(height: 4),
                      LayoutBuilder(builder: (ctx, c) {
                        final narrow = c.maxWidth < 400;
                        return narrow
                          ? Column(children: [
                              _DimBar('Sombra',       analysis['intensidade_sombra'] ?? 0,        _cCrimson, grad: [_cCrimson, const Color(0x88c03030)]),
                              const SizedBox(height: 12),
                              _DimBar('Herói',        analysis['intensidade_heroi'] ?? 0,          _cGold,   grad: [_cGold, _cAmber]),
                              const SizedBox(height: 12),
                              _DimBar('Transformação',analysis['intensidade_transformacao'] ?? 0,  _cTeal,   grad: [_cTeal, const Color(0x882a8070)]),
                            ])
                          : Row(children: [
                              Expanded(child: _DimBar('Sombra',       analysis['intensidade_sombra'] ?? 0,        _cCrimson, grad: [_cCrimson, const Color(0x88c03030)])),
                              const SizedBox(width: 14),
                              Expanded(child: _DimBar('Herói',        analysis['intensidade_heroi'] ?? 0,          _cGold,   grad: [_cGold, _cAmber])),
                              const SizedBox(width: 14),
                              Expanded(child: _DimBar('Transformação',analysis['intensidade_transformacao'] ?? 0,  _cTeal,   grad: [_cTeal, const Color(0x882a8070)])),
                            ]);
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ⑤ ARQUÉTIPOS
                if (arquetipos.isNotEmpty) ...[
                  _Label('⟁  ARQUÉTIPOS PRESENTES', color: _cGold),
                  const SizedBox(height: 12),
                  LayoutBuilder(builder: (ctx, c) {
                    final wide = c.maxWidth > 460;
                    Widget arcCard(dynamic arc) {
                      final cor = _arcColor(arc['nome'] ?? '');
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _cAbyss,
                          border: Border(
                            top:    BorderSide(color: cor, width: 3),
                            bottom: const BorderSide(color: _cShadow),
                            left:   const BorderSide(color: _cShadow),
                            right:  const BorderSide(color: _cShadow),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(arc['simbolo'] ?? '⌘', style: const TextStyle(fontSize: 22)),
                            const SizedBox(height: 8),
                            Text(arc['nome'] ?? '', style: TextStyle(color: cor, fontSize: 13, letterSpacing: 1)),
                            const SizedBox(height: 8),
                            Text(arc['descricao'] ?? '',
                              style: const TextStyle(color: _cSilver, fontSize: 12, height: 1.7)),
                          ],
                        ),
                      );
                    }
                    if (wide && arquetipos.length >= 2) {
                      final rows = <Widget>[];
                      for (int i = 0; i < arquetipos.length; i += 2) {
                        final hasNext = i + 1 < arquetipos.length;
                        rows.add(Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: arcCard(arquetipos[i])),
                            if (hasNext) const SizedBox(width: 12),
                            if (hasNext) Expanded(child: arcCard(arquetipos[i + 1]))
                            else const Spacer(),
                          ],
                        ));
                        if (i + 2 < arquetipos.length) rows.add(const SizedBox(height: 12));
                      }
                      return Column(children: rows);
                    }
                    return Column(
                      children: arquetipos.asMap().entries.map((e) => Padding(
                        padding: EdgeInsets.only(bottom: e.key < arquetipos.length - 1 ? 12 : 0),
                        child: arcCard(e.value),
                      )).toList(),
                    );
                  }),
                  const SizedBox(height: 14),
                ],

                // ⑥ FUNÇÃO COMPENSATÓRIA + PROSPECÇÃO
                LayoutBuilder(builder: (ctx, c) {
                  final wide = c.maxWidth > 500;
                  final cardComp = _Card(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _Label('⊗  FUNÇÃO COMPENSATÓRIA', color: _cAmber),
                      Text(analysis['funcao_compensatoria'] ?? '',
                        style: const TextStyle(color: _cGhost, fontSize: 13, height: 1.8)),
                    ]),
                  );
                  final cardProsp = _Card(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _Label('✦  PROSPECÇÃO', color: _cSilver),
                      Text(analysis['prospeccao'] ?? '',
                        style: const TextStyle(color: _cGhost, fontSize: 13, height: 1.8)),
                    ]),
                  );
                  if (wide) {
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: cardComp),
                      const SizedBox(width: 14),
                      Expanded(child: cardProsp),
                    ]);
                  }
                  return Column(children: [cardComp, const SizedBox(height: 14), cardProsp]);
                }),
                const SizedBox(height: 14),

                // ⑦ SÍMBOLOS & AMPLIAÇÃO
                if (simbolos.isNotEmpty)
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('⋈  SÍMBOLOS & AMPLIAÇÃO', color: _cGold),
                        ...List.generate(simbolos.length, (i) {
                          final s = simbolos[i];
                          final isLast = i == simbolos.length - 1;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 120,
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 14, top: 2),
                                        child: Text(s['elemento'] ?? '',
                                          style: const TextStyle(color: _cAmber, fontSize: 12)),
                                      ),
                                    ),
                                    Container(width: 1, height: 40, color: _cVeil),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(s['significado'] ?? '',
                                        style: const TextStyle(color: _cSilver, fontSize: 12, height: 1.7)),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isLast) ...[
                                const SizedBox(height: 12),
                                Container(height: 1, color: _cShadow),
                                const SizedBox(height: 12),
                              ],
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),

                // ⑧ JORNADA DO HERÓI
                if (analysis['fase_jornada'] != null) ...[
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('⊕  JORNADA DO HERÓI — CAMPBELL', color: _cGold),
                        Text(analysis['fase_jornada']['nome'] ?? '',
                          style: const TextStyle(color: _cAmber, fontSize: 15)),
                        const SizedBox(height: 8),
                        _journeyBar(analysis['fase_jornada']['nome'] ?? ''),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('O Mundo Comum', style: TextStyle(color: _cMist, fontSize: 10)),
                            Text('O Retorno com o Elixir', style: TextStyle(color: _cMist, fontSize: 10)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(analysis['fase_jornada']['descricao'] ?? '',
                          style: const TextStyle(color: _cSilver, fontSize: 13, height: 1.8)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ⑨ MITO ESPELHO
                if (analysis['mito_espelho'] != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _cIndigoBg,
                      border: Border.all(color: _cIndigoBd),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('☽  MITO ESPELHO', color: _cIndigoLabel),
                        Text(analysis['mito_espelho']['titulo'] ?? '',
                          style: const TextStyle(color: _cGhost, fontSize: 14)),
                        const SizedBox(height: 10),
                        Text(analysis['mito_espelho']['paralelo'] ?? '',
                          style: const TextStyle(color: _cSilver, fontSize: 13, height: 1.8)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ⑩ PERGUNTA PARA REFLEXÃO
                if (analysis['pergunta_para_reflexao'] != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                    decoration: BoxDecoration(
                      color: _cDeep,
                      border: Border.all(color: _cGold.withOpacity(0.28)),
                    ),
                    child: Column(
                      children: [
                        _Label('PERGUNTA PARA REFLEXÃO', color: _cGold, centered: true),
                        const SizedBox(height: 4),
                        Text('"${analysis['pergunta_para_reflexao']}"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _cDawn, fontSize: 18, fontStyle: FontStyle.italic, height: 1.9)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ⑪ EPISÓDIOS RECOMENDADOS
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _cGreenBg,
                    border: Border.all(color: _cGreenBd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('▶  EPISÓDIOS RECOMENDADOS — MITO & PSIQUE', color: _cGreenText),
                      const Text('Baseado nos arquétipos identificados neste sonho:',
                        style: TextStyle(color: _cMist, fontSize: 12)),
                      const SizedBox(height: 16),
                      _EpisodeCard(num: 'EP07', color: const Color(0xFF5a8a5a),
                        title: 'A Grande Deusa',
                        sub: 'Magna Mater — o arquétipo que as civilizações temeram e veneraram'),
                      const SizedBox(height: 8),
                      _EpisodeCard(num: 'EP08', color: _cDawn,
                        title: 'O Retorno do Herói',
                        sub: 'A individuação — tornar-se quem você sempre foi'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Botões
                Wrap(
                  spacing: 10, runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _cGold, foregroundColor: _cVoid,
                        shape: const RoundedRectangleBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: const Text('+ Novo Sonho'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent, foregroundColor: _cSilver,
                        side: const BorderSide(color: _cVeil),
                        shape: const RoundedRectangleBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: const Text('Início'),
                    ),
                  ],
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _journeyBar(String nomeFase) {
    final idx = _fases.indexWhere((f) => nomeFase.toLowerCase().contains(f.split(' ').first.toLowerCase()));
    final phase = idx >= 0 ? idx : 0;
    final width = (phase + 1) / 12.0;
    return Container(
      height: 4, color: _cShadow,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: width,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_cGold, _cAmber]),
          ),
        ),
      ),
    );
  }
}

// ── WIDGET: Label ────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  final Color color;
  final bool centered;
  const _Label(this.text, {required this.color, this.centered = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          color: color,
          fontSize: 9,
          letterSpacing: 5,
          fontFamily: 'Georgia',
        ),
      ),
    );
  }
}

// ── WIDGET: Card angular ─────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderSide? leftBorder;
  const _Card({required this.child, this.padding, this.leftBorder});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121120),
        border: Border(
          top:    const BorderSide(color: Color(0xFF1a1830)),
          bottom: const BorderSide(color: Color(0xFF1a1830)),
          right:  const BorderSide(color: Color(0xFF1a1830)),
          left:   leftBorder ?? const BorderSide(color: Color(0xFF1a1830)),
        ),
      ),
      child: child,
    );
  }
}

// ── WIDGET: Barra de dimensão com gradiente ──────────────────────
class _DimBar extends StatelessWidget {
  final String label;
  final dynamic valueDyn;
  final Color color;
  final List<Color> grad;
  const _DimBar(this.label, this.valueDyn, this.color, {required this.grad});

  @override
  Widget build(BuildContext context) {
    double v = 0;
    if (valueDyn is num)    v = (valueDyn as num).toDouble();
    if (valueDyn is String) v = double.tryParse(valueDyn) ?? 0;
    final pct = (v > 1 ? v / 10.0 : v).clamp(0.0, 1.0);
    final display = '${(v > 1 ? v : v * 10).round()}/10';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Color(0xFF9898b8), fontSize: 12)),
        Text(display, style: TextStyle(color: color, fontSize: 12)),
      ]),
      const SizedBox(height: 5),
      Container(
        height: 4, color: const Color(0xFF1a1830),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: pct,
          child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: grad))),
        ),
      ),
    ]);
  }
}

// ── WIDGET: Episódio ─────────────────────────────────────────────
class _EpisodeCard extends StatelessWidget {
  final String num, title, sub;
  final Color color;
  const _EpisodeCard({required this.num, required this.color, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121120),
        border: Border(
          top:    const BorderSide(color: Color(0xFF1a1830)),
          bottom: const BorderSide(color: Color(0xFF1a1830)),
          right:  const BorderSide(color: Color(0xFF1a1830)),
          left:   BorderSide(color: color, width: 3),
        ),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 42,
          child: Text(num, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w300, letterSpacing: 1)),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Color(0xFFf5dfa0), fontSize: 13)),
          const SizedBox(height: 3),
          Text(sub,   style: const TextStyle(color: Color(0xFF9898b8), fontSize: 11)),
        ])),
      ]),
    );
  }
}
