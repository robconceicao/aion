import 'package:flutter/material.dart';

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
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_controller),
      child: Image.asset(
        'assets/images/logo.jpg',
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
      ),
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
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Image.asset(
        'assets/images/logo.jpg',
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
      ),
    );
  }
}
