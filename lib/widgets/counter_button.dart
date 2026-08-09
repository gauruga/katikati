import 'package:flutter/material.dart';
import 'pressable.dart';

/// 下部のカウントボタン。押すと count が増え、
/// (mainCount + total) / count を "1/xx.x" 形式で表示する。
class CounterButton extends StatelessWidget {
  final int count;
  final String ratioText;
  final List<Color> gradientColors;
  final VoidCallback onPressed;

  const CounterButton({
    super.key,
    required this.count,
    required this.ratioText,
    required this.gradientColors,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPressable(
      onTap: onPressed,
      pressedScale: 0.94,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 34,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                ratioText,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
