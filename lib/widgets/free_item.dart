import 'package:flutter/material.dart';
import '../layout_positions.dart';

/// 自由配置モードでドラッグ移動＆リサイズ可能な要素をラップする。
/// リサイズは「横だけ」「縦だけ」「縦横そろえて」の3つのハンドルで行う。
class FreeItem extends StatelessWidget {
  final Offset fraction; // 0..1 の相対座標
  final ItemScale scale; // アイテムの縦横それぞれの倍率
  final Size canvasSize;
  final Size baseItemSize;
  final bool editing;
  // true の場合、中身を引き伸ばさずに指定サイズで描き直す
  final bool stretchToSize;
  final Widget child;
  final ValueChanged<Offset> onDragUpdate;
  final ValueChanged<ItemScale> onScaleUpdate;
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
    this.stretchToSize = false,
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
      baseItemSize.width * scale.x,
      baseItemSize.height * scale.y,
    );
    final pos = clampedPixelPosition(fraction, canvasSize, itemSize);
    final left = pos.dx;
    final top = pos.dy;
    final maxLeft = (canvasSize.width - itemSize.width).clamp(
      0.0,
      double.infinity,
    );
    final maxTop = (canvasSize.height - itemSize.height).clamp(
      0.0,
      double.infinity,
    );

    final inner = IgnorePointer(ignoring: editing, child: child);

    Widget content = SizedBox(
      width: itemSize.width,
      height: itemSize.height,
      // 引き伸ばし対象は与えられたサイズいっぱいに描き直し、
      // それ以外は元の大きさのまま拡大縮小する。
      child: stretchToSize
          ? inner
          : Center(
              child: Transform.scale(
                scaleX: scale.x,
                scaleY: scale.y,
                alignment: Alignment.center,
                child: SizedBox(
                  width: baseItemSize.width,
                  height: baseItemSize.height,
                  child: inner,
                ),
              ),
            ),
    );

    if (editing) {
      // ハンドルが枠の外にはみ出してもタップできるよう、周囲に余白を確保する。
      const m = 14.0;
      final boxW = itemSize.width + 4; // 枠線ぶん
      final boxH = itemSize.height + 4;
      content = SizedBox(
        width: boxW + m * 2,
        height: boxH + m * 2,
        child: Stack(
          children: [
            Positioned(
              left: m,
              top: m,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: onDoubleTap,
                onPanUpdate: (details) {
                  final newLeft = (left + details.delta.dx).clamp(0.0, maxLeft);
                  final newTop = (top + details.delta.dy).clamp(0.0, maxTop);
                  final safeW = canvasSize.width == 0 ? 1.0 : canvasSize.width;
                  final safeH = canvasSize.height == 0
                      ? 1.0
                      : canvasSize.height;
                  onDragUpdate(Offset(newLeft / safeW, newTop / safeH));
                },
                onPanEnd: (_) => onInteractionEnd?.call(),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF448AFF),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: content,
                ),
              ),
            ),
            // 横幅のリサイズハンドル（右辺中央）
            Positioned(
              left: m + boxW - 11,
              top: m + boxH / 2 - 11,
              child: _resizeHandle(
                icon: Icons.swap_horiz,
                color: const Color(0xFF448AFF),
                onPanUpdate: (details) {
                  final sx = (scale.x + details.delta.dx / baseItemSize.width)
                      .clamp(kMinScale, kMaxScale);
                  onScaleUpdate(scale.copyWith(x: sx));
                },
              ),
            ),
            // 高さのリサイズハンドル（下辺中央）
            Positioned(
              left: m + boxW / 2 - 11,
              top: m + boxH - 11,
              child: _resizeHandle(
                icon: Icons.swap_vert,
                color: const Color(0xFF448AFF),
                onPanUpdate: (details) {
                  final sy = (scale.y + details.delta.dy / baseItemSize.height)
                      .clamp(kMinScale, kMaxScale);
                  onScaleUpdate(scale.copyWith(y: sy));
                },
              ),
            ),
            // 縦横そろえてリサイズ（右下）
            Positioned(
              left: m + boxW - 13,
              top: m + boxH - 13,
              child: _resizeHandle(
                icon: Icons.open_in_full,
                color: const Color(0xFF1565C0),
                size: 26,
                onPanUpdate: (details) {
                  final delta =
                      (details.delta.dx / baseItemSize.width +
                          details.delta.dy / baseItemSize.height) /
                      2;
                  onScaleUpdate(
                    ItemScale(
                      (scale.x + delta).clamp(kMinScale, kMaxScale),
                      (scale.y + delta).clamp(kMinScale, kMaxScale),
                    ),
                  );
                },
              ),
            ),
            // カラー編集アイコン（左上）
            if (colorEditable)
              Positioned(
                left: m - 13,
                top: m - 13,
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
                left: m + boxW - 13,
                top: m - 13,
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
      return Positioned(left: left - m, top: top - m, child: content);
    }

    return Positioned(left: left, top: top, child: content);
  }

  Widget _resizeHandle({
    required IconData icon,
    required Color color,
    required GestureDragUpdateCallback onPanUpdate,
    double size = 22,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      onPanEnd: (_) => onInteractionEnd?.call(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.55),
      ),
    );
  }
}
