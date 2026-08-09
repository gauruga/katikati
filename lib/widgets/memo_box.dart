import 'package:flutter/material.dart';

/// 自由配置レイアウトに追加できるメモ帳ウィジェット。
class MemoBox extends StatefulWidget {
  final String initialText;
  final ValueChanged<String> onChanged;
  final double width;
  final double height;

  const MemoBox({
    super.key,
    required this.initialText,
    required this.onChanged,
    required this.width,
    required this.height,
  });

  @override
  State<MemoBox> createState() => _MemoBoxState();
}

class _MemoBoxState extends State<MemoBox> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void didUpdateWidget(covariant MemoBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText &&
        _controller.text != widget.initialText) {
      _controller.text = widget.initialText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9C4),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.sticky_note_2_outlined, size: 14, color: Colors.black54),
              SizedBox(width: 4),
              Text('メモ帳',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'メモを入力...',
              ),
              onChanged: widget.onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
