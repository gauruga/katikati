import 'package:flutter/material.dart';
import 'layout_positions.dart';

/// メニュー「移動」から開くレイアウト設定画面。
/// 固定レイアウト / 自由配置レイアウト をタブで切り替える。
class LayoutSettingsPage extends StatefulWidget {
  final int initialButtonCount;
  final bool isPremium;
  // 現在使用中のレイアウト ('fixed' | 'free')
  final String layoutMode;
  // 固定レイアウトに戻す
  final VoidCallback onUseFixedLayout;
  // fromDefault: true = デフォルト配置から編集を開始 / false = 現在の配置から編集を開始
  final void Function(bool fromDefault) onOpenFreeEditor;
  final ValueChanged<int> onButtonCountChanged;
  final VoidCallback onUpgrade;

  const LayoutSettingsPage({
    super.key,
    required this.initialButtonCount,
    required this.isPremium,
    required this.layoutMode,
    required this.onUseFixedLayout,
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
  // 実際に反映済みの下部ボタン数
  late int _appliedCount;
  // 各タブで選択中（未反映）の下部ボタン数
  late int _fixedCount;
  late int _freeCount;
  late String _mode;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _appliedCount = widget.initialButtonCount;
    _fixedCount = widget.initialButtonCount;
    _freeCount = widget.initialButtonCount;
    _mode = widget.layoutMode;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 下部ボタン数の選択リング。選んだだけでは反映せず、呼び出し側の
  /// 「適用」／「デフォルト配置から編集する」を押したときにだけ反映する。
  Widget _countSelector({
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: List.generate(kMaxCounterButtons, (i) {
        final n = i + 1;
        final selected = n == value;
        return GestureDetector(
          onTap: () => onChanged(n),
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
        children: [_buildFixedTab(), _buildFreeTab()],
      ),
    );
  }

  Widget _buildFixedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '下部ボタンの数（1〜$kMaxCounterButtons）',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 6),
          const Text(
            '数が多いときは、メニューの「シンプル表示」をオンにすると'
            '上の段が消えてボタンを大きく使えます。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          _countSelector(
            value: _fixedCount,
            onChanged: (n) => setState(() => _fixedCount = n),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _applyFixedCount,
              icon: const Icon(Icons.check),
              label: const Text('適用'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '「適用」を押すまでホーム画面には反映されません。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          const Text(
            '固定レイアウトでは、既定の位置にすべてのボタンが自動的に整列表示されます。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          if (widget.isPremium) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C4DFF),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _mode == 'fixed'
                    ? null
                    : () {
                        setState(() => _mode = 'fixed');
                        widget.onUseFixedLayout();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('固定レイアウトに戻しました')),
                        );
                      },
                icon: Icon(
                  _mode == 'fixed' ? Icons.check : Icons.grid_view_rounded,
                ),
                label: Text(_mode == 'fixed' ? '固定レイアウトを使用中' : '固定レイアウトに戻す'),
              ),
            ),
          ],
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
          if (!widget.isPremium)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium, color: Color(0xFFFFA000)),
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
          if (!widget.isPremium) const SizedBox(height: 20),
          Text(
            '下部ボタンの数（1〜$kMaxCounterButtons）',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 6),
          const Text(
            'この数は下の「デフォルト配置から編集する」でだけ使います。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          _countSelector(
            value: _freeCount,
            onChanged: (n) => setState(() => _freeCount = n),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _openDefaultEditor,
              icon: const Icon(Icons.restart_alt),
              label: Text(
                widget.isPremium ? 'デフォルト配置から編集する' : '試してみる（デフォルト配置・プレビュー）',
              ),
            ),
          ),
          _sectionDivider(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C4DFF),
                side: const BorderSide(color: Color(0xFF7C4DFF)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => widget.onOpenFreeEditor(false),
              icon: const Icon(Icons.open_with),
              label: Text(
                widget.isPremium ? '今の配置から編集する' : '試してみる（今の配置・プレビュー）',
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '現在のボタン配置・個数をそのまま引き継いで編集します。'
            '上の「下部ボタンの数」の影響は受けません。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          _sectionDivider(),
          if (widget.isPremium)
            const Text(
              'この配置に名前を付けて保存したり、保存した配置を呼び出したりするのは、'
              'メニューの「レイアウトの保存」から行えます。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onUpgrade,
                child: const Text('プレミアムにアップグレード'),
              ),
            ),
        ],
      ),
    );
  }

  /// 区切り線。
  Widget _sectionDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Divider(height: 1, thickness: 1, color: Color(0xFFDCD1EE)),
    );
  }

  /// 「適用」: 選んだ下部ボタン数を反映してホーム画面へ戻る。
  void _applyFixedCount() {
    widget.onButtonCountChanged(_fixedCount);
    _appliedCount = _fixedCount;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('下部ボタンを$_fixedCount個にしました')));
    Navigator.pop(context);
  }

  /// デフォルト配置から編集する。ここでだけ選択中の下部ボタン数を反映する。
  void _openDefaultEditor() {
    if (_freeCount != _appliedCount) {
      widget.onButtonCountChanged(_freeCount);
      setState(() => _appliedCount = _freeCount);
    }
    widget.onOpenFreeEditor(true);
  }
}
