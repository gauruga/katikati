import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'background_settings_page.dart';
import 'free_layout_editor_page.dart';
import 'gogo_lamp_button.dart';
import 'layout_positions.dart';
import 'layout_settings_page.dart';
import 'state_store.dart';
import 'style_stores.dart';
import 'widgets/adjust_button.dart';
import 'widgets/circle_icon_button.dart';
import 'widgets/color_picker_sheet.dart';
import 'widgets/counter_button.dart';
import 'widgets/free_canvas.dart';
import 'widgets/labeled_box.dart';
import 'widgets/memo_box.dart';
import 'widgets/pressable.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _store = StateStore();
  final _layoutStore = LayoutStore();
  final _itemStyleStore = ItemStyleStore();
  final _backgroundStore = BackgroundStore();
  final _memoStore = MemoStore();

  // ---- 状態 ----
  int _startCount = 0;
  bool _startEntered = false; // 一度確定したら true (入力欄を無効化)
  int _mainCount = 0;
  int _total = 0;
  List<int> _buttonCounts = List.filled(kMaxCounterButtons, 0);
  int _buttonLayout = 4; // 1〜9 (デフォルト4)
  String _premiumType = 'none'; // none | onetime | monthly
  bool get _isPremium => _premiumType != 'none';
  bool _isPlaying = false;

  String _layoutMode = 'fixed'; // 'fixed' | 'free'
  Map<String, Offset> _freePositions = {};
  Map<String, double> _freeScales = {};
  Map<String, ItemStyle> _itemStyles = {};
  BackgroundSetting _background = const BackgroundSetting();
  List<String> _memoIds = [];
  Map<String, String> _memoTexts = {};
  Set<String> _excludedFreeIds = {}; // 自由配置レイアウトから削除された下部ボタンID

  // ランプ誤操作の取り消し用
  int? _lastLampDiff;

  Timer? _timer;
  Timer? _progressTimer;
  DateTime? _playStartedAt;
  double _elapsedSeconds = 0;

  final _startController = TextEditingController();
  bool _loaded = false;

  static const _cycleMs = 4100;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _store.load();
    final layout = await _layoutStore.load();
    final styles = await _itemStyleStore.load();
    final bg = await _backgroundStore.load();
    final memoIds = await _memoStore.loadIds();
    final memoTexts = await _memoStore.loadTexts();
    final excluded = await _layoutStore.loadExcluded();
    setState(() {
      _startCount = data['startCount'];
      _startEntered = data['startEntered'];
      _mainCount = data['mainCount'];
      _total = data['total'];
      _buttonCounts = List<int>.from(data['buttonCounts']);
      if (_buttonCounts.length < kMaxCounterButtons) {
        final filled = List<int>.filled(kMaxCounterButtons, 0);
        for (int i = 0; i < _buttonCounts.length; i++) {
          filled[i] = _buttonCounts[i];
        }
        _buttonCounts = filled;
      }
      _buttonLayout = data['buttonLayout'];
      _premiumType = data['premiumType'];
      _layoutMode = data['layoutMode'];
      _freePositions = layout.positions;
      _freeScales = layout.scales;
      _itemStyles = styles;
      _background = bg;
      _memoIds = memoIds;
      _memoTexts = memoTexts;
      _excludedFreeIds = excluded;
      _startController.text = _startEntered ? '$_startCount' : '';
      _loaded = true;
    });
  }

  Future<void> _persist() async {
    await _store.save(
      startCount: _startCount,
      startEntered: _startEntered,
      mainCount: _mainCount,
      total: _total,
      buttonCounts: _buttonCounts,
      buttonLayout: _buttonLayout,
      premiumType: _premiumType,
      layoutMode: _layoutMode,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressTimer?.cancel();
    _startController.dispose();
    super.dispose();
  }

  // ---- ロジック ----

  void _confirmStartCount() {
    if (_startEntered) return;
    final v = int.tryParse(_startController.text) ?? 0;
    setState(() {
      _startCount = v;
      _mainCount = v;
      _startEntered = true;
      _lastLampDiff = null;
    });
    FocusScope.of(context).unfocus();
    _persist();
  }

  Future<void> _onStartBoxTapWhileLocked() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('固定を解除しますか？'),
        content: const Text('開始ゲーム数の入力固定を解除して、再入力できるようにします。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('解除する'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        _startEntered = false;
        _startController.text = '';
        _lastLampDiff = null;
      });
      _persist();
    }
  }

  void _adjustMain(int delta) {
    setState(() {
      _mainCount = (_mainCount + delta).clamp(0, 1 << 31);
      _lastLampDiff = null;
    });
    _persist();
  }

  void _togglePlay() {
    if (_isPlaying) {
      _stopPlay();
    } else {
      _startPlay();
    }
  }

  void _startPlay() {
    _timer?.cancel();
    _progressTimer?.cancel();
    _playStartedAt = DateTime.now();
    setState(() {
      _isPlaying = true;
      _elapsedSeconds = 0;
      _lastLampDiff = null;
    });
    _timer = Timer.periodic(const Duration(milliseconds: _cycleMs), (_) {
      setState(() {
        _mainCount = _mainCount + 1;
      });
      _persist();
    });
    _progressTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      final startedAt = _playStartedAt;
      if (startedAt == null) return;
      final elapsedMs =
          DateTime.now().difference(startedAt).inMilliseconds % _cycleMs;
      setState(() {
        _elapsedSeconds = elapsedMs / 1000.0;
      });
    });
  }

  void _stopPlay() {
    _timer?.cancel();
    _progressTimer?.cancel();
    _playStartedAt = null;
    setState(() {
      _isPlaying = false;
      _elapsedSeconds = 0;
    });
  }

  /// ランプボタン押下。
  /// 通常時: Total += (大きい数字 - 開始ゲーム数)、大きい数字を0にリセット。
  /// 直前のランプ操作を取り消したい場合（誤操作で押した後、大きい数字が0のまま）:
  /// もう一度押すと Total から差し引いた分を大きい数字に戻す（取り消し）。
  void _onLampPressed() {
    if (_lastLampDiff != null && _mainCount == 0) {
      // 取り消し
      final diff = _lastLampDiff!;
      setState(() {
        _mainCount = diff;
        _total = (_total - diff).clamp(0, 1 << 31);
        _lastLampDiff = null;
      });
      _persist();
      return;
    }

    setState(() {
      final diff = _mainCount - _startCount;
      _total = (_total + diff).clamp(0, 1 << 31);
      _mainCount = 0;
      _isPlaying = false;
      _lastLampDiff = diff;
    });
    _timer?.cancel();
    _progressTimer?.cancel();
    _playStartedAt = null;
    _elapsedSeconds = 0;
    _persist();
  }

  Future<void> _editMainCountDialog() async {
    final controller = TextEditingController(text: '$_mainCount');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('数字を編集'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(controller.text) ?? 0;
              Navigator.pop(ctx, v);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() {
        _mainCount = result.clamp(0, 1 << 31);
        _lastLampDiff = null;
      });
      _persist();
    }
  }

  void _incrementButton(int index) {
    setState(() {
      _buttonCounts[index] = _buttonCounts[index] + 1;
    });
    _persist();
  }

  String _ratioText(int index) {
    final count = _buttonCounts[index];
    if (count <= 0) return '1/-';
    final value = (_mainCount + _total) / count;
    return '1/${value.toStringAsFixed(1)}';
  }

  // ---- データクリア ----

  Future<void> _confirmClearData() async {
    Navigator.pop(context); // close drawer
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('データをクリアしますか？'),
        content: const Text('全ての数字がゼロに戻り、開始ゲーム数の固定も解除されます。この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('クリアする'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _timer?.cancel();
      _progressTimer?.cancel();
      _playStartedAt = null;
      setState(() {
        _startCount = 0;
        _startEntered = false;
        _mainCount = 0;
        _total = 0;
        _buttonCounts = List.filled(kMaxCounterButtons, 0);
        _isPlaying = false;
        _elapsedSeconds = 0;
        _startController.text = '';
        _lastLampDiff = null;
      });
      _persist();
    }
  }

  // ---- 移動(レイアウト変更) ----

  void _openLayoutSettings() {
    Navigator.pop(context); // close drawer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => LayoutSettingsPage(
          initialButtonCount: _buttonLayout,
          isPremium: _isPremium,
          onButtonCountChanged: (n) {
            setState(() => _buttonLayout = n);
            _persist();
          },
          onOpenFreeEditor: _openFreeEditor,
          onUpgrade: () {
            Navigator.pop(ctx);
            _openPremiumSheet();
          },
        ),
      ),
    );
  }

  List<String> _freeItemIds() {
    return [
      'start_box',
      'total_box',
      'play_btn',
      'lamp_btn',
      'stop_btn',
      'dec_100',
      'dec_10',
      'dec_1',
      'inc_100',
      'inc_10',
      'inc_1',
      'main_counter',
      ..._memoIds,
      for (int i = 0; i < _buttonLayout.clamp(1, kMaxCounterButtons); i++)
        if (!_excludedFreeIds.contains('counter_$i')) 'counter_$i',
    ];
  }

  static const _colorEditableIds = {
    'play_btn',
    'stop_btn',
    'dec_100',
    'dec_10',
    'dec_1',
    'inc_100',
    'inc_10',
    'inc_1',
    'main_counter',
  };

  bool _isColorEditable(String id) {
    return _colorEditableIds.contains(id) || id.startsWith('counter_');
  }

  bool _isDeletable(String id) {
    return id.startsWith('counter_') || id.startsWith('memo_');
  }

  Future<ItemStyle?> _pickColorForId(
      BuildContext context, String id, List<Color> fallback) async {
    final current = _itemStyles[id] ?? const ItemStyle();
    return ColorPickerSheet.show(context, current);
  }

  /// 自由配置レイアウトの初期位置／サイズを解決する。
  /// fromDefault=true の場合はデフォルト配置、false の場合は現在保存されている
  /// 配置（新規追加アイテムはデフォルト位置で補完）を返す。
  ({Map<String, Offset> positions, Map<String, double> scales})
      _resolveFreeLayout(bool fromDefault) {
    final ids = _freeItemIds();
    final defPos = defaultPositions();
    final defScale = defaultScales();
    final positions = <String, Offset>{};
    final scales = <String, double>{};
    int memoOrder = 0;
    for (final id in ids) {
      if (id.startsWith('memo_')) {
        if (!fromDefault && _freePositions.containsKey(id)) {
          positions[id] = _freePositions[id]!;
          scales[id] = _freeScales[id] ?? defaultMemoScale;
        } else {
          positions[id] = defaultMemoPosition(memoOrder);
          scales[id] = defaultMemoScale;
        }
        memoOrder++;
      } else {
        if (!fromDefault && _freePositions.containsKey(id)) {
          positions[id] = _freePositions[id]!;
          scales[id] = _freeScales[id] ?? defScale[id] ?? 1.0;
        } else {
          positions[id] = defPos[id] ?? Offset.zero;
          scales[id] = defScale[id] ?? 1.0;
        }
      }
    }
    return (positions: positions, scales: scales);
  }

  /// fromDefault=true: デフォルト配置から編集開始 / false: 現在の配置から編集開始
  void _openFreeEditor(bool fromDefault) {
    final resolved = _resolveFreeLayout(fromDefault);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => FreeLayoutEditorPage(
          itemIds: _freeItemIds(),
          initialPositions: resolved.positions,
          initialScales: resolved.scales,
          previewOnly: !_isPremium,
          buildContent: _contentForId,
          isColorEditable: _isColorEditable,
          onColorTap: (id) async {
            final fallback = _fallbackColorsForId(id);
            final style = await _pickColorForId(ctx, id, fallback);
            if (style != null) {
              setState(() {
                _itemStyles = {..._itemStyles, id: style};
              });
              await _itemStyleStore.save(_itemStyles);
            }
          },
          isDeletable: _isDeletable,
          onDeleteItem: (id) {
            if (id.startsWith('memo_')) {
              setState(() {
                _memoIds = _memoIds.where((m) => m != id).toList();
                _memoTexts.remove(id);
              });
              _memoStore.saveIds(_memoIds);
              _memoStore.saveTexts(_memoTexts);
            } else if (id.startsWith('counter_')) {
              setState(() {
                _excludedFreeIds = {..._excludedFreeIds, id};
              });
              _layoutStore.saveExcluded(_excludedFreeIds);
            }
          },
          onItemDoubleTap: (id) async {
            if (!id.startsWith('memo_')) return;
            final controller =
                TextEditingController(text: _memoTexts[id] ?? '');
            final result = await showDialog<String>(
              context: ctx,
              builder: (dctx) => AlertDialog(
                title: const Text('メモを編集'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 5,
                  decoration: const InputDecoration(hintText: 'メモを入力...'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dctx),
                    child: const Text('キャンセル'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dctx, controller.text),
                    child: const Text('保存'),
                  ),
                ],
              ),
            );
            if (result != null) {
              setState(() {
                _memoTexts[id] = result;
              });
              await _memoStore.saveTexts(_memoTexts);
            }
          },
          onAddMemo: () async {
            final counter = await _memoStore.nextCounter();
            final id = 'memo_$counter';
            final order = _memoIds.length;
            setState(() {
              _memoIds = [..._memoIds, id];
              _memoTexts[id] = '';
            });
            await _memoStore.saveIds(_memoIds);
            await _memoStore.saveTexts(_memoTexts);
            return MapEntry(id, defaultMemoPosition(order));
          },
          onUpgrade: () {
            Navigator.pop(ctx);
            _openPremiumSheet();
          },
          onSave: (positions, scales) async {
            if (_isPremium) {
              setState(() {
                _freePositions = positions;
                _freeScales = scales;
                _layoutMode = 'free';
              });
              await _layoutStore.save(positions, scales);
              await _persist();
            }
            // プレミアム未加入の場合は保存しない（プレビューのみ）
          },
        ),
      ),
    );
  }

  // ---- 背景変更 ----

  void _openBackgroundSettings() {
    Navigator.pop(context); // close drawer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => BackgroundSettingsPage(
          initial: _background,
          isPremium: _isPremium,
          onSave: (setting) async {
            if (!_isPremium) return;
            setState(() => _background = setting);
            await _backgroundStore.save(setting);
          },
          onUpgrade: () {
            Navigator.pop(ctx);
            _openPremiumSheet();
          },
        ),
      ),
    );
  }

  // ---- 課金 ----

  Future<void> _openPremiumSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium,
                    size: 48, color: Color(0xFFFFA000)),
                const SizedBox(height: 12),
                const Text(
                  'Spin Counter プレミアム',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const SizedBox(height: 6),
                const Text(
                  'もっと自由に、もっと自分らしく。',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                const _PremiumFeatureRow(text: 'ボタンを自由な位置・サイズに配置できる'),
                const _PremiumFeatureRow(text: 'ボタンの色やグラデーションを自由にカスタマイズ'),
                const _PremiumFeatureRow(text: 'お好きな画像や配色で背景を変更できる'),
                const _PremiumFeatureRow(text: 'メモ帳ウィジェットを画面に追加できる'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      setState(() => _premiumType = 'onetime');
                      _persist();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('買い切りプランを購入しました！')),
                      );
                    },
                    child: const Text(
                      '買い切りプラン ¥4,800（一回のみ・永久利用）',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF7C4DFF)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      setState(() => _premiumType = 'monthly');
                      _persist();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('月額プランに登録しました！')),
                      );
                    },
                    child: const Text(
                      '月額プラン ¥300（毎月自動更新）',
                      style: TextStyle(fontSize: 15, color: Color(0xFF7C4DFF)),
                    ),
                  ),
                ),
                if (_isPremium)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton(
                      onPressed: () {
                        setState(() => _premiumType = 'none');
                        _persist();
                        Navigator.pop(ctx);
                      },
                      child: const Text('プレミアムを解除（テスト用）'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- フィードバック ----

  Future<void> _sendFeedback() async {
    Navigator.pop(context); // close drawer
    final uri = Uri(
      scheme: 'mailto',
      path: 'test@example.com',
      query: 'subject=${Uri.encodeComponent('Spin Counter フィードバック')}'
          '&body=${Uri.encodeComponent('ご意見・ご要望をご記入ください。\n\n')}',
    );
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メールアプリを起動できませんでした')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メールアプリを起動できませんでした')),
        );
      }
    }
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final useFreeLayout = _layoutMode == 'free' && _isPremium;

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: _buildDrawer(context),
      body: Container(
        decoration: _backgroundDecoration(),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context),
              Expanded(
                child:
                    useFreeLayout ? _buildFreeCanvas() : _buildFixedLayout(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _backgroundDecoration() {
    if (!_isPremium) {
      return const BoxDecoration(color: Color(0xFFF6F1FB));
    }
    switch (_background.mode) {
      case 'color':
        return BoxDecoration(
          color: _background.colors.isNotEmpty
              ? _background.colors[0]
              : const Color(0xFFF6F1FB),
        );
      case 'gradient':
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _background.colors.length >= 2
                ? _background.colors
                : const [Color(0xFFF6F1FB), Color(0xFFF6F1FB)],
          ),
        );
      case 'image':
        if (_background.imageBase64 != null) {
          return BoxDecoration(
            image: DecorationImage(
              image: MemoryImage(base64Decode(_background.imageBase64!)),
              fit: BoxFit.cover,
            ),
          );
        }
        return const BoxDecoration(color: Color(0xFFF6F1FB));
      default:
        return const BoxDecoration(color: Color(0xFFF6F1FB));
    }
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, size: 22),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'メニュー',
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ---- カラー解決 ----

  List<Color> _fallbackColorsForId(String id) {
    switch (id) {
      case 'play_btn':
        return const [Color(0xFF43A047), Color(0xFF43A047)];
      case 'stop_btn':
        return const [Color(0xFFE53935), Color(0xFFE53935)];
      case 'dec_100':
        return const [Color(0xFFFF7043), Color(0xFFFF7043)];
      case 'dec_10':
        return const [Color(0xFFFF8A65), Color(0xFFFF8A65)];
      case 'dec_1':
        return const [Color(0xFFFFAB91), Color(0xFFFFAB91)];
      case 'inc_100':
        return const [Color(0xFF7E57C2), Color(0xFF7E57C2)];
      case 'inc_10':
        return const [Color(0xFF9575CD), Color(0xFF9575CD)];
      case 'inc_1':
        return const [Color(0xFFB39DDB), Color(0xFFB39DDB)];
      case 'main_counter':
        return const [Color(0xFF9C6BFF), Color(0xFFEA80FC)];
      default:
        if (id.startsWith('counter_')) {
          final idx = int.parse(id.substring('counter_'.length));
          return _buttonColorSets[idx % _buttonColorSets.length];
        }
        return const [Color(0xFF7C4DFF), Color(0xFFB388FF)];
    }
  }

  List<Color> _resolvedColors(String id) {
    final style = _itemStyles[id];
    final fallback = _fallbackColorsForId(id);
    if (style == null) return fallback;
    return style.resolve(fallback);
  }

  // ---- 各アイテムのコンテンツ生成（固定/自由 共通） ----

  Widget _startBoxContent() {
    return LabeledBox(
      label: '開始ゲーム数',
      gradientColors: const [Color(0xFF7C4DFF), Color(0xFFB388FF)],
      width: ItemSizes.startBox.width,
      height: ItemSizes.startBox.height,
      child: _startEntered
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onStartBoxTapWhileLocked,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$_startCount',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.lock, color: Colors.white70, size: 15),
                ],
              ),
            )
          : TextField(
              controller: _startController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              onSubmitted: (_) => _confirmStartCount(),
              onEditingComplete: _confirmStartCount,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: '0',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              ),
            ),
    );
  }

  Widget _totalBoxContent() {
    return LabeledBox(
      label: 'Total',
      gradientColors: const [Color(0xFFFF7043), Color(0xFFFFAB91)],
      width: ItemSizes.totalBox.width,
      height: ItemSizes.totalBox.height,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$_total',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _playButtonContent() {
    return CircleIconButton(
      icon: Icons.play_arrow_rounded,
      colors: _isPlaying
          ? const [Color(0xFFBDBDBD), Color(0xFFBDBDBD)]
          : _resolvedColors('play_btn'),
      onPressed: _isPlaying ? null : _togglePlay,
      size: ItemSizes.playBtn.width,
    );
  }

  Widget _stopButtonContent() {
    return CircleIconButton(
      icon: Icons.stop_rounded,
      colors: !_isPlaying
          ? const [Color(0xFFBDBDBD), Color(0xFFBDBDBD)]
          : _resolvedColors('stop_btn'),
      onPressed: !_isPlaying ? null : _togglePlay,
      size: ItemSizes.stopBtn.width,
    );
  }

  Widget _lampButtonContent() {
    return GogoLampButton(
      onPressed: _onLampPressed,
      size: ItemSizes.lampBtn.width,
    );
  }

  Widget _adjustButtonContent(String id) {
    final colors = _resolvedColors(id);
    switch (id) {
      case 'dec_100':
        return AdjustButton(
            label: '-100', colors: colors, onPressed: () => _adjustMain(-100));
      case 'dec_10':
        return AdjustButton(
            label: '-10', colors: colors, onPressed: () => _adjustMain(-10));
      case 'dec_1':
        return AdjustButton(
            label: '-1', colors: colors, onPressed: () => _adjustMain(-1));
      case 'inc_100':
        return AdjustButton(
            label: '+100', colors: colors, onPressed: () => _adjustMain(100));
      case 'inc_10':
        return AdjustButton(
            label: '+10', colors: colors, onPressed: () => _adjustMain(10));
      default:
        return AdjustButton(
            label: '+1', colors: colors, onPressed: () => _adjustMain(1));
    }
  }

  Widget _mainCounterContent() {
    final colors = _resolvedColors('main_counter');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedPressable(
          onTap: _editMainCountDialog,
          pressedScale: 0.96,
          child: Container(
            width: ItemSizes.mainCounter.width,
            height: ItemSizes.mainCounter.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  '$_mainCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 48,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 22,
          child: _isPlaying
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _elapsedSeconds.toStringAsFixed(3),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7C4DFF),
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                )
              : null,
        ),
      ],
    );
  }

  static const _buttonColorSets = [
    [Color(0xFF7C4DFF), Color(0xFFB388FF)],
    [Color(0xFFEC407A), Color(0xFFF48FB1)],
    [Color(0xFFFFA726), Color(0xFFFFCC80)],
    [Color(0xFF26A69A), Color(0xFF80CBC4)],
    [Color(0xFFFF7043), Color(0xFFFFAB91)],
    [Color(0xFF66BB6A), Color(0xFFA5D6A7)],
    [Color(0xFF42A5F5), Color(0xFF90CAF9)],
    [Color(0xFFAB47BC), Color(0xFFCE93D8)],
    [Color(0xFFFFCA28), Color(0xFFFFE082)],
  ];

  Widget _counterButtonContent(int index) {
    return CounterButton(
      count: _buttonCounts[index],
      ratioText: _ratioText(index),
      gradientColors: _resolvedColors('counter_$index'),
      onPressed: () => _incrementButton(index),
    );
  }

  Widget _memoBoxContent(String id) {
    return MemoBox(
      key: ValueKey(id),
      initialText: _memoTexts[id] ?? '',
      width: ItemSizes.memoBox.width,
      height: ItemSizes.memoBox.height,
      onChanged: (text) {
        _memoTexts[id] = text;
        _memoStore.saveTexts(_memoTexts);
      },
    );
  }

  Widget _contentForId(String id) {
    if (id == 'start_box') return _startBoxContent();
    if (id == 'total_box') return _totalBoxContent();
    if (id == 'play_btn') return _playButtonContent();
    if (id == 'lamp_btn') return _lampButtonContent();
    if (id == 'stop_btn') return _stopButtonContent();
    if (id == 'main_counter') return _mainCounterContent();
    if (id.startsWith('memo_')) return _memoBoxContent(id);
    if (id.startsWith('counter_')) {
      final idx = int.parse(id.substring('counter_'.length));
      return _counterButtonContent(idx);
    }
    return _adjustButtonContent(id);
  }

  // ---- 固定レイアウト ----

  Widget _buildFixedLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 4),
          _buildStartAndTotalRow(),
          const SizedBox(height: 18),
          _buildControlRow(),
          const SizedBox(height: 14),
          _buildMainCounterRow(),
          const SizedBox(height: 20),
          _buildBottomGrid(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStartAndTotalRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 4,
          child: SizedBox(
            height: ItemSizes.startBox.height + 20,
            child: _startBoxContent(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 6,
          child: SizedBox(
            height: ItemSizes.totalBox.height + 20,
            child: _totalBoxContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildControlRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _playButtonContent(),
        const SizedBox(width: 20),
        _lampButtonContent(),
        const SizedBox(width: 20),
        _stopButtonContent(),
      ],
    );
  }

  Widget _buildMainCounterRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _adjustButtonContent('dec_100'),
            const SizedBox(height: 8),
            _adjustButtonContent('dec_10'),
            const SizedBox(height: 8),
            _adjustButtonContent('dec_1'),
          ],
        ),
        const SizedBox(width: 14),
        _mainCounterContent(),
        const SizedBox(width: 14),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _adjustButtonContent('inc_100'),
            const SizedBox(height: 8),
            _adjustButtonContent('inc_10'),
            const SizedBox(height: 8),
            _adjustButtonContent('inc_1'),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomGrid() {
    final count = _buttonLayout.clamp(1, kMaxCounterButtons);
    int crossAxisCount;
    if (count == 1) {
      crossAxisCount = 1;
    } else if (count == 2 || count == 4) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 3;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: count == 1 ? 2.4 : 1.05,
      ),
      itemBuilder: (context, index) => _counterButtonContent(index),
    );
  }

  // ---- 自由配置レイアウト（本番表示・プレミアムのみ） ----

  Widget _buildFreeCanvas() {
    // 保存されている配置に存在しないID（新規追加された下部ボタンやメモ帳など）は
    // デフォルト位置で補完して表示する（左上に固まる不具合を防止）。
    final resolved = _resolveFreeLayout(false);
    return FreeCanvas(
      itemIds: _freeItemIds(),
      positions: resolved.positions,
      scales: resolved.scales,
      editing: false,
      buildContent: _contentForId,
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFFEA80FC)],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.casino, color: Colors.white, size: 36),
                  SizedBox(height: 8),
                  Text(
                    'Spin Counter',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.grid_view_rounded),
              title: const Text('レイアウト変更'),
              onTap: _openLayoutSettings,
            ),
            ListTile(
              leading: Icon(
                Icons.wallpaper_outlined,
                color: _isPremium ? null : Colors.black38,
              ),
              title: Row(
                children: [
                  const Text('背景変更'),
                  if (!_isPremium) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.lock, size: 14, color: Colors.black38),
                  ],
                ],
              ),
              onTap: _openBackgroundSettings,
            ),
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('課金'),
              onTap: () {
                Navigator.pop(context);
                _openPremiumSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('フィードバック'),
              onTap: _sendFeedback,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title:
                  const Text('データクリア', style: TextStyle(color: Colors.red)),
              onTap: _confirmClearData,
            ),
            if (_isPremium)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _premiumType == 'onetime'
                          ? 'プレミアム会員（買い切り）'
                          : 'プレミアム会員（月額）',
                      style: const TextStyle(color: Colors.green),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PremiumFeatureRow extends StatelessWidget {
  final String text;
  const _PremiumFeatureRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle,
                color: Color(0xFF43A047), size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
