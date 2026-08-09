import 'package:flutter/material.dart';

/// ジャグラーのGOGOランプ風の光るランプボタン。
/// タップすると数回フラッシュ(点滅)してから onPressed を呼び出す。
class GogoLampButton extends StatefulWidget {
  final VoidCallback onPressed;
  final double size;

  const GogoLampButton({
    super.key,
    required this.onPressed,
    this.size = 64,
  });

  @override
  State<GogoLampButton> createState() => _GogoLampButtonState();
}

class _GogoLampButtonState extends State<GogoLampButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isFlashing = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _flash() async {
    if (_isFlashing) return;
    _isFlashing = true;
    for (int i = 0; i < 4; i++) {
      await _controller.forward();
      if (!mounted) return;
      await _controller.reverse();
      if (!mounted) return;
    }
    _isFlashing = false;
  }

  void _handleTap() {
    _flash();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            final glow = Color.lerp(
              const Color(0xFFFF6D00),
              const Color(0xFFFFF59D),
              t,
            )!;
            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [glow, const Color(0xFFD84315)],
                  stops: const [0.2, 1.0],
                ),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: glow.withValues(alpha: 0.75),
                    blurRadius: 10 + t * 14,
                    spreadRadius: 1 + t * 5,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: widget.size * 0.32,
                  height: widget.size * 0.32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.85 + t * 0.15),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
