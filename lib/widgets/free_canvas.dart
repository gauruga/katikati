import 'package:flutter/material.dart';
import '../layout_positions.dart';
import 'free_item.dart';

/// 自由配置レイアウトを描画する共通キャンバス。
/// editing=true でドラッグ／リサイズ可能、false なら表示専用。
class FreeCanvas extends StatelessWidget {
  final List<String> itemIds;
  final Map<String, Offset> positions;
  final Map<String, ItemScale> scales;
  final bool editing;
  final Widget Function(String id, Size size) buildContent;
  final void Function(String id, Offset fraction)? onDragUpdate;
  final void Function(String id, ItemScale scale)? onScaleUpdate;
  final VoidCallback? onInteractionEnd;
  final Widget? overlayTop;
  final Widget? overlayBottom;
  final bool Function(String id)? isColorEditable;
  final void Function(String id)? onColorTap;
  final bool Function(String id)? isDeletable;
  final void Function(String id)? onDelete;
  final void Function(String id)? onItemDoubleTap;
  // 実画面と同じ大きさのキャンバスで編集したいときに渡す。
  // 表示領域に収まるよう自動で縮小表示される。
  final Size? logicalSize;
  // 実際に使われたキャンバスサイズの通知（デフォルト配置の計算に使う）
  final ValueChanged<Size>? onCanvasSize;

  const FreeCanvas({
    super.key,
    required this.itemIds,
    required this.positions,
    required this.scales,
    required this.editing,
    required this.buildContent,
    this.onDragUpdate,
    this.onScaleUpdate,
    this.onInteractionEnd,
    this.overlayTop,
    this.overlayBottom,
    this.isColorEditable,
    this.onColorTap,
    this.isDeletable,
    this.onDelete,
    this.onItemDoubleTap,
    this.logicalSize,
    this.onCanvasSize,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 表示領域そのものをキャンバスにする（編集中はスクロールできないため、
        // 画面より大きいキャンバスだと下部が操作できなくなる）。
        final viewport = Size(
          constraints.maxWidth,
          constraints.maxHeight.isFinite ? constraints.maxHeight : kRefHeight,
        );
        final canvasSize = logicalSize ?? viewport;
        onCanvasSize?.call(canvasSize);
        final canvas = SizedBox(
          width: canvasSize.width,
          height: canvasSize.height,
          child: Stack(
            clipBehavior: editing ? Clip.none : Clip.hardEdge,
            children: [
              for (final id in itemIds) _buildItem(id, canvasSize),
              if (overlayTop != null)
                Positioned(top: 0, left: 0, right: 0, child: overlayTop!),
              if (overlayBottom != null)
                Positioned(
                    left: 16, right: 16, bottom: 16, child: overlayBottom!),
            ],
          ),
        );
        if (logicalSize == null) return canvas;
        // 実画面と同じ配置のまま、編集画面に収まるよう縮小して表示する。
        return FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.topCenter,
          child: canvas,
        );
      },
    );
  }

  Widget _buildItem(String id, Size canvasSize) {
    final base = ItemSizes.forId(id);
    final scale = scales[id] ?? const ItemScale.uniform(1.0);
    final itemSize = Size(base.width * scale.x, base.height * scale.y);
    return FreeItem(
      fraction: positions[id] ?? Offset.zero,
      scale: scale,
      canvasSize: canvasSize,
      baseItemSize: base,
      editing: editing,
      stretchToSize: stretchesToSize(id),
      onDragUpdate: (f) => onDragUpdate?.call(id, f),
      onScaleUpdate: (s) => onScaleUpdate?.call(id, s),
      onInteractionEnd: onInteractionEnd,
      colorEditable: isColorEditable?.call(id) ?? false,
      onColorTap: () => onColorTap?.call(id),
      deletable: isDeletable?.call(id) ?? false,
      onDelete: () => onDelete?.call(id),
      onDoubleTap: () => onItemDoubleTap?.call(id),
      child: buildContent(id, itemSize),
    );
  }
}
