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
              // Rotating Aion Logo
              const AionSpinLogo(size: 96.0),
              // Pinging border effect
              ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.2).animate(_controller),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 0.5, end: 0.0).animate(_controller),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AionTheme.gold.withOpacity(0.2), width: 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          const Text(
            'TECENDO\nSÍMBOLOS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
              letterSpacing: 4,
              fontWeight: FontWeight.w300,
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
