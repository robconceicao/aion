import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import 'dream_tips.dart';

class LoadingTip extends StatefulWidget {
  const LoadingTip({super.key});

  @override
  State<LoadingTip> createState() => _LoadingTipState();
}

class _LoadingTipState extends State<LoadingTip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  Timer? _timer;
  String _currentTip = '';
  final _rng = Random();
  final List<int> _usedIndices = [];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _showNextTip();

    // Rotaciona a cada 3.5s
    _timer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      _showNextTip();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _showNextTip() async {
    // Garante que não repete até esgotar todas as dicas
    if (_usedIndices.length >= DreamTips.loading.length) {
      _usedIndices.clear();
    }

    int index;
    do {
      index = _rng.nextInt(DreamTips.loading.length);
    } while (_usedIndices.contains(index));
    _usedIndices.add(index);

    if (_currentTip.isNotEmpty) {
      // Fade out
      await _controller.reverse();
    }

    if (!mounted) return;
    setState(() => _currentTip = DreamTips.loading[index]);

    // Fade in
    await _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentTip.isEmpty) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
        decoration: BoxDecoration(
          color: AionTheme.darkAbyss.withOpacity(0.6),
          border: Border(
            left: BorderSide(color: AionTheme.gold.withOpacity(0.45), width: 1),
            right: BorderSide(color: AionTheme.gold.withOpacity(0.45), width: 1),
          ),
        ),
        child: Column(
          children: [
            // Divisor decorativo
            Row(children: [
              Expanded(child: Container(
                height: 1,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [
                  Colors.transparent,
                  AionTheme.gold.withOpacity(0.5),
                ])),
              )),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('✦',
                    style: TextStyle(
                      color: AionTheme.gold.withOpacity(0.7),
                      fontSize: 9,
                    )),
              ),
              Expanded(child: Container(
                height: 1,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [
                  AionTheme.gold.withOpacity(0.5),
                  Colors.transparent,
                ])),
              )),
            ]),
            const SizedBox(height: 14),

            // Texto da dica
            Text(
              _currentTip,
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 15,
                height: 1.65,
                fontStyle: FontStyle.italic,
                color: AionTheme.silver.withOpacity(0.85),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
