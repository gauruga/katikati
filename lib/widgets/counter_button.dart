import 'package:flutter/material.dart';
import 'pressable.dart';

/// 下部のカウントボタン。押すと count が増え、
/// (mainCount + total) / count を "1/xx.x" 形式で表示する。
///
/// 誤って押してしまったときは長押しで修正パネルを開く。
/// 減算を常設ボタンにすると巨大な +1 ターゲットの隣に小さな −1 が並び、
/// かえって誤タップが増えるため、意図しないと起きない長押しに割り当てている。
class CounterButton extends StatelessWidget {
  final int count;
  final String ratioText;
  final List<Color> gradientColors;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  const CounterButton({
    super.key,
    required this.count,
    required this.ratioText,
    required this.gradientColors,
    required this.onPressed,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPressable(
      onTap: onPressed,
      onLongPress: onLongPress,
      pressedScale: 0.94,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // ボタンの大きさに合わせて文字サイズと角丸をスケールさせる
          // （個数が少なくボタンが大きいときに数字が小さく見えないように）。
          final shortest = constraints.biggest.shortestSide;
          final base = shortest.isFinite && shortest > 0 ? shortest : 100.0;
          final countFont = (base * 0.34).clamp(20.0, 90.0);
          final ratioFont = (countFont * 0.44).clamp(11.0, 34.0);
          final radius = (base * 0.2).clamp(16.0, 34.0);
          final hintSize = (base * 0.13).clamp(11.0, 20.0);
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
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
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: countFont,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          ratioText,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w600,
                            fontSize: ratioFont,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // 「長押しで修正できる」ことを示す控えめな印。
                // タップ対象ではないので、押し間違いの原因にはならない。
                if (onLongPress != null)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(
                      Icons.edit,
                      size: hintSize,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
