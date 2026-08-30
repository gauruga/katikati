import 'package:flutter/material.dart';
import 'layout_positions.dart';
import 'widgets/free_canvas.dart';

/// 自由配置レイアウトの編集／プレビュー画面。
/// previewOnly=true の場合はプレミアム未加入者向けの「見るだけ体験」で、
/// 操作(ドラッグ・リサイズ・メモ追加・削除)は可能だが実際の画面には反映されないことを示すバナーを表示する。
class FreeLayoutEditorPage extends StatefulWidget {
  final List<String> itemIds;
  final Map<String, Offset> initialPositions;
  final Map<String, ItemScale> initialScales;
  final Widget Function(String id, Size size) buildContent;
  final bool previewOnly;
  // 下部カウントボタンの数（リセット時のデフォルト配置に使う）
  final int buttonCount;
  final Future<void> Function(
      Map<String, Offset> positions, Map<String, ItemScale> scales) onSave;
  final VoidCallback onUpgrade;
  final bool Function(String id)? isColorEditable;
  final void Function(String id)? onColorTap;
  final bool Function(String id)? isDeletable;
  final void Function(String id)? onDeleteItem;
  final void Function(String id)? onItemDoubleTap;
  // 押すとメモ帳を1つ追加する。新しいID・初期位置を返す。
  final Future<MapEntry<String, Offset>> Function()? onAddMemo;
  // 実画面と同じ大きさのキャンバスで編集するためのサイズ
  final Size canvasSize;
  // 名前を付けて現在のレイアウトを保存する
  final Future<void> Function(String name)? onSaveNamed;
  // 既に保存済みの名前一覧（上書き確認に使う）
  final List<String> presetNames;

  const FreeLayoutEditorPage({
    super.key,
    required this.itemIds,
    required this.initialPositions,
    required this.initialScales,
    required this.buildContent,
    required this.previewOnly,
    required this.buttonCount,
    required this.onSave,
    required this.onUpgrade,
    this.isColorEditable,
    this.onColorTap,
    this.isDeletable,
    this.onDeleteItem,
    this.onItemDoubleTap,
    this.onAddMemo,
    required this.canvasSize,
    this.onSaveNamed,
    this.presetNames = const [],
  });

  @override
  State<FreeLayoutEditorPage> createState() => _FreeLayoutEditorPageState();
}

class _FreeLayoutEditorPageState extends State<FreeLayoutEditorPage> {
  late Map<String, Offset> _positions;
  late Map<String, ItemScale> _scales;
  late List<String> _itemIds;
  // この画面で追加したメモ帳（破棄する場合は取り消す）
  final List<String> _addedIds = [];
  // 完了・保存したときに実際に削除するアイテム
  final List<String> _pendingDeletes = [];
  // 編集内容は「完了」または「保存」を押すまで反映しない
  bool _dirty = false;
  bool _canPop = false;

  @override
  void initState() {
    super.initState();
    _positions = Map.of(widget.initialPositions);
    _scales = Map.of(widget.initialScales);
    _itemIds = List.of(widget.itemIds);
  }

  /// 編集内容を実際のレイアウトへ反映する。
  Future<void> _commit() async {
    for (final id in _pendingDeletes) {
      widget.onDeleteItem?.call(id);
    }
    _pendingDeletes.clear();
    _addedIds.clear();
    await widget.onSave(_positions, _scales);
    _dirty = false;
  }

  /// 編集内容を捨ててこの画面を閉じる（← / 端末の戻る）。
  Future<void> _leaveWithoutSaving() async {
    if (_dirty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('編集を破棄しますか？'),
          content: const Text('現在の編集が破棄されますが、よろしいですか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('編集を続ける'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('破棄する'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    // この画面で追加したメモ帳は取り消す
    for (final id in _addedIds) {
      widget.onDeleteItem?.call(id);
    }
    _addedIds.clear();
    _pendingDeletes.clear();
    if (!mounted) return;
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _done() async {
    await _commit();
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('編集前に戻しますか？'),
        content: const Text('この画面を開いたときの配置・サイズに戻します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('戻す'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // この画面で追加したメモ帳は取り除く
    for (final id in _addedIds) {
      widget.onDeleteItem?.call(id);
    }
    _addedIds.clear();
    _pendingDeletes.clear();
    setState(() {
      _itemIds = List.of(widget.itemIds);
      _positions = Map.of(widget.initialPositions);
      _scales = Map.of(widget.initialScales);
      _dirty = false;
    });
  }

  Future<void> _saveNamed() async {
    final onSaveNamed = widget.onSaveNamed;
    if (onSaveNamed == null) return;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('レイアウトを保存'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '名前を付けて保存すると、あとから呼び出せます。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'タイトル',
              ),
            ),
            if (widget.presetNames.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('保存済み', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  for (final n in widget.presetNames)
                    ActionChip(
                      label: Text(n, style: const TextStyle(fontSize: 12)),
                      onPressed: () => controller.text = n,
                    ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _commit();
    await onSaveNamed(name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「$name」として保存しました')),
    );
  }

  Future<void> _addMemo() async {
    final onAddMemo = widget.onAddMemo;
    if (onAddMemo == null) return;
    final result = await onAddMemo();
    setState(() {
      _itemIds = [..._itemIds, result.key];
      _positions[result.key] = result.value;
      _scales[result.key] = defaultMemoScale;
      _addedIds.add(result.key);
      _dirty = true;
    });
  }

  void _deleteItem(String id) {
    setState(() {
      _itemIds = _itemIds.where((i) => i != id).toList();
      _positions.remove(id);
      _scales.remove(id);
      _dirty = true;
      if (_addedIds.remove(id)) {
        // この画面で追加したものはその場で取り消す
        widget.onDeleteItem?.call(id);
      } else {
        _pendingDeletes.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _leaveWithoutSaving();
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C4DFF),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '編集を破棄して戻る',
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Row(
          children: [
            _barButton(
              icon: Icons.check,
              label: '完了',
              onPressed: _done,
            ),
            _barButton(
              icon: Icons.undo,
              label: 'リセット',
              onPressed: _reset,
            ),
            if (widget.onAddMemo != null)
              _barButton(
                icon: Icons.add,
                label: 'メモ帳',
                onPressed: _addMemo,
              ),
            if (widget.onSaveNamed != null)
              _barButton(
                icon: Icons.bookmark_add_outlined,
                label: '保存',
                onPressed: _saveNamed,
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: FreeCanvas(
                itemIds: _itemIds,
                positions: _positions,
                scales: _scales,
                editing: true,
                buildContent: widget.buildContent,
                onDragUpdate: (id, f) => setState(() {
                  _positions[id] = f;
                  _dirty = true;
                }),
                onScaleUpdate: (id, s) => setState(() {
                  _scales[id] = s;
                  _dirty = true;
                }),
                overlayTop: widget.previewOnly ? _buildPreviewBanner() : null,
                isColorEditable: widget.isColorEditable,
                onColorTap: widget.onColorTap,
                isDeletable: widget.isDeletable,
                onDelete: _deleteItem,
                onItemDoubleTap: widget.onItemDoubleTap,
                logicalSize: widget.canvasSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontSize: 13)),
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
