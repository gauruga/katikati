import 'package:flutter/material.dart';
import '../layout_positions.dart';
import 'free_item.dart';

/// 自由配置レイアウトを描画する共通キャンバス。
/// editing=true でドラッグ／リサイズ可能、false なら表示専用。
class FreeCanvas extends StatelessWidget {
  final List<String> itemIds;
  final Map<String, Offset> positions;
  final Map<String, double> scales;
  final bool editing;
  final Widget Function(String id) buildContent;
  final void Function(String id, Offset fraction)? onDragUpdate;
  final void Function(String id, double scale)? onScaleUpdate;
  final VoidCallback? onInteractionEnd;
  final Widget? overlayTop;
  final Widget? overlayBottom;
  final bool Function(String id)? isColorEditable;
  final void Function(String id)? onColorTap;
  final bool Function(String id)? isDeletable;
  final void Function(String id)? onDelete;
  final void Function(String id)? onItemDoubleTap;

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
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height =
            constraints.maxHeight < kRefHeight ? kRefHeight : constraints.maxHeight;
        final canvasSize = Size(width, height);
        return SingleChildScrollView(
          physics: editing
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                for (final id in itemIds)
                  FreeItem(
                    fraction: positions[id] ?? Offset.zero,
                    scale: scales[id] ?? 1.0,
                    canvasSize: canvasSize,
                    baseItemSize: ItemSizes.forId(id),
                    editing: editing,
                    onDragUpdate: (f) => onDragUpdate?.call(id, f),
                    onScaleUpdate: (s) => onScaleUpdate?.call(id, s),
                    onInteractionEnd: onInteractionEnd,
                    colorEditable: isColorEditable?.call(id) ?? false,
                    onColorTap: () => onColorTap?.call(id),
                    deletable: isDeletable?.call(id) ?? false,
                    onDelete: () => onDelete?.call(id),
                    onDoubleTap: () => onItemDoubleTap?.call(id),
                    child: buildContent(id),
                  ),
                if (overlayTop != null)
                  Positioned(top: 0, left: 0, right: 0, child: overlayTop!),
                if (overlayBottom != null)
                  Positioned(
                      left: 16, right: 16, bottom: 16, child: overlayBottom!),
              ],
            ),
          ),
        );
      },
    );
  }
}
