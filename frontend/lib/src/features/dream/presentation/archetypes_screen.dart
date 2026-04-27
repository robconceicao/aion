import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import 'record_dream_screen.dart';
import 'canal_screen.dart';

// ─── Modelo de dado do Arquétipo ───────────────────────────────────────────
class _Archetype {
  final String symbol;
  final String name;
  final Color accent;
  final String description;
  _Archetype({
    required this.symbol,
    required this.name,
    required this.accent,
    required this.description,
  });
}

// ─── Dados dos 12 Arquétipos Junguianos ────────────────────────────────────
final List<_Archetype> _archetypes = [
  _Archetype(
    symbol: '⊕',
    name: 'O Herói',
    accent: AionTheme.gold,
    description: 'A jornada da superação e da conquista do Self.',
  ),
  _Archetype(
    symbol: ')',
    name: 'A Sombra',
    accent: AionTheme.crimson,
    description: 'O lado oculto da psique — tudo que o ego recusa.',
  ),
  _Archetype(
    symbol: '△',
    name: 'A Anima',
    accent: AionTheme.rose,
    description: 'A face feminina do inconsciente masculino.',
  ),
  _Archetype(
    symbol: '✦',
    name: 'O Animus',
    accent: AionTheme.teal,
    description: 'A face masculina do inconsciente feminino.',
  ),
  _Archetype(
    symbol: '✧',
    name: 'O Velho Sábio',
    accent: AionTheme.ghost,
    description: 'O guia interior — a voz da sabedoria acumulada.',
  ),
  _Archetype(
    symbol: '⌘',
    name: 'A Grande Mãe',
    accent: AionTheme.green,
    description: 'O princípio nutridor e devorador da existência.',
  ),
  _Archetype(
    symbol: '∞',
    name: 'O Trickster',
    accent: AionTheme.indigo,
    description: 'O agente do caos criativo e da transformação.',
  ),
  _Archetype(
    symbol: '◎',
    name: 'A Persona',
    accent: AionTheme.blood,
    description: 'A máscara social que apresentamos ao mundo.',
  ),
  _Archetype(
    symbol: '○',
    name: 'O Self',
    accent: AionTheme.amber,
    description: 'O centro e a totalidade da personalidade.',
  ),
  _Archetype(
    symbol: '✿',
    name: 'O Eterno Jovem',
    accent: AionTheme.crimson,
    description: 'Puer Aeternus — a recusa à maturidade, o eterno início.',
  ),
  _Archetype(
    symbol: '⊗',
    name: 'O Inimigo',
    accent: AionTheme.blood,
    description: 'A força opositora que forja o crescimento pela resistência.',
  ),
  _Archetype(
    symbol: '⋈',
    name: 'O Guerreiro',
    accent: AionTheme.gold,
    description: 'A energia da disciplina, da luta e da proteção do sagrado.',
  ),
];

// ─── Tela: Galeria dos Arquétipos ──────────────────────────────────────────
class ArchetypesScreen extends StatefulWidget {
  const ArchetypesScreen({super.key});

  @override
  State<ArchetypesScreen> createState() => _ArchetypesScreenState();
}

class _ArchetypesScreenState extends State<ArchetypesScreen> {
  _Archetype? _selected;

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
              child: _selected != null
                  ? _buildDetail(_selected!)
                  : _buildGallery(),
            ),
          ),
        ),
      ),
    );
  }

  // ── Barra de navegação (reutilizável) ──────────────────────────────────
  Widget _buildNav({String active = 'ARQUÉTIPOS'}) {
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
                  'Galeria dos Arquétipos',
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
                _navBtn('INÍCIO', active == 'INÍCIO', () {
                  if (_selected != null) {
                    setState(() => _selected = null);
                  } else {
                    Navigator.pop(context);
                  }
                }),
                _navBtn('+ SONHO', active == '+ SONHO', () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RecordDreamScreen(),
                    ),
                  );
                }),
                _navBtn('ARQUÉTIPOS', active == 'ARQUÉTIPOS', () {
                  setState(() => _selected = null);
                }),
                _navBtn('CANAL', active == 'CANAL', () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const CanalScreen()),
                  );
                }),
              ],
            ),
          ],
        ),
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

  // ── Grade de Arquétipos ────────────────────────────────────────────────
  Widget _buildGallery() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNav(),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 500 ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  childAspectRatio: 1.8,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _archetypes.length,
                itemBuilder: (_, i) => _buildCard(_archetypes[i]),
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCard(_Archetype a) {
    return InkWell(
      onTap: () => setState(() => _selected = a),
      child: Container(
        decoration: BoxDecoration(
          color: AionTheme.deep,
          border: Border(
            top: BorderSide(color: a.accent, width: 2),
            left: BorderSide(color: AionTheme.shadow),
            right: BorderSide(color: AionTheme.shadow),
            bottom: BorderSide(color: AionTheme.shadow),
          ),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              a.symbol,
              style: TextStyle(
                fontSize: 28,
                color: a.accent,
                fontFamily: 'Georgia',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              a.name,
              style: TextStyle(
                fontSize: 15,
                color: a.accent,
                fontFamily: 'Georgia',
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Detalhe do Arquétipo ──────────────────────────────────────────────
  Widget _buildDetail(_Archetype a) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNav(),
          // Card de destaque
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AionTheme.deep,
              border: Border(
                top: BorderSide(color: a.accent, width: 3),
                left: BorderSide(color: AionTheme.shadow),
                right: BorderSide(color: AionTheme.shadow),
                bottom: BorderSide(color: AionTheme.shadow),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.symbol,
                  style: TextStyle(
                    fontSize: 48,
                    color: a.accent,
                    fontFamily: 'Georgia',
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  a.name,
                  style: TextStyle(
                    fontSize: 28,
                    color: a.accent,
                    fontFamily: 'Georgia',
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: AionTheme.veil),
                const SizedBox(height: 20),
                Text(
                  a.description,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AionTheme.ghost,
                    fontFamily: 'Georgia',
                    height: 1.8,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Botão voltar à galeria
          InkWell(
            onTap: () => setState(() => _selected = null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AionTheme.veil),
              ),
              child: const Text(
                '← VOLTAR À GALERIA',
                style: TextStyle(
                  color: AionTheme.silver,
                  fontSize: 10,
                  letterSpacing: 3,
                  fontFamily: 'Georgia',
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
