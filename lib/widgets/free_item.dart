import 'package:flutter/material.dart';
import '../layout_positions.dart';

/// 自由配置モードでドラッグ移動＆リサイズ可能な要素をラップする。
class FreeItem extends StatelessWidget {
  final Offset fraction; // 0..1 の相対座標
  final double scale; // アイテムのサイズ倍率
  final Size canvasSize;
  final Size baseItemSize;
  final bool editing;
  final Widget child;
  final ValueChanged<Offset> onDragUpdate;
  final ValueChanged<double> onScaleUpdate;
  final VoidCallback? onInteractionEnd;
  final bool colorEditable;
  final VoidCallback? onColorTap;
  final bool deletable;
  final VoidCallback? onDelete;
  final VoidCallback? onDoubleTap;

  const FreeItem({
    super.key,
    required this.fraction,
    required this.scale,
    required this.canvasSize,
    required this.baseItemSize,
    required this.editing,
    required this.child,
    required this.onDragUpdate,
    required this.onScaleUpdate,
    this.onInteractionEnd,
    this.colorEditable = false,
    this.onColorTap,
    this.deletable = false,
    this.onDelete,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final itemSize = Size(
      baseItemSize.width * scale,
      baseItemSize.height * scale,
    );
    final pos = clampedPixelPosition(fraction, canvasSize, itemSize);
    final left = pos.dx;
    final top = pos.dy;
    final maxLeft =
        (canvasSize.width - itemSize.width).clamp(0.0, double.infinity);
    final maxTop =
        (canvasSize.height - itemSize.height).clamp(0.0, double.infinity);

    Widget scaledChild = Transform.scale(
      scale: scale,
      alignment: Alignment.center,
      child: SizedBox(
        width: baseItemSize.width,
        height: baseItemSize.height,
        child: IgnorePointer(ignoring: editing, child: child),
      ),
    );

    Widget content = SizedBox(
      width: itemSize.width,
      height: itemSize.height,
      child: Center(child: scaledChild),
    );

    if (editing) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: onDoubleTap,
        onPanUpdate: (details) {
          final newLeft = (left + details.delta.dx).clamp(0.0, maxLeft);
          final newTop = (top + details.delta.dy).clamp(0.0, maxTop);
          final safeW = canvasSize.width == 0 ? 1.0 : canvasSize.width;
          final safeH = canvasSize.height == 0 ? 1.0 : canvasSize.height;
          onDragUpdate(Offset(newLeft / safeW, newTop / safeH));
        },
        onPanEnd: (_) => onInteractionEnd?.call(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF448AFF), width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: content,
            ),
            // リサイズハンドル（右下）
            Positioned(
              right: -10,
              bottom: -10,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  final delta =
                      (details.delta.dx + details.delta.dy) / 2 / 60;
                  final newScale =
                      (scale + delta).clamp(kMinScale, kMaxScale);
                  onScaleUpdate(newScale);
                },
                onPanEnd: (_) => onInteractionEnd?.call(),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFF448AFF),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4),
                    ],
                  ),
                  child: const Icon(
                    Icons.open_in_full,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
            // カラー編集アイコン（左上）
            if (colorEditable)
              Positioned(
                left: -10,
                top: -10,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onColorTap,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7043),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: const Icon(
                      Icons.palette,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
            // 削除ボタン（右上）
            if (deletable)
              Positioned(
                right: -10,
                top: -10,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDelete,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Positioned(
      left: left,
      top: top,
      child: content,
    );
  }
}
