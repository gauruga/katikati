import 'package:flutter/material.dart';
import 'layout_positions.dart';

/// メニュー「移動」から開くレイアウト設定画面。
/// 固定レイアウト / 自由配置レイアウト をタブで切り替える。
class LayoutSettingsPage extends StatefulWidget {
  final int initialButtonCount;
  final bool isPremium;
  // fromDefault: true = デフォルト配置から編集を開始 / false = 現在の配置から編集を開始
  final void Function(bool fromDefault) onOpenFreeEditor;
  final ValueChanged<int> onButtonCountChanged;
  final VoidCallback onUpgrade;

  const LayoutSettingsPage({
    super.key,
    required this.initialButtonCount,
    required this.isPremium,
    required this.onOpenFreeEditor,
    required this.onButtonCountChanged,
    required this.onUpgrade,
  });

  @override
  State<LayoutSettingsPage> createState() => _LayoutSettingsPageState();
}

class _LayoutSettingsPageState extends State<LayoutSettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _buttonCount;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _buttonCount = widget.initialButtonCount;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _countSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: List.generate(kMaxCounterButtons, (i) {
        final n = i + 1;
        final selected = n == _buttonCount;
        return GestureDetector(
          onTap: () {
            setState(() => _buttonCount = n);
            widget.onButtonCountChanged(n);
          },
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: selected
                    ? [const Color(0xFF7C4DFF), const Color(0xFFB388FF)]
                    : [const Color(0xFFE0D6F5), const Color(0xFFE0D6F5)],
              ),
            ),
            child: Text(
              '$n',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: selected ? Colors.white : const Color(0xFF7C4DFF),
              ),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C4DFF),
        foregroundColor: Colors.white,
        title: const Text('レイアウト変更'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: '固定レイアウト'),
            Tab(text: '自由配置レイアウト'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFixedTab(),
          _buildFreeTab(),
        ],
      ),
    );
  }

  Widget _buildFixedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '下部ボタンの数（1〜9）',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 16),
          _countSelector(),
          const SizedBox(height: 24),
          const Text(
            '固定レイアウトでは、既定の位置にすべてのボタンが自動的に整列表示されます。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '下部ボタンの数（1〜9）',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 16),
          _countSelector(),
          const SizedBox(height: 24),
          if (!widget.isPremium)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium,
                      color: Color(0xFFFFA000)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '自由配置レイアウトはプレミアム限定機能です。\n'
                      '未加入でも配置操作はお試しいただけますが、実際の画面には反映されません。',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => widget.onOpenFreeEditor(false),
              icon: const Icon(Icons.open_with),
              label: Text(widget.isPremium
                  ? '今の配置から編集する'
                  : '試してみる（今の配置・プレビュー）'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C4DFF),
                side: const BorderSide(color: Color(0xFF7C4DFF)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => widget.onOpenFreeEditor(true),
              icon: const Icon(Icons.restart_alt),
              label: Text(widget.isPremium
                  ? 'デフォルト配置から編集する'
                  : '試してみる（デフォルト配置・プレビュー）'),
            ),
          ),
          if (!widget.isPremium) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onUpgrade,
                child: const Text('プレミアムにアップグレード'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
