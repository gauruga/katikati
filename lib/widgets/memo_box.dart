import 'package:flutter/material.dart';

/// 自由配置レイアウトに追加できるメモ帳ウィジェット。
/// タイトルは書き換えでき、右上のボタンで本文を隠す／展開できる。
class MemoBox extends StatefulWidget {
  final String initialText;
  final String initialTitle;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onTitleChanged;
  final bool collapsed;
  final ValueChanged<bool> onCollapsedChanged;
  final double width;
  final double height;

  /// 本文の文字サイズ（デフォルトサイズはこの6行分の高さ）。
  static const double bodyFontSize = 13;
  static const double bodyLineHeight = 1.3;
  static const double titleFontSize = 11;
  static const double padding = 10;
  static const double headerHeight = 18;
  static const double headerGap = 4;

  /// 本文 [lines] 行がちょうど収まる高さ。
  static double heightForLines(int lines) =>
      padding * 2 +
      headerHeight +
      headerGap +
      bodyFontSize * bodyLineHeight * lines;

  const MemoBox({
    super.key,
    required this.initialText,
    required this.initialTitle,
    required this.onChanged,
    required this.onTitleChanged,
    required this.collapsed,
    required this.onCollapsedChanged,
    required this.width,
    required this.height,
  });

  @override
  State<MemoBox> createState() => _MemoBoxState();
}

class _MemoBoxState extends State<MemoBox> {
  late TextEditingController _controller;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _titleController = TextEditingController(text: widget.initialTitle);
  }

  @override
  void didUpdateWidget(covariant MemoBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText &&
        _controller.text != widget.initialText) {
      _controller.text = widget.initialText;
    }
    if (oldWidget.initialTitle != widget.initialTitle &&
        _titleController.text != widget.initialTitle) {
      _titleController.text = widget.initialTitle;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 折りたたみ時はタイトル行だけの高さになるよう、上下は成り行きにする。
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        width: widget.width,
        height: widget.collapsed ? null : widget.height,
        padding: const EdgeInsets.all(MemoBox.padding),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9C4),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: MemoBox.headerHeight,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      textAlignVertical: TextAlignVertical.center,
                      style: const TextStyle(
                        fontSize: MemoBox.titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'タイトル',
                      ),
                      onChanged: widget.onTitleChanged,
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onCollapsedChanged(!widget.collapsed),
                    child: SizedBox(
                      width: 18,
                      height: MemoBox.headerHeight,
                      child: Icon(
                        widget.collapsed
                            ? Icons.expand_more
                            : Icons.expand_less,
                        size: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!widget.collapsed) ...[
              const SizedBox(height: MemoBox.headerGap),
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    fontSize: MemoBox.bodyFontSize,
                    height: MemoBox.bodyLineHeight,
                    color: Colors.black87,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'メモ...',
                  ),
                  onChanged: widget.onChanged,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
