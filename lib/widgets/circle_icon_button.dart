import 'package:flutter/material.dart';
import 'pressable.dart';

class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final VoidCallback? onPressed;
  final double size;

  const CircleIconButton({
    super.key,
    required this.icon,
    required this.colors,
    required this.onPressed,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final grad = colors.length > 1 ? colors : [colors.first, colors.first];
    return AnimatedPressable(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: grad),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: grad.last.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.52),
      ),
    );
  }
}
