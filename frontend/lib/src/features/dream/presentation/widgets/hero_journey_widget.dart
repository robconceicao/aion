import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';

class HeroJourneyMapper {
  static const Map<String, double> _stages = {
    'O Mundo Comum':              0.05,
    'O Chamado':                  0.15,
    'A Recusa do Chamado':        0.22,
    'O Encontro com o Mentor':    0.30,
    'A Travessia do Limiar':      0.42,
    'Provas e Aliados':           0.55,
    'O Abismo':                   0.65,
    'A Recompensa':               0.75,
    'O Caminho de Volta':         0.84,
    'A Ressurreição':             0.92,
    'O Retorno':                  1.0,
  };

  static double getProgress(String name) {
    for (final entry in _stages.entries) {
      if (name.toLowerCase().contains(
              entry.key.split(' ').last.toLowerCase())) {
        return entry.value;
      }
    }
    return 0.05;
  }

  static Color getColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('comum') || n.contains('mundo')) return const Color(0xFF4A6FA5);
    if (n.contains('chamado') || n.contains('mentor') || n.contains('recusa')) return const Color(0xFFC8A84A);
    if (n.contains('limiar') || n.contains('provas') || n.contains('aliados')) return const Color(0xFF6B3FA0);
    if (n.contains('abismo') || n.contains('recompensa')) return const Color(0xFF9B2C2C);
    if (n.contains('retorno') || n.contains('ressurrei') || n.contains('volta')) return const Color(0xFF2A8070);
    return const Color(0xFF4A6FA5);
  }

  static String getMacroStage(String name) {
    final n = name.toLowerCase();
    if (n.contains('comum') || n.contains('chamado') || n.contains('recusa') || n.contains('mentor')) return 'PARTIDA';
    if (n.contains('limiar') || n.contains('provas') || n.contains('abismo') || n.contains('recompensa')) return 'INICIAÇÃO';
    if (n.contains('retorno') || n.contains('volta') || n.contains('ressurrei')) return 'RETORNO';
    return 'PARTIDA';
  }
}

class HeroJourneyWidget extends StatefulWidget {
  final String stageName;
  final String stageDescription;

  const HeroJourneyWidget({
    super.key,
    required this.stageName,
    required this.stageDescription,
  });

  @override
  State<HeroJourneyWidget> createState() => _HeroJourneyWidgetState();
}

class _HeroJourneyWidgetState extends State<HeroJourneyWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _progressAnim = Tween<double>(
      begin: 0,
      end: HeroJourneyMapper.getProgress(widget.stageName),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = HeroJourneyMapper.getColor(widget.stageName);
    final macro = HeroJourneyMapper.getMacroStage(widget.stageName);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AionTheme.darkAbyss,
        border: Border.all(color: AionTheme.shadow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(children: [
              Text('⊕', style: TextStyle(color: color, fontSize: 14)),
              const SizedBox(width: 8),
              Text('JORNADA DO HERÓI — CAMPBELL',
                  style: GoogleFonts.ptSerif(
                      fontSize: 9, letterSpacing: 3, color: color)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Text(
              widget.stageName,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22, color: AionTheme.ghost,
                fontWeight: FontWeight.w400, fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AnimatedBuilder(
              animation: _progressAnim,
              builder: (context, _) => Column(children: [
                // Barra de progresso animada
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: _progressAnim.value,
                    backgroundColor: AionTheme.shadow,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 12),
                // Labels macro-estágios
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _macroLabel('PARTIDA',   macro == 'PARTIDA',   const Color(0xFF4A6FA5)),
                    _macroLabel('INICIAÇÃO', macro == 'INICIAÇÃO', const Color(0xFF6B3FA0)),
                    _macroLabel('RETORNO',   macro == 'RETORNO',   const Color(0xFF2A8070)),
                  ],
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Text(
              widget.stageDescription,
              style: GoogleFonts.ptSerif(
                  fontSize: 13, height: 1.7, color: AionTheme.silver),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroLabel(String label, bool active, Color color) {
    return Column(children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          color: active ? color : color.withOpacity(0.2),
          shape: BoxShape.circle,
          boxShadow: active
              ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 1)]
              : null,
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(
        fontSize: 8, letterSpacing: 1.5,
        color: active ? color : color.withOpacity(0.3),
        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
      )),
    ]);
  }
}
