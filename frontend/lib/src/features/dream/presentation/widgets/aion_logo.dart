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
                color: AionTheme.gold.withOpacity(0.15 * _controller.value),
                blurRadius: 40 * _controller.value,
                spreadRadius: 10 * _controller.value,
              ),
            ],
          ),
          child: Opacity(
            opacity: 0.6 + (0.4 * _controller.value),
            child: Image.asset(
              'assets/images/logo.jpg',
              fit: BoxFit.contain,
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
      duration: const Duration(seconds: 15),
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
        // Aura estática sutil
        Container(
          width: widget.size * 0.8,
          height: widget.size * 0.8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AionTheme.gold.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
        ),
        RotationTransition(
          turns: _controller,
          child: Image.asset(
            'assets/images/logo.jpg',
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}
