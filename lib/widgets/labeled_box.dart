import 'package:flutter/material.dart';

/// 上部の「開始ゲーム数」「Total」などのラベル付きボックス。
class LabeledBox extends StatelessWidget {
  final String label;
  final Widget child;
  final List<Color> gradientColors;
  final double width;
  final double height;

  const LabeledBox({
    super.key,
    required this.label,
    required this.child,
    required this.gradientColors,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 3),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(colors: gradientColors),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.last.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(child: child),
            ),
          ),
        ],
      ),
    );
  }
}
