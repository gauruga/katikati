import 'package:flutter/material.dart';
import '../style_stores.dart';

/// 単色 / グラデーションを選べるシンプルなカラーピッカー。
class ColorPickerSheet extends StatefulWidget {
  final ItemStyle initial;

  const ColorPickerSheet({super.key, required this.initial});

  static Future<ItemStyle?> show(BuildContext context, ItemStyle initial) {
    return showModalBottomSheet<ItemStyle>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ColorPickerSheet(initial: initial),
    );
  }

  @override
  State<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

const List<Color> _palette = [
  Color(0xFF7C4DFF),
  Color(0xFFB388FF),
  Color(0xFFEC407A),
  Color(0xFFF48FB1),
  Color(0xFFFFA726),
  Color(0xFFFFCC80),
  Color(0xFF26A69A),
  Color(0xFF80CBC4),
  Color(0xFFFF7043),
  Color(0xFFFFAB91),
  Color(0xFF66BB6A),
  Color(0xFFA5D6A7),
  Color(0xFF42A5F5),
  Color(0xFF90CAF9),
  Color(0xFFAB47BC),
  Color(0xFFCE93D8),
  Color(0xFFFFCA28),
  Color(0xFFFFE082),
  Color(0xFF616161),
  Color(0xFFBDBDBD),
  Color(0xFFE53935),
  Color(0xFF43A047),
  Color(0xFF212121),
  Color(0xFFFFFFFF),
];

class _ColorPickerSheetState extends State<ColorPickerSheet> {
  late String _mode;
  late Color _colorA;
  late Color _colorB;

  @override
  void initState() {
    super.initState();
    _mode = widget.initial.mode == 'default' ? 'solid' : widget.initial.mode;
    _colorA = widget.initial.colors.isNotEmpty
        ? widget.initial.colors[0]
        : _palette[0];
    _colorB = widget.initial.colors.length > 1
        ? widget.initial.colors[1]
        : _palette[2];
  }

  Widget _swatch(Color c, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.black : Colors.black12,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '色を変更',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ModeTab(
                    label: '単色',
                    selected: _mode == 'solid',
                    onTap: () => setState(() => _mode = 'solid'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ModeTab(
                    label: 'グラデーション',
                    selected: _mode == 'gradient',
                    onTap: () => setState(() => _mode = 'gradient'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: _mode == 'gradient'
                    ? LinearGradient(colors: [_colorA, _colorB])
                    : LinearGradient(colors: [_colorA, _colorA]),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _mode == 'gradient' ? 'カラー1' : 'カラー',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _palette
                  .map(
                    (c) => _swatch(
                      c,
                      c.toARGB32() == _colorA.toARGB32(),
                      () => setState(() => _colorA = c),
                    ),
                  )
                  .toList(),
            ),
            if (_mode == 'gradient') ...[
              const SizedBox(height: 18),
              const Text(
                'カラー2',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _palette
                    .map(
                      (c) => _swatch(
                        c,
                        c.toARGB32() == _colorB.toARGB32(),
                        () => setState(() => _colorB = c),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context, const ItemStyle(mode: 'default'));
                    },
                    child: const Text('リセット'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                    ),
                    onPressed: () {
                      Navigator.pop(
                        context,
                        ItemStyle(
                          mode: _mode,
                          colors: _mode == 'gradient'
                              ? [_colorA, _colorB]
                              : [_colorA],
                        ),
                      );
                    },
                    child: const Text('適用'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7C4DFF) : const Color(0xFFEDE7F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF7C4DFF),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
