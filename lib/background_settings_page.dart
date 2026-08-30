import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'style_stores.dart';

/// メニュー「背景変更」から開く背景設定画面（プレミアム限定）。
class BackgroundSettingsPage extends StatefulWidget {
  final BackgroundSetting initial;
  final bool isPremium;
  final Future<void> Function(BackgroundSetting) onSave;
  final VoidCallback onUpgrade;

  const BackgroundSettingsPage({
    super.key,
    required this.initial,
    required this.isPremium,
    required this.onSave,
    required this.onUpgrade,
  });

  @override
  State<BackgroundSettingsPage> createState() => _BackgroundSettingsPageState();
}

const List<Color> _bgPalette = [
  Color(0xFFF6F1FB),
  Color(0xFFFFFFFF),
  Color(0xFF212121),
  Color(0xFF0D47A1),
  Color(0xFF1B5E20),
  Color(0xFF4A148C),
  Color(0xFFBF360C),
  Color(0xFFFFF3E0),
  Color(0xFFE0F7FA),
  Color(0xFFFCE4EC),
];

class _BackgroundSettingsPageState extends State<BackgroundSettingsPage> {
  late String _mode;
  late Color _colorA;
  late Color _colorB;
  String? _imageBase64;

  @override
  void initState() {
    super.initState();
    _mode = widget.initial.mode;
    _colorA = widget.initial.colors.isNotEmpty
        ? widget.initial.colors[0]
        : _bgPalette[0];
    _colorB = widget.initial.colors.length > 1
        ? widget.initial.colors[1]
        : _bgPalette[3];
    _imageBase64 = widget.initial.imageBase64;
  }

  bool get _locked => !widget.isPremium;

  Future<void> _pickImage() async {
    if (_locked) {
      widget.onUpgrade();
      return;
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _imageBase64 = base64Encode(bytes);
      _mode = 'image';
    });
  }

  Future<void> _apply() async {
    if (_locked) {
      widget.onUpgrade();
      return;
    }
    final setting = BackgroundSetting(
      mode: _mode,
      colors: _mode == 'gradient' ? [_colorA, _colorB] : [_colorA],
      imageBase64: _mode == 'image' ? _imageBase64 : null,
    );
    await widget.onSave(setting);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _resetToDefault() async {
    await widget.onSave(const BackgroundSetting());
    if (mounted) Navigator.pop(context);
  }

  Widget _swatch(Color c, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? const Color(0xFF7C4DFF) : Colors.black12,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C4DFF),
        foregroundColor: Colors.white,
        title: const Text('背景変更'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_locked)
              Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium,
                      color: Color(0xFFFFA000),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '背景変更はプレミアム限定機能です。',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onUpgrade,
                      child: const Text('アップグレード'),
                    ),
                  ],
                ),
              ),
            // プレビュー
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: _mode == 'color' ? _colorA : null,
                gradient: _mode == 'gradient'
                    ? LinearGradient(colors: [_colorA, _colorB])
                    : null,
                image: _mode == 'image' && _imageBase64 != null
                    ? DecorationImage(
                        image: MemoryImage(base64Decode(_imageBase64!)),
                        fit: BoxFit.cover,
                      )
                    : null,
                border: Border.all(color: Colors.black12),
              ),
              alignment: Alignment.center,
              child: _mode == 'default'
                  ? const Text(
                      'デフォルト背景',
                      style: TextStyle(color: Colors.black45),
                    )
                  : null,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ModeTab(
                    label: '単色',
                    selected: _mode == 'color',
                    onTap: _locked
                        ? widget.onUpgrade
                        : () => setState(() => _mode = 'color'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeTab(
                    label: 'グラデーション',
                    selected: _mode == 'gradient',
                    onTap: _locked
                        ? widget.onUpgrade
                        : () => setState(() => _mode = 'gradient'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeTab(
                    label: '画像',
                    selected: _mode == 'image',
                    onTap: _pickImage,
                  ),
                ),
              ],
            ),
            if (_mode == 'color' || _mode == 'gradient') ...[
              const SizedBox(height: 20),
              Text(
                _mode == 'gradient' ? 'カラー1' : 'カラー',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _bgPalette
                    .map(
                      (c) => _swatch(
                        c,
                        c.toARGB32() == _colorA.toARGB32(),
                        () => setState(() => _colorA = c),
                      ),
                    )
                    .toList(),
              ),
            ],
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
                children: _bgPalette
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
            if (_mode == 'image') ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('画像を選択'),
              ),
            ],
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetToDefault,
                    child: const Text('デフォルトに戻す'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _apply,
                    child: const Text('適用する'),
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
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF7C4DFF),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
