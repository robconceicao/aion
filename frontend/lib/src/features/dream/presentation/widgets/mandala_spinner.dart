import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import 'aion_logo.dart';

class MandalaSpinner extends StatefulWidget {
  final String message;
  const MandalaSpinner({super.key, this.message = 'Sintonizando com o inconsciente...'});

  @override
  State<MandalaSpinner> createState() => _MandalaSpinnerState();
}

class _MandalaSpinnerState extends State<MandalaSpinner> with SingleTickerProviderStateMixin {
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Anel de pulso externo
              ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.15).animate(_controller),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 0.35, end: 0.0).animate(_controller),
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AionTheme.gold.withOpacity(0.25), width: 1.5),
                    ),
                  ),
                ),
              ),
              // Mandala girando
              const AionSpinLogo(size: 280.0),
            ],
          ),
          const SizedBox(height: 40),
          Text(
            widget.message.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              letterSpacing: 3,
              fontWeight: FontWeight.w300,
              height: 1.9,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) => _buildDot(index)),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AionTheme.gold,
      ),
    );
  }
}
