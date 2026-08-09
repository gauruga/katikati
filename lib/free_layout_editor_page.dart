import 'package:flutter/material.dart';
import 'layout_positions.dart';
import 'widgets/free_canvas.dart';

/// 自由配置レイアウトの編集／プレビュー画面。
/// previewOnly=true の場合はプレミアム未加入者向けの「見るだけ体験」で、
/// 操作(ドラッグ・リサイズ・メモ追加・削除)は可能だが実際の画面には反映されないことを示すバナーを表示する。
class FreeLayoutEditorPage extends StatefulWidget {
  final List<String> itemIds;
  final Map<String, Offset> initialPositions;
  final Map<String, double> initialScales;
  final Widget Function(String id) buildContent;
  final bool previewOnly;
  final Future<void> Function(
      Map<String, Offset> positions, Map<String, double> scales) onSave;
  final VoidCallback onUpgrade;
  final bool Function(String id)? isColorEditable;
  final void Function(String id)? onColorTap;
  final bool Function(String id)? isDeletable;
  final void Function(String id)? onDeleteItem;
  final void Function(String id)? onItemDoubleTap;
  // 押すとメモ帳を1つ追加する。新しいID・初期位置を返す。
  final Future<MapEntry<String, Offset>> Function()? onAddMemo;

  const FreeLayoutEditorPage({
    super.key,
    required this.itemIds,
    required this.initialPositions,
    required this.initialScales,
    required this.buildContent,
    required this.previewOnly,
    required this.onSave,
    required this.onUpgrade,
    this.isColorEditable,
    this.onColorTap,
    this.isDeletable,
    this.onDeleteItem,
    this.onItemDoubleTap,
    this.onAddMemo,
  });

  @override
  State<FreeLayoutEditorPage> createState() => _FreeLayoutEditorPageState();
}

class _FreeLayoutEditorPageState extends State<FreeLayoutEditorPage> {
  late Map<String, Offset> _positions;
  late Map<String, double> _scales;
  late List<String> _itemIds;

  @override
  void initState() {
    super.initState();
    _positions = Map.of(widget.initialPositions);
    _scales = Map.of(widget.initialScales);
    _itemIds = List.of(widget.itemIds);
  }

  Future<void> _commit() async {
    await widget.onSave(_positions, _scales);
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('レイアウトをリセットしますか？'),
        content: const Text('全てのボタンの位置・サイズが初期状態に戻ります。この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('リセットする'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final defPos = defaultPositions();
    final defScale = defaultScales();
    final newPositions = <String, Offset>{};
    final newScales = <String, double>{};
    int memoOrder = 0;
    for (final id in _itemIds) {
      if (id.startsWith('memo_')) {
        newPositions[id] = defaultMemoPosition(memoOrder);
        newScales[id] = defaultMemoScale;
        memoOrder++;
      } else {
        newPositions[id] = defPos[id] ?? Offset.zero;
        newScales[id] = defScale[id] ?? 1.0;
      }
    }
    setState(() {
      _positions = newPositions;
      _scales = newScales;
    });
    await _commit();
  }

  Future<void> _addMemo() async {
    final onAddMemo = widget.onAddMemo;
    if (onAddMemo == null) return;
    final result = await onAddMemo();
    setState(() {
      _itemIds = [..._itemIds, result.key];
      _positions[result.key] = result.value;
      _scales[result.key] = defaultMemoScale;
    });
    await _commit();
  }

  void _deleteItem(String id) {
    setState(() {
      _itemIds = _itemIds.where((i) => i != id).toList();
      _positions.remove(id);
      _scales.remove(id);
    });
    widget.onDeleteItem?.call(id);
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C4DFF),
        foregroundColor: Colors.white,
        title: Text(widget.previewOnly ? 'プレビュー（プレミアム限定機能）' : 'レイアウト編集'),
        actions: [
          TextButton(
            onPressed: _reset,
            child: const Text('リセット', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.onAddMemo != null) _buildAddMemoRow(),
            Expanded(
              child: FreeCanvas(
                itemIds: _itemIds,
                positions: _positions,
                scales: _scales,
                editing: true,
                buildContent: widget.buildContent,
                onDragUpdate: (id, f) => setState(() => _positions[id] = f),
                onScaleUpdate: (id, s) => setState(() => _scales[id] = s),
                onInteractionEnd: _commit,
                overlayTop: widget.previewOnly ? _buildPreviewBanner() : null,
                isColorEditable: widget.isColorEditable,
                onColorTap: widget.onColorTap,
                isDeletable: widget.isDeletable,
                onDelete: _deleteItem,
                onItemDoubleTap: widget.onItemDoubleTap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddMemoRow() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.sticky_note_2_outlined,
              color: Color(0xFF7C4DFF), size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'メモ帳（ダブルタップで文字入力・×で削除）',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF7C4DFF),
              side: const BorderSide(color: Color(0xFF7C4DFF)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            onPressed: _addMemo,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('メモ帳を追加', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF3E0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFF57C00), size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '配置操作はお試しいただけますが、実際の画面には反映されません。',
              style: TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
            ),
          ),
          TextButton(
            onPressed: widget.onUpgrade,
            child: const Text('アップグレード'),
          ),
        ],
      ),
    );
  }
}
