import 'package:flutter/material.dart';
import '../../../../core/theme.dart';

class AionPulseLogo extends StatefulWidget {
  final double size;
  const AionPulseLogo({super.key, this.size = 180});

  @override
  State<AionPulseLogo> createState() => _AionPulseLogoState();
}

class _AionPulseLogoState extends State<AionPulseLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AionTheme.gold.withOpacity(0.12 * _controller.value),
                blurRadius: 45 * _controller.value,
                spreadRadius: 8 * _controller.value,
              ),
            ],
          ),
          child: Opacity(
            opacity: 0.65 + (0.35 * _controller.value),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              color: Colors.white.withOpacity(0.9),
              colorBlendMode: BlendMode.modulate,
            ),
          ),
        );
      },
    );
  }
}

class AionSpinLogo extends StatefulWidget {
  final double size;
  const AionSpinLogo({super.key, this.size = 80});

  @override
  State<AionSpinLogo> createState() => _AionSpinLogoState();
}

class _AionSpinLogoState extends State<AionSpinLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: widget.size * 0.85,
          height: widget.size * 0.85,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AionTheme.gold.withOpacity(0.15),
                blurRadius: 35,
                spreadRadius: 4,
              ),
            ],
          ),
        ),
        RotationTransition(
          turns: _controller,
          child: Image.asset(
            'assets/images/logo.png',
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
            color: Colors.white.withOpacity(0.9),
            colorBlendMode: BlendMode.modulate,
          ),
        ),
      ],
    );
  }
}
