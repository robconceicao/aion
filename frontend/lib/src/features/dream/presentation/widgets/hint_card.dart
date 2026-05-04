import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme.dart';
import 'dream_tips.dart';

class DreamHintCard extends StatefulWidget {
  const DreamHintCard({super.key});

  @override
  State<DreamHintCard> createState() => _DreamHintCardState();
}

class _DreamHintCardState extends State<DreamHintCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  bool _visible = false;
  String _tip = '';

  static const _prefKey = 'hint_dismissed_date';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim  = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<double>(begin: -12, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _checkVisibility();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getString(_prefKey);
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (dismissed == today) return; // já foi descartado hoje

    final index = Random().nextInt(DreamTips.registry.length);
    setState(() {
      _tip = DreamTips.registry[index];
      _visible = true;
    });
    _controller.forward();
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString(_prefKey, today);
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || _tip.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: _fadeAnim.value,
        child: Transform.translate(
          offset: Offset(0, _slideAnim.value),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: AionTheme.darkAbyss,
          border: Border(
            left: BorderSide(color: AionTheme.gold.withOpacity(0.5), width: 2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícone
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 12),
                child: Text(
                  '✦',
                  style: TextStyle(
                    color: AionTheme.gold.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ),

              // Texto da dica
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DICA DE REGISTRO',
                      style: GoogleFonts.ptSerif(
                        fontSize: 8,
                        letterSpacing: 2.5,
                        color: AionTheme.gold.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _tip,
                      style: GoogleFonts.ptSerif(
                        fontSize: 13,
                        height: 1.6,
                        color: AionTheme.silver,
                      ),
                    ),
                  ],
                ),
              ),

              // Botão fechar
              GestureDetector(
                onTap: _dismiss,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 0, 0),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: AionTheme.silver.withOpacity(0.35),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
