import 'package:flutter/material.dart';
import 'pressable.dart';

/// 下部のカウントボタン。押すと count が増え、
/// (mainCount + total) / count を "1/xx.x" 形式で表示する。
///
/// 誤って押してしまったときは長押しで修正パネルを開く。
/// 減算を常設ボタンにすると巨大な +1 ターゲットの隣に小さな −1 が並び、
/// かえって誤タップが増えるため、意図しないと起きない長押しに割り当てている。
/// （長押しできることは、初回カウント時のヒント表示だけで伝える）
class CounterButton extends StatefulWidget {
  final int count;
  final String ratioText;

  /// 付けた名前。未設定なら null で、そのときはラベルを出さない。
  final String? label;
  final List<Color> gradientColors;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  const CounterButton({
    super.key,
    required this.count,
    required this.ratioText,
    this.label,
    required this.gradientColors,
    required this.onPressed,
    this.onLongPress,
  });

  @override
  State<CounterButton> createState() => _CounterButtonState();
}

class _CounterButtonState extends State<CounterButton>
    with SingleTickerProviderStateMixin {
  /// 数字が光ってから元に戻るまで。押した実感を出すためだけの演出なので短く。
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1, // 起動直後に光らないよう、最初から終了状態にしておく
  );

  @override
  void didUpdateWidget(CounterButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count != oldWidget.count) _pulse.forward(from: 0);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPressable(
      onTap: widget.onPressed,
      onLongPress: widget.onLongPress,
      pressedScale: 0.94,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // ボタンの大きさに合わせて文字サイズと角丸をスケールさせる
          // （個数が少なくボタンが大きいときに数字が小さく見えないように）。
          final shortest = constraints.biggest.shortestSide;
          final base = shortest.isFinite && shortest > 0 ? shortest : 100.0;
          final countFont = (base * 0.34).clamp(20.0, 90.0);
          final ratioFont = (countFont * 0.44).clamp(11.0, 34.0);
          final labelFont = (countFont * 0.34).clamp(10.0, 24.0);
          final radius = (base * 0.2).clamp(16.0, 34.0);
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.gradientColors,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.gradientColors.last.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.label != null)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.label!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w700,
                          fontSize: labelFont,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                if (widget.label != null) const SizedBox(height: 2),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) {
                        // 押した瞬間が一番強く、そこから減衰する
                        final glow = 1 - Curves.easeOut.transform(_pulse.value);
                        return Transform.scale(
                          scale: 1 + 0.08 * glow,
                          child: Text(
                            '${widget.count}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: countFont,
                              height: 1.0,
                              shadows: glow <= 0.01
                                  ? null
                                  : [
                                      Shadow(
                                        color: Colors.white.withValues(
                                          alpha: 0.9 * glow,
                                        ),
                                        blurRadius: 14 * glow,
                                      ),
                                      Shadow(
                                        color: Colors.white.withValues(
                                          alpha: 0.5 * glow,
                                        ),
                                        blurRadius: 32 * glow,
                                      ),
                                    ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.ratioText,
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
          );
        },
      ),
    );
  }
}
