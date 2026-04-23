import 'package:flutter/material.dart';
import '../../../../core/theme.dart';

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
          RotationTransition(
            turns: _controller,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AionTheme.gold.withOpacity(0.1), width: 1),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                   // Outer ring
                  Text('⊕', style: TextStyle(fontSize: 160, color: AionTheme.gold.withOpacity(0.05))),
                  // Middle ring
                  RotationTransition(
                    turns: ReverseAnimation(_controller),
                    child: Text('⟁', style: TextStyle(fontSize: 100, color: AionTheme.gold.withOpacity(0.1))),
                  ),
                  // Center
                  Text('◯', style: TextStyle(fontSize: 40, color: AionTheme.gold)),
                ],
              ),
            ),
          ),
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
