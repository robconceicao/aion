import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

class CinematicBackground extends StatelessWidget {
  final Widget child;
  const CinematicBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: AionTheme.darkVoid),
        const Positioned.fill(child: _AmbientLighting()),
        const Positioned.fill(child: _StardustField()),
        const Positioned.fill(child: _FilmGrain()),
        child,
      ],
    );
  }
}

class _AmbientLighting extends StatelessWidget {
  const _AmbientLighting();
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -100, right: -100,
          child: Container(
            width: 400, height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AionTheme.gold.withOpacity(0.03), Colors.transparent]),
            ),
          ),
        ),
        Positioned(
          bottom: -150, left: -100,
          child: Container(
            width: 500, height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AionTheme.indigo.withOpacity(0.04), Colors.transparent]),
            ),
          ),
        ),
      ],
    );
  }
}

class _StardustField extends StatefulWidget {
  const _StardustField();
  @override
  State<_StardustField> createState() => _StardustFieldState();
}

class _StardustFieldState extends State<_StardustField> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Star> _stars = List.generate(45, (_) => _Star());
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 30))..repeat();
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(painter: _StardustPainter(_stars, _controller.value)),
    );
  }
}

class _Star {
  final double x = Random().nextDouble();
  final double y = Random().nextDouble();
  final double size = Random().nextDouble() * 1.5 + 0.5;
  final double speed = Random().nextDouble() * 0.02 + 0.005;
  final double drift = Random().nextDouble() * 0.04 - 0.02;
}

class _StardustPainter extends CustomPainter {
  final List<_Star> stars;
  final double progress;
  _StardustPainter(this.stars, this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AionTheme.silver.withOpacity(0.25);
    for (var star in stars) {
      final x = (star.x * size.width + (star.drift * size.width * progress)) % size.width;
      final y = (star.y * size.height - (star.speed * size.height * progress)) % size.height;
      canvas.drawCircle(Offset(x, y), star.size, paint);
      if (star.size > 1.4) {
        canvas.drawCircle(Offset(x, y), star.size * 2, Paint()..color = AionTheme.gold.withOpacity(0.08));
      }
    }
  }
  @override
  bool shouldRepaint(CustomPainter old) => true;
}

class _FilmGrain extends StatelessWidget {
  const _FilmGrain();
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.035,
        child: CustomPaint(painter: _GrainPainter()),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random();
    final paint = Paint()..color = Colors.white;
    for (var i = 0; i < 1200; i++) {
      canvas.drawRect(Rect.fromLTWH(random.nextDouble() * size.width, random.nextDouble() * size.height, 1, 1), paint);
    }
  }
  @override
  bool shouldRepaint(CustomPainter old) => false;
}
