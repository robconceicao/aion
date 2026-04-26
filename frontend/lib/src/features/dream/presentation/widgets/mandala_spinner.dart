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
          // Rotating Aion Logo
          const AionSpinLogo(size: 80),
          const SizedBox(height: 48),
          Text(
            widget.message,
            style: const TextStyle(
              fontFamily: 'CormorantGaramond',
              fontSize: 18,
              fontStyle: FontStyle.italic,
              color: AionTheme.silver,
              letterSpacing: 1.2,
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
