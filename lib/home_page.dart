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

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final _store = StateStore();
  final _layoutStore = LayoutStore();
  final _itemStyleStore = ItemStyleStore();
  final _backgroundStore = BackgroundStore();
  final _memoStore = MemoStore();
  final _presetStore = LayoutPresetStore();
  final _counterProbStore = CounterProbStore();
  final _counterNameStore = CounterNameStore();

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
  // 経過秒数表示の濃さ（0.0=非表示 〜 1.0=くっきり）
  double _elapsedOpacity = 1.0;
  Map<String, Offset> _freePositions = {};
  Map<String, ItemScale> _freeScales = {};
  Map<String, ItemStyle> _itemStyles = {};
  BackgroundSetting _background = const BackgroundSetting();
  List<String> _memoIds = [];
  Map<String, String> _memoTexts = {};
  Map<String, String> _memoTitles = {};
  Set<String> _memoCollapsed = {}; // 本文を隠しているメモのID
  Set<String> _excludedFreeIds = {}; // 自由配置レイアウトから削除された下部ボタンID
  List<LayoutPreset> _presets = []; // 名前を付けて保存したレイアウト
  // 実際の描画領域（デフォルト配置を固定レイアウトと一致させるために使う）
  Size? _canvasSize;
  Size get _canvas => _canvasSize ?? kRefCanvas;

  // ランプ誤操作の取り消し用
  int? _lastLampDiff;
  // 「下部ボタンは長押しで修正できる」ヒントを出したか
  bool _counterHintShown = false;
  // ボタンごとの小役確率メモ（'counter_0' → 設定6〜設定1 の分母）
  Map<String, List<String>> _counterProbs = {};
  // ボタンごとに付けた名前（'counter_0' → 'ベル' など）
  Map<String, String> _counterNames = {};

  Timer? _timer;
  Timer? _progressTimer;
  DateTime? _playStartedAt;
  double _elapsedSeconds = 0;

  final _startController = TextEditingController();

  // ---- 押したときの画面フラッシュ ----
  // 押したボタンの色で画面全体を一瞬染めて、反応があったことを分かりやすくする。
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1, // 起動直後に光らないよう、最初から終了状態にしておく
  );
  Color _flashColor = Colors.transparent;
  bool _loaded = false;

  static const _cycleMs = 4100;
  // 小役確率メモの変更検出用の区切り（入力に現れない文字）
  static const _sep = '\u0000';

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
    final memoTitles = await _memoStore.loadTitles();
    final memoCollapsed = await _memoStore.loadCollapsed();
    final excluded = await _layoutStore.loadExcluded();
    final presets = await _presetStore.load();
    final savedLayoutCount = await _layoutStore.loadButtonCount();
    final counterHintShown = await _store.loadCounterHintShown();
    final counterProbs = await _counterProbStore.load();
    final counterNames = await _counterNameStore.load();
    setState(() {
      _counterHintShown = counterHintShown;
      _counterProbs = counterProbs;
      _counterNames = counterNames;
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
      _elapsedOpacity = data['elapsedOpacity'];
      _freePositions = layout.positions;
      _freeScales = layout.scales;
      // 保存した配置と今のボタン数が食い違う場合は、下部ボタンだけ既定に戻す
      // （個数が変わると並び自体が変わるため）
      if (savedLayoutCount != _buttonLayout) {
        _freePositions.removeWhere((id, _) => id.startsWith('counter_'));
        _freeScales.removeWhere((id, _) => id.startsWith('counter_'));
      }
      _itemStyles = styles;
      _background = bg;
      _memoIds = memoIds;
      _memoTexts = memoTexts;
      _memoTitles = memoTitles;
      _memoCollapsed = memoCollapsed;
      _excludedFreeIds = excluded;
      _presets = presets;
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
      elapsedOpacity: _elapsedOpacity,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressTimer?.cancel();
    _startController.dispose();
    _flash.dispose();
    super.dispose();
  }

  // ---- ロジック ----

  /// 開始ゲーム数がロック状態か。
  /// 一度確定したら誤タップで書き換わらないようロックするだけで、
  /// タップすれば確認ダイアログから解除できる（完全ロックはしない）。
  bool get _startLocked => _startEntered;

  void _confirmStartCount() {
    if (_startLocked) return;
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
    // 合計が 1 以上でも解除は許可する。集計への影響は注意書きで伝えるだけ。
    final hasTotal = _total > 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ロックを解除しますか？'),
        content: Text(
          hasTotal
              ? '開始ゲーム数のロックを解除して、再入力できるようにします。\n\n'
                    '合計（Total）はそのまま残りますが、再入力すると'
                    '大きい数字が新しい開始ゲーム数にリセットされます。'
              : '開始ゲーム数のロックを解除して、再入力できるようにします。',
        ),
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

  /// メニューやレイアウト編集を開くときは、数字が進み続けないよう停止する。
  void _stopPlayIfNeeded() {
    if (_isPlaying) _stopPlay();
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
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => _TextInputDialog(
        title: '数字を編集',
        initial: '$_mainCount',
        confirmLabel: 'OK',
        numberOnly: true,
      ),
    );
    final result = text == null ? null : (int.tryParse(text) ?? 0);
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
    _flashColor = _resolvedColors('counter_$index').first;
    _flash.forward(from: 0);
    _persist();
    _showCounterHintOnce();
  }

  /// 「長押しで直せる」ことを最初のカウント時に一度だけ伝える。
  /// 押し間違いに気づいた人が直し方を探さずに済むようにする。
  void _showCounterHintOnce() {
    if (_counterHintShown) return;
    _markCounterHintShown();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('押し間違えたときは、ボタンを長押しすると回数を修正できます'),
        duration: Duration(seconds: 5),
      ),
    );
  }

  void _markCounterHintShown() {
    if (_counterHintShown) return;
    setState(() => _counterHintShown = true);
    _store.markCounterHintShown();
  }

  /// 下部ボタンの回数の修正パネル。
  /// 長押しでしか開かないので誤操作では出てこない。開いたあとは
  /// 大きめのボタンで素早く −1 できるようにしている。
  Future<void> _openCounterAdjustSheet(int index) async {
    _markCounterHintShown();
    final id = 'counter_$index';
    final before = _buttonCounts[index];
    final accent = _resolvedColors(id).first;

    // 小役確率メモ。設定1〜6の枠は固定で、分母だけを編集する。
    final probsBefore = CounterProbStore.normalize(
      _counterProbs[id] ?? const [],
    );
    // TextEditingController はシートを閉じるアニメーションの間も使われるので、
    // 入力欄側（_ProbMemoFields）に持たせて破棄まで任せる。
    final probs = List<String>.from(probsBefore);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true, // メモ入力でキーボードが出ても隠れないように
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            child: StatefulBuilder(
              builder: (ctx, setSheetState) {
                final count = _buttonCounts[index];

                void apply(int v) {
                  setSheetState(() {});
                  setState(() => _buttonCounts[index] = v.clamp(0, 1 << 31));
                }

                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildProbMemo(
                          ctx,
                          index,
                          accent,
                          probs,
                          () => setSheetState(() {}),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _RoundAdjustButton(
                              icon: Icons.remove,
                              color: accent,
                              onTap: count > 0 ? () => apply(count - 1) : null,
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w900,
                                    color: accent,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _ratioText(index),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            _RoundAdjustButton(
                              icon: Icons.add,
                              color: accent,
                              onTap: () => apply(count + 1),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                final v = await _promptCounterValue(ctx, count);
                                if (v != null) apply(v);
                              },
                              icon: const Icon(Icons.keyboard, size: 18),
                              label: const Text('直接入力'),
                            ),
                            TextButton.icon(
                              // 0 に戻すのは取り返しがつかないので確認を挟む
                              onPressed: count > 0
                                  ? () async {
                                      final ok = await _confirmCounterReset(
                                        ctx,
                                        index,
                                        count,
                                      );
                                      if (ok) apply(0);
                                    }
                                  : null,
                              icon: const Icon(Icons.restart_alt, size: 18),
                              label: const Text('0にリセット'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('完了'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (_buttonCounts[index] != before) await _persist();
    final trimmed = probs.map((v) => v.trim()).toList();
    if (_isPremium && trimmed.join(_sep) != probsBefore.join(_sep)) {
      setState(() => _counterProbs = {..._counterProbs, id: trimmed});
      await _counterProbStore.save(_counterProbs);
    }
  }

  /// 修正パネルの上に置く小役確率メモ（プレミアム限定）。
  /// 「設定6 1/5.69」のような並びで、分母だけを直接書き換えられる。
  Widget _buildProbMemo(
    BuildContext ctx,
    int index,
    Color accent,
    List<String> values,
    VoidCallback onRenamed,
  ) {
    final block = Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7DDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // 名前のチップ。課金中はタップで付け替えられる。
              GestureDetector(
                onTap: _isPremium
                    ? () async {
                        await _renameCounter(ctx, index);
                        onRenamed();
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 3, 6, 3),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _counterTitle(index),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_isPremium) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 11, color: Colors.white70),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  '小役確率',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              if (!_isPremium) ...[
                const Icon(Icons.lock, size: 13, color: Colors.black38),
                const SizedBox(width: 3),
                const Text(
                  'プレミアム限定',
                  style: TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          _ProbMemoFields(
            initial: values,
            enabled: _isPremium,
            onChanged: (slot, v) => values[slot] = v,
          ),
        ],
      ),
    );

    if (_isPremium) return block;
    // 非課金はタップで課金シートへ（入力欄自体は enabled:false で触れない）
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        _openPremiumSheet();
      },
      child: Opacity(opacity: 0.75, child: block),
    );
  }

  Future<int?> _promptCounterValue(BuildContext ctx, int current) async {
    final text = await showDialog<String>(
      context: ctx,
      builder: (dialogCtx) => _TextInputDialog(
        title: '回数を入力',
        initial: '$current',
        confirmLabel: '決定',
        numberOnly: true,
      ),
    );
    if (text == null) return null;
    return int.tryParse(text) ?? current;
  }

  Future<bool> _confirmCounterReset(
    BuildContext ctx,
    int index,
    int count,
  ) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('0に戻しますか？'),
        content: Text('${_counterTitle(index)} の回数（$count）を0に戻します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('0に戻す'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// ボタンに付けた名前。未設定なら null。
  String? _counterLabel(int index) {
    final v = _counterNames['counter_$index']?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  /// パネルの見出しなどで使う表示名。未設定なら「ボタンN」。
  String _counterTitle(int index) => _counterLabel(index) ?? 'ボタン${index + 1}';

  Future<void> _renameCounter(BuildContext ctx, int index) async {
    final input = await showDialog<String>(
      context: ctx,
      builder: (d) => _TextInputDialog(
        title: 'ボタンの名前',
        initial: _counterLabel(index) ?? '',
        hintText: 'ベル / チェリー など',
        confirmLabel: '決定',
      ),
    );
    if (input == null) return;
    final name = input.trim();
    final id = 'counter_$index';
    setState(() {
      _counterNames = {..._counterNames};
      if (name.isEmpty) {
        _counterNames.remove(id); // 空にしたら「ボタンN」に戻す
      } else {
        _counterNames[id] = name;
      }
    });
    await _counterNameStore.save(_counterNames);
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
    if (confirmed == true) _resetCounters();
  }

  /// 数字だけをゼロに戻す。レイアウトや色などの設定はそのまま残す。
  void _resetCounters() {
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

  // ---- 移動(レイアウト変更) ----

  void _openLayoutSettings() {
    _stopPlayIfNeeded();
    Navigator.pop(context); // close drawer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => LayoutSettingsPage(
          initialButtonCount: _buttonLayout,
          isPremium: _isPremium,
          layoutMode: _layoutMode,
          onUseFixedLayout: () {
            setState(() => _layoutMode = 'fixed');
            _persist();
          },
          onButtonCountChanged: (n) {
            setState(() {
              _buttonLayout = n;
              // 個数が変わると並び自体が変わるので、下部ボタンの配置は作り直す
              _freePositions.removeWhere((id, _) => id.startsWith('counter_'));
              _freeScales.removeWhere((id, _) => id.startsWith('counter_'));
            });
            _layoutStore.save(_freePositions, _freeScales);
            _layoutStore.saveButtonCount(n);
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
      for (int i = 0; i < _buttonLayout.clamp(1, kMaxCounterButtons); i++)
        if (!_excludedFreeIds.contains('counter_$i')) 'counter_$i',
      // メモ帳は他のボタンに隠れないよう最後（最前面）に描画する
      ..._memoIds,
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
    BuildContext context,
    String id,
    List<Color> fallback,
  ) async {
    final current = _itemStyles[id] ?? const ItemStyle();
    return ColorPickerSheet.show(context, current);
  }

  /// 自由配置レイアウトの初期位置／サイズを解決する。
  /// fromDefault=true の場合はデフォルト配置、false の場合は現在保存されている
  /// 配置（新規追加アイテムはデフォルト位置で補完）を返す。
  ({Map<String, Offset> positions, Map<String, ItemScale> scales})
  _resolveFreeLayout(bool fromDefault) {
    final ids = _freeItemIds();
    final count = _buttonLayout.clamp(1, kMaxCounterButtons);
    final defPos = defaultPositions(canvas: _canvas, buttonCount: count);
    final defScale = defaultScales(canvas: _canvas, buttonCount: count);
    final positions = <String, Offset>{};
    final scales = <String, ItemScale>{};
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
          scales[id] =
              _freeScales[id] ?? defScale[id] ?? const ItemScale.uniform(1.0);
        } else {
          positions[id] = defPos[id] ?? Offset.zero;
          scales[id] = defScale[id] ?? const ItemScale.uniform(1.0);
        }
      }
    }
    return (positions: positions, scales: scales);
  }

  /// fromDefault=true: デフォルト配置から編集開始 / false: 現在の配置から編集開始
  void _openFreeEditor(bool fromDefault) {
    _stopPlayIfNeeded();
    // 固定レイアウトを表示中なら「今の配置」＝固定レイアウトそのもの。
    // 以前に保存した自由配置が残っていても、そちらは使わない。
    final useDefault = fromDefault || _layoutMode != 'free' || !_isPremium;
    final resolved = _resolveFreeLayout(useDefault);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => FreeLayoutEditorPage(
          itemIds: _freeItemIds(),
          initialPositions: resolved.positions,
          initialScales: resolved.scales,
          previewOnly: !_isPremium,
          buttonCount: _buttonLayout.clamp(1, kMaxCounterButtons),
          canvasSize: _canvas,
          onSaveNamed: _isPremium ? _saveCurrentAsPreset : null,
          presetNames: _presets.map((e) => e.name).toList(),
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
                _memoTitles.remove(id);
                _memoCollapsed = {..._memoCollapsed}..remove(id);
              });
              _memoStore.saveIds(_memoIds);
              _memoStore.saveTexts(_memoTexts);
              _memoStore.saveTitles(_memoTitles);
              _memoStore.saveCollapsed(_memoCollapsed);
            } else if (id.startsWith('counter_')) {
              setState(() {
                _excludedFreeIds = {..._excludedFreeIds, id};
              });
              _layoutStore.saveExcluded(_excludedFreeIds);
            }
          },
          onItemDoubleTap: (id) async {
            if (!id.startsWith('memo_')) return;
            final titleController = TextEditingController(
              text: _memoTitles[id] ?? kDefaultMemoTitle,
            );
            final bodyController = TextEditingController(
              text: _memoTexts[id] ?? '',
            );
            final result = await showDialog<List<String>>(
              context: ctx,
              builder: (dctx) => AlertDialog(
                title: const Text('メモを編集'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'タイトル',
                        hintText: 'メモ帳',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bodyController,
                      autofocus: true,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: '本文',
                        hintText: 'メモを入力...',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dctx),
                    child: const Text('キャンセル'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dctx, [
                      titleController.text,
                      bodyController.text,
                    ]),
                    child: const Text('保存'),
                  ),
                ],
              ),
            );
            if (result != null) {
              setState(() {
                _memoTitles[id] = result[0];
                _memoTexts[id] = result[1];
              });
              await _memoStore.saveTitles(_memoTitles);
              await _memoStore.saveTexts(_memoTexts);
            }
          },
          onAddMemo: () async {
            final counter = await _memoStore.nextCounter();
            final id = 'memo_$counter';
            final order = _memoIds.length;
            setState(() {
              _memoIds = [..._memoIds, id];
              _memoTexts[id] = kDefaultMemoText;
              _memoTitles[id] = kDefaultMemoTitle;
            });
            await _memoStore.saveIds(_memoIds);
            await _memoStore.saveTexts(_memoTexts);
            await _memoStore.saveTitles(_memoTitles);
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
              await _layoutStore.saveButtonCount(_buttonLayout);
              await _persist();
            }
            // プレミアム未加入の場合は保存しない（プレビューのみ）
          },
        ),
      ),
    );
  }

  // ---- レイアウトの保存／呼び出し ----

  /// 現在の自由配置レイアウト一式に名前を付けて保存する。
  ///
  /// useResolved=true では、固定レイアウト中や未配置のアイテムがあっても
  /// 保存できるよう、既定位置で補完した配置を保存する（メニューからの保存用）。
  /// 保存しても今の画面の状態は変わらない。
  Future<void> _saveCurrentAsPreset(
    String name, {
    bool useResolved = false,
  }) async {
    final resolved = useResolved ? _resolveFreeLayout(false) : null;
    final preset = LayoutPreset(
      name: name,
      positions: Map.of(resolved?.positions ?? _freePositions),
      scales: Map.of(resolved?.scales ?? _freeScales),
      buttonCount: _buttonLayout,
      memoIds: List.of(_memoIds),
      memoTitles: Map.of(_memoTitles),
      memoTexts: Map.of(_memoTexts),
      memoCollapsed: _memoCollapsed.toList(),
      excludedIds: _excludedFreeIds.toList(),
      savedAt: DateTime.now().millisecondsSinceEpoch,
    );
    final presets = await _presetStore.save(preset);
    if (!mounted) return;
    setState(() => _presets = presets);
  }

  /// 保存したレイアウトを呼び出して反映する。
  Future<void> _applyPreset(LayoutPreset preset) async {
    setState(() {
      _freePositions = Map.of(preset.positions);
      _freeScales = Map.of(preset.scales);
      _buttonLayout = preset.buttonCount.clamp(1, kMaxCounterButtons);
      _memoIds = List.of(preset.memoIds);
      _memoTitles = Map.of(preset.memoTitles);
      _memoTexts = Map.of(preset.memoTexts);
      _memoCollapsed = preset.memoCollapsed.toSet();
      _excludedFreeIds = preset.excludedIds.toSet();
      _layoutMode = 'free';
    });
    await _layoutStore.save(_freePositions, _freeScales);
    await _layoutStore.saveButtonCount(_buttonLayout);
    await _layoutStore.saveExcluded(_excludedFreeIds);
    await _memoStore.saveIds(_memoIds);
    await _memoStore.saveTitles(_memoTitles);
    await _memoStore.saveTexts(_memoTexts);
    await _memoStore.saveCollapsed(_memoCollapsed);
    await _persist();
  }

  /// メニューから開くレイアウトの保存／呼び出し（プレミアム限定）。
  /// 配置・ボタン数・メモだけを扱い、カウンターの数字は保存しない。
  Future<void> _openPresetSheet() async {
    Navigator.pop(context); // close drawer
    if (!_isPremium) {
      await _openPremiumSheet();
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'レイアウトの保存 / 呼び出し',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '配置・ボタン数・メモを保存します。'
                        'カウンターの数字は保存されません。',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF7C4DFF),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          await _savePresetFromMenu(ctx);
                          setSheetState(() {});
                        },
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('今の配置を保存'),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        '保存したレイアウト',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_presets.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'まだ保存されていません。',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black38,
                            ),
                          ),
                        ),
                      for (final preset in _presets)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          color: const Color(0xFFF7F3FC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE7DDF5)),
                          ),
                          child: ListTile(
                            title: Text(
                              preset.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'ボタン${preset.buttonCount}個'
                              '${preset.memoIds.isEmpty ? '' : ' / メモ${preset.memoIds.length}個'}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.black45,
                              ),
                              onPressed: () async {
                                await _confirmDeletePreset(ctx, preset);
                                setSheetState(() {});
                              },
                            ),
                            onTap: () => _confirmApplyPreset(ctx, preset),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// メニューからの保存。名前を聞き、同名があれば上書き確認する。
  Future<void> _savePresetFromMenu(BuildContext ctx) async {
    final input = await showDialog<String>(
      context: ctx,
      builder: (d) => _TextInputDialog(
        title: '今の配置を保存',
        initial: 'レイアウト${_presets.length + 1}',
        hintText: '機種名など',
        confirmLabel: '保存',
      ),
    );
    final name = input?.trim();
    if (name == null || name.isEmpty) return;

    if (_presets.any((p) => p.name == name)) {
      if (!ctx.mounted) return;
      final overwrite = await showDialog<bool>(
        context: ctx,
        builder: (d) => AlertDialog(
          title: Text('「$name」を上書きしますか？'),
          content: const Text('同じ名前の保存があります。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('上書きする'),
            ),
          ],
        ),
      );
      if (overwrite != true) return;
    }

    await _saveCurrentAsPreset(name, useResolved: true);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('「$name」を保存しました')));
  }

  /// 呼び出し。数字をリセットするかどうかをここで確認する。
  Future<void> _confirmApplyPreset(
    BuildContext ctx,
    LayoutPreset preset,
  ) async {
    final choice = await showDialog<String>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: Text('「${preset.name}」を呼び出しますか？'),
        content: const Text(
          '配置・ボタン数・メモが保存した状態に戻ります。\n\n'
          'カウンターの数字（開始ゲーム数・大きい数字・合計・下部ボタン）は'
          'どうしますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, 'keep'),
            child: const Text('そのまま'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, 'reset'),
            child: const Text('リセットする'),
          ),
        ],
      ),
    );
    if (choice == null) return;

    _stopPlayIfNeeded();
    await _applyPreset(preset);
    if (choice == 'reset') _resetCounters();
    if (ctx.mounted) Navigator.pop(ctx); // close sheet
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('「${preset.name}」を呼び出しました')));
  }

  Future<void> _confirmDeletePreset(
    BuildContext ctx,
    LayoutPreset preset,
  ) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: Text('「${preset.name}」を削除しますか？'),
        content: const Text('この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final presets = await _presetStore.delete(preset.name);
    if (!mounted) return;
    setState(() => _presets = presets);
  }

  // ---- 背景変更 ----

  void _openBackgroundSettings() {
    _stopPlayIfNeeded();
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

  // ---- 経過秒数表示の濃さ ----

  static const Color _elapsedBaseColor = Color(0xFF7C4DFF);

  /// 実際に表示へ使う濃さ。濃さの調整はプレミアム限定なので、
  /// 非課金のときは保存値によらず既定（くっきり）で表示する。
  double get _effectiveElapsedOpacity => _isPremium ? _elapsedOpacity : 1.0;

  Color get _elapsedTextColor =>
      _elapsedBaseColor.withValues(alpha: _effectiveElapsedOpacity);

  Future<void> _openElapsedOpacitySheet() async {
    Navigator.pop(context); // close drawer
    if (!_isPremium) {
      await _openPremiumSheet();
      return;
    }
    final before = _elapsedOpacity;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              void update(double v) {
                setSheetState(() {});
                setState(() => _elapsedOpacity = v);
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '経過秒数の濃さ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '再生中に大きい数字の下に出る経過秒数（0.000〜4.100）の濃さを調整できます。'
                      '0%にすると表示されなくなります。',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F1FB),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '3.219',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _elapsedTextColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.opacity,
                          size: 18,
                          color: Colors.black45,
                        ),
                        Expanded(
                          child: Slider(
                            value: _elapsedOpacity,
                            min: 0,
                            max: 1,
                            divisions: 20,
                            activeColor: _elapsedBaseColor,
                            label: '${(_elapsedOpacity * 100).round()}%',
                            onChanged: update,
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          child: Text(
                            '${(_elapsedOpacity * 100).round()}%',
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => update(0),
                          child: const Text('非表示'),
                        ),
                        TextButton(
                          onPressed: () => update(0.3),
                          child: const Text('うすく'),
                        ),
                        TextButton(
                          onPressed: () => update(1),
                          child: const Text('くっきり'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _elapsedBaseColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('完了'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    if (_elapsedOpacity != before) await _persist();
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
        // 画面が低い端末でもはみ出さないようスクロールできるようにする。
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.workspace_premium,
                    size: 48,
                    color: Color(0xFFFFA000),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '小役カウンター プレミアム',
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
                  const _PremiumFeatureRow(
                    text: '経過秒数（0.000〜4.100）表示の濃さを調整できる',
                  ),
                  const _PremiumFeatureRow(text: 'ボタンごとに設定1〜6の小役確率をメモできる'),
                  const _PremiumFeatureRow(text: 'ボタンに「ベル」「チェリー」など名前を付けられる'),
                  const _PremiumFeatureRow(text: 'レイアウトを名前を付けて保存し、すぐ呼び出せる'),
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
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF7C4DFF),
                        ),
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
      query:
          'subject=${Uri.encodeComponent('小役カウンター フィードバック')}'
          '&body=${Uri.encodeComponent('ご意見・ご要望をご記入ください。\n\n')}',
    );
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('メールアプリを起動できませんでした')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('メールアプリを起動できませんでした')));
      }
    }
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final useFreeLayout = _layoutMode == 'free' && _isPremium;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.transparent,
          drawer: _buildDrawer(context),
          onDrawerChanged: (isOpened) {
            if (isOpened) _stopPlayIfNeeded();
          },
          body: Container(
            decoration: _backgroundDecoration(),
            child: SafeArea(
              child: Column(
                children: [
                  _buildTopBar(context),
                  Expanded(
                    child: useFreeLayout
                        ? _buildFreeCanvas()
                        : _buildFixedLayout(),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 連打を邪魔しないよう、タップは素通しさせる
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _flash,
              builder: (context, _) {
                final t = 1 - Curves.easeOut.transform(_flash.value);
                if (t <= 0.01) return const SizedBox.shrink();
                return ColoredBox(
                  key: const ValueKey('tap_flash'),
                  color: _flashColor.withValues(alpha: 0.26 * t),
                );
              },
            ),
          ),
        ),
      ],
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
      child: _startLocked
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
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
    );
  }

  Widget _totalBoxContent() {
    return LabeledBox(
      label: '合計',
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
          label: '-100',
          colors: colors,
          onPressed: () => _adjustMain(-100),
        );
      case 'dec_10':
        return AdjustButton(
          label: '-10',
          colors: colors,
          onPressed: () => _adjustMain(-10),
        );
      case 'dec_1':
        return AdjustButton(
          label: '-1',
          colors: colors,
          onPressed: () => _adjustMain(-1),
        );
      case 'inc_100':
        return AdjustButton(
          label: '+100',
          colors: colors,
          onPressed: () => _adjustMain(100),
        );
      case 'inc_10':
        return AdjustButton(
          label: '+10',
          colors: colors,
          onPressed: () => _adjustMain(10),
        );
      default:
        return AdjustButton(
          label: '+1',
          colors: colors,
          onPressed: () => _adjustMain(1),
        );
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
          height: FixedLayout.elapsedHeight,
          child: _isPlaying && _effectiveElapsedOpacity > 0
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _elapsedSeconds.toStringAsFixed(3),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _elapsedTextColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                )
              : null,
        ),
      ],
    );
  }

  /// 下部ボタンの既定色。小役の使用率が高い順に、その小役の色を割り当てる。
  /// （1:ベル=黄 2:チェリー=赤 3:スイカ=緑 4:チャンス目=紫）
  static const _buttonColorSets = [
    [Color(0xFFFFCA28), Color(0xFFFFE082)], // 黄 ベル
    [Color(0xFFE53935), Color(0xFFEF5350)], // 赤 チェリー
    [Color(0xFF66BB6A), Color(0xFFA5D6A7)], // 緑 スイカ
    [Color(0xFFAB47BC), Color(0xFFCE93D8)], // 紫 チャンス目
    [Color(0xFFFFA726), Color(0xFFFFCC80)], // オレンジ
    [Color(0xFF26A69A), Color(0xFF80CBC4)], // ティール
    [Color(0xFF7C4DFF), Color(0xFFB388FF)], // 濃紫
    [Color(0xFF42A5F5), Color(0xFF90CAF9)], // 青
    [Color(0xFFEC407A), Color(0xFFF48FB1)], // ピンク
  ];

  Widget _counterButtonContent(int index) {
    return CounterButton(
      count: _buttonCounts[index],
      ratioText: _ratioText(index),
      label: _counterLabel(index),
      gradientColors: _resolvedColors('counter_$index'),
      onPressed: () => _incrementButton(index),
      onLongPress: () => _openCounterAdjustSheet(index),
    );
  }

  Widget _memoBoxContent(String id, Size size) {
    return MemoBox(
      key: ValueKey(id),
      initialText: _memoTexts[id] ?? '',
      initialTitle: _memoTitles[id] ?? kDefaultMemoTitle,
      width: size.width,
      height: size.height,
      collapsed: _memoCollapsed.contains(id),
      onChanged: (text) {
        _memoTexts[id] = text;
        _memoStore.saveTexts(_memoTexts);
      },
      onTitleChanged: (title) {
        _memoTitles[id] = title;
        _memoStore.saveTitles(_memoTitles);
      },
      onCollapsedChanged: (collapsed) {
        final next = {..._memoCollapsed};
        if (collapsed) {
          next.add(id);
        } else {
          next.remove(id);
        }
        setState(() => _memoCollapsed = next);
        _memoStore.saveCollapsed(next);
      },
    );
  }

  Widget _contentForId(String id, Size size) {
    if (id == 'start_box') return _startBoxContent();
    if (id == 'total_box') return _totalBoxContent();
    if (id == 'play_btn') return _playButtonContent();
    if (id == 'lamp_btn') return _lampButtonContent();
    if (id == 'stop_btn') return _stopButtonContent();
    if (id == 'main_counter') return _mainCounterContent();
    if (id.startsWith('memo_')) return _memoBoxContent(id, size);
    if (id.startsWith('counter_')) {
      final idx = int.parse(id.substring('counter_'.length));
      return _counterButtonContent(idx);
    }
    return _adjustButtonContent(id);
  }

  // ---- 固定レイアウト ----

  Widget _buildFixedLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        final rows = bottomGridRows(_buttonLayout);
        // 画面が低すぎる場合だけスクロールできるよう、最低限の高さは確保する。
        final minGridHeight =
            rows.length * 84 + (rows.length - 1) * FixedLayout.gridGap;
        final rest =
            constraints.maxHeight -
            FixedLayout.topHeight -
            FixedLayout.bottomGap;
        final gridHeight = rest > minGridHeight ? rest : minGridHeight;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: FixedLayout.hPadding),
          child: Column(
            children: [
              const SizedBox(height: FixedLayout.topGap),
              SizedBox(
                height: FixedLayout.startRowHeight,
                child: _buildStartAndTotalRow(),
              ),
              const SizedBox(height: FixedLayout.gapAfterStart),
              SizedBox(
                height: FixedLayout.controlRowHeight,
                child: _buildControlRow(),
              ),
              const SizedBox(height: FixedLayout.gapAfterControl),
              SizedBox(
                height: FixedLayout.mainRowHeight,
                child: _buildMainCounterRow(),
              ),
              const SizedBox(height: FixedLayout.gapAfterMain),
              SizedBox(height: gridHeight, child: _buildBottomGrid(rows)),
              const SizedBox(height: FixedLayout.bottomGap),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStartAndTotalRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 4,
          child: SizedBox(
            height: ItemSizes.startBox.height,
            child: _startBoxContent(),
          ),
        ),
        const SizedBox(width: FixedLayout.startRowGap),
        Expanded(
          flex: 6,
          child: SizedBox(
            height: ItemSizes.totalBox.height,
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
        const SizedBox(width: FixedLayout.controlGap),
        _lampButtonContent(),
        const SizedBox(width: FixedLayout.controlGap),
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
            const SizedBox(height: FixedLayout.adjustGap),
            _adjustButtonContent('dec_10'),
            const SizedBox(height: FixedLayout.adjustGap),
            _adjustButtonContent('dec_1'),
          ],
        ),
        const SizedBox(width: FixedLayout.mainGap),
        _mainCounterContent(),
        const SizedBox(width: FixedLayout.mainGap),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _adjustButtonContent('inc_100'),
            const SizedBox(height: FixedLayout.adjustGap),
            _adjustButtonContent('inc_10'),
            const SizedBox(height: FixedLayout.adjustGap),
            _adjustButtonContent('inc_1'),
          ],
        ),
      ],
    );
  }

  /// 下部カウントボタン。個数に応じた行構成（bottomGridRows）で、
  /// 与えられた領域の幅・高さを余さず使い切るように敷き詰める。
  Widget _buildBottomGrid(List<int> rows) {
    final children = <Widget>[];
    int index = 0;
    for (int r = 0; r < rows.length; r++) {
      if (r > 0) children.add(const SizedBox(height: FixedLayout.gridGap));
      final cells = <Widget>[];
      for (int c = 0; c < rows[r]; c++) {
        if (c > 0) cells.add(const SizedBox(width: FixedLayout.gridGap));
        cells.add(Expanded(child: _counterButtonContent(index)));
        index++;
      }
      children.add(Expanded(child: Row(children: cells)));
    }
    return Column(children: children);
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
      onCanvasSize: (size) => _canvasSize = size,
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
                    '小役カウンター',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              // 項目が増えても低い画面で溢れないようにスクロールさせる。
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.grid_view_rounded),
                    title: const Text('レイアウト変更'),
                    onTap: _openLayoutSettings,
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.bookmark_outline,
                      color: _isPremium ? null : Colors.black38,
                    ),
                    title: Row(
                      children: [
                        const Text('レイアウトの保存'),
                        if (!_isPremium) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.lock,
                            size: 14,
                            color: Colors.black38,
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      !_isPremium
                          ? 'プレミアム限定'
                          : _presets.isEmpty
                          ? 'まだ保存なし'
                          : '保存 ${_presets.length} 件',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: _openPresetSheet,
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
                          const Icon(
                            Icons.lock,
                            size: 14,
                            color: Colors.black38,
                          ),
                        ],
                      ],
                    ),
                    onTap: _openBackgroundSettings,
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.timer_outlined,
                      color: _isPremium ? null : Colors.black38,
                    ),
                    title: Row(
                      children: [
                        const Text('経過秒数の濃さ'),
                        if (!_isPremium) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.lock,
                            size: 14,
                            color: Colors.black38,
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      !_isPremium
                          ? 'プレミアム限定'
                          : _elapsedOpacity <= 0
                          ? '非表示'
                          : '${(_elapsedOpacity * 100).round()}%',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: _openElapsedOpacitySheet,
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
                    leading: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'データクリア',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: _confirmClearData,
                  ),
                  if (_isPremium)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 18,
                          ),
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
          ],
        ),
      ),
    );
  }
}

/// テキストを1行入力するダイアログ。
///
/// TextEditingController は閉じるアニメーションが終わるまで使われるため、
/// 呼び出し側で await 直後に dispose すると「used after being disposed」に
/// なる。コントローラはこのウィジェットが持って破棄する。
class _TextInputDialog extends StatefulWidget {
  final String title;
  final String initial;
  final String confirmLabel;
  final String? hintText;

  /// 数字だけを受け付け、大きく中央寄せで表示する。
  final bool numberOnly;

  const _TextInputDialog({
    required this.title,
    required this.initial,
    required this.confirmLabel,
    this.hintText,
    this.numberOnly = false,
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: widget.numberOnly ? null : 20,
        keyboardType: widget.numberOnly ? TextInputType.number : null,
        inputFormatters: widget.numberOnly
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        textAlign: widget.numberOnly ? TextAlign.center : TextAlign.start,
        style: widget.numberOnly
            ? const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)
            : null,
        decoration: InputDecoration(hintText: widget.hintText, counterText: ''),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// 小役確率メモの入力欄（設定6〜設定1 の 6 枠）。
///
/// TextEditingController はシートを閉じるアニメーションが終わるまで使われるため、
/// 呼び出し側ではなくこのウィジェットが持って dispose まで面倒を見る。
class _ProbMemoFields extends StatefulWidget {
  final List<String> initial;
  final bool enabled;
  final void Function(int slot, String value) onChanged;

  const _ProbMemoFields({
    required this.initial,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_ProbMemoFields> createState() => _ProbMemoFieldsState();
}

class _ProbMemoFieldsState extends State<_ProbMemoFields> {
  late final List<TextEditingController> _controllers = [
    for (final v in widget.initial) TextEditingController(text: v),
  ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _row(int slot) {
    final setting = CounterProbStore.slots - slot; // 0 → 設定6
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '設定$setting',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          const Text(
            '1/',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          Expanded(
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: _controllers[slot],
                enabled: widget.enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                onChanged: (v) => widget.onChanged(slot, v),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  hintText: '—',
                  hintStyle: const TextStyle(color: Colors.black26),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: [_row(0), _row(1), _row(2)])),
        const SizedBox(width: 10),
        Expanded(child: Column(children: [_row(3), _row(4), _row(5)])),
      ],
    );
  }
}

/// 修正パネルの −／＋ 。長押しで開いた先なので、指で狙いやすい大きさにする。
class _RoundAdjustButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _RoundAdjustButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return AnimatedPressable(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? color : Colors.black12,
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : Colors.black26,
          size: 30,
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
            child: Icon(Icons.check_circle, color: Color(0xFF43A047), size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
