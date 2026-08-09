import 'package:flutter/material.dart';
import 'pressable.dart';

/// 上部の +1/+10/+100 や -1/-10/-100 の縦並びボタン。
class AdjustButton extends StatelessWidget {
  final String label;
  final List<Color> colors;
  final VoidCallback onPressed;

  const AdjustButton({
    super.key,
    required this.label,
    required this.colors,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final grad = colors.length > 1 ? colors : [colors.first, colors.first];
    return AnimatedPressable(
      onTap: onPressed,
      child: Container(
        width: 64,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: grad),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: grad.last.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
