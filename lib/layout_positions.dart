import 'dart:convert';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';

/// 自由配置レイアウトの各アイテムのデフォルトサイズ定義（論理ピクセル）。
class ItemSizes {
  static const Size startBox = Size(150, 70);
  static const Size totalBox = Size(150, 70);
  static const Size playBtn = Size(64, 64);
  static const Size lampBtn = Size(76, 76);
  static const Size stopBtn = Size(64, 64);
  static const Size adjustBtn = Size(64, 44);
  static const Size mainCounter = Size(168, 168);
  static const Size counterBtn = Size(100, 100);
  // メモ帳：縦は本文6行分、横はタイトル「メモ帳」がちょうど収まる幅。
  static const Size memoBox = Size(74, 144);

  /// 自由配置キャンバス上での実際の描画サイズ（付随する行を含む）。
  static Size forId(String id) {
    if (id == 'start_box') return startBox;
    if (id == 'total_box') return totalBox;
    if (id == 'play_btn') return playBtn;
    if (id == 'lamp_btn') return lampBtn;
    if (id == 'stop_btn') return stopBtn;
    // メインカウンタは円の下に経過秒数の行がぶら下がる。
    if (id == 'main_counter') {
      return Size(
        mainCounter.width,
        mainCounter.height + FixedLayout.elapsedHeight,
      );
    }
    if (id.startsWith('memo_')) return memoBox;
    if (id.startsWith('counter_')) return counterBtn;
    return adjustBtn; // dec_/inc_
  }
}

/// 固定レイアウトの余白・各段の高さ。
/// 自由配置レイアウトのデフォルト配置もここから計算するため、
/// 固定レイアウトと自由配置レイアウトの初期状態は同じ見た目になる。
class FixedLayout {
  static const double hPadding = 16;
  static const double topGap = 4;
  static const double startRowGap = 10; // 開始ゲーム数とTotalの間隔
  static const double gapAfterStart = 18;
  static const double controlGap = 20; // 再生／ランプ／停止の間隔
  static const double gapAfterControl = 14;
  static const double mainGap = 14; // 増減ボタン列とメインカウンタの間隔
  static const double adjustGap = 8; // 増減ボタン同士の間隔
  static const double elapsedHeight = 22; // メインカウンタ下の経過秒数の行
  static const double gapAfterMain = 20;
  static const double gridGap = 12; // 下部カウントボタン同士の間隔
  static const double bottomGap = 16;

  static double get startRowHeight => ItemSizes.startBox.height;
  static double get controlRowHeight => ItemSizes.lampBtn.height;
  static double get mainRowHeight =>
      ItemSizes.mainCounter.height + elapsedHeight;

  /// 下部グリッドより上の合計高さ。
  /// simple=true（シンプル表示）では開始ゲーム数／合計の段と
  /// 再生・ボーナス・停止の段を出さないので、その分だけ低くなる。
  static double topHeightFor(bool simple) =>
      topGap +
      (simple
          ? 0
          : startRowHeight +
                gapAfterStart +
                controlRowHeight +
                gapAfterControl) +
      mainRowHeight +
      gapAfterMain;

  static double get topHeight => topHeightFor(false);
}

/// アイテムの縦・横それぞれの拡大率。
class ItemScale {
  final double x;
  final double y;

  const ItemScale(this.x, this.y);
  const ItemScale.uniform(double v) : x = v, y = v;

  ItemScale copyWith({double? x, double? y}) =>
      ItemScale(x ?? this.x, y ?? this.y);

  @override
  bool operator ==(Object other) =>
      other is ItemScale && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// 参照キャンバスサイズ（デフォルト位置の計算基準）。
const double kRefWidth = 380.0;
const double kRefHeight = 820.0;

/// キャンバスサイズが分からないときの既定値。
const Size kRefCanvas = Size(kRefWidth, kRefHeight);

const int kMaxCounterButtons = 12;

/// シンプル表示（メニューのオン／オフ）で画面から取り払うアイテムのID。
/// 開始ゲーム数 / 合計 / 再生 / 停止 / ボーナス（ランプ）。
/// 空いた分だけ下部カウントボタンが大きくなり、個数も増やせる。
const Set<String> kSimpleHiddenIds = {
  'start_box',
  'total_box',
  'play_btn',
  'lamp_btn',
  'stop_btn',
};
const double kMinScale = 0.3;
const double kMaxScale = 5.0;

/// 指定したボタン数に応じた下部カウントボタンの列数を返す。
/// （自由配置レイアウトの互換用。現在の並びは bottomGridRows を参照）
int colsForButtonCount(int buttonCount) {
  if (buttonCount <= 1) return 1;
  if (buttonCount == 2 || buttonCount == 4) return 2;
  return 3;
}

/// 固定レイアウトの下部カウントボタンを「下画面いっぱい」に敷き詰めるための
/// 行構成を返す（各要素 = その行に並べるボタンの数）。
/// 行の高さは均等なので、1行あたりの個数が少ない行ほどボタンが大きくなる。
/// 例) 1個 → 特大1個 / 2個 → 横長2段 / 3個 → 上に横長1個＋下に2個 /
///     5個 → 上に大きめ2個＋下に3個
/// 10個以上はシンプル表示（上段を隠して縦を空ける）向けの並び。
List<int> bottomGridRows(int buttonCount) {
  switch (buttonCount.clamp(1, kMaxCounterButtons)) {
    case 1:
      return const [1];
    case 2:
      return const [1, 1];
    case 3:
      return const [1, 2];
    case 4:
      return const [2, 2];
    case 5:
      return const [2, 3];
    case 6:
      return const [3, 3];
    case 7:
      return const [2, 2, 3];
    case 8:
      return const [2, 3, 3];
    case 9:
      return const [3, 3, 3];
    case 10:
      return const [3, 3, 4];
    case 11:
      return const [3, 4, 4];
    default:
      return const [4, 4, 4];
  }
}

/// 指定サイズのキャンバス上で、固定レイアウトと全く同じ位置・大きさになる
/// 矩形を計算する。自由配置レイアウトのデフォルトはこれをそのまま使う。
/// simple=true（シンプル表示）では kSimpleHiddenIds のアイテムを含めず、
/// その段の高さも詰めるので、下部カウントボタンがその分だけ大きくなる。
Map<String, Rect> fixedLayoutRects(
  Size canvas,
  int buttonCount, {
  bool simple = false,
}) {
  final map = <String, Rect>{};
  const pad = FixedLayout.hPadding;
  final contentW = canvas.width - pad * 2;

  double y = FixedLayout.topGap;
  if (!simple) {
    // 開始ゲーム数 / Total（flex 4 : 6）
    final startW = (contentW - FixedLayout.startRowGap) * 0.4;
    final totalW = (contentW - FixedLayout.startRowGap) * 0.6;
    final startRowH = FixedLayout.startRowHeight;
    map['start_box'] = Rect.fromLTWH(pad, y, startW, startRowH);
    map['total_box'] = Rect.fromLTWH(
      pad + startW + FixedLayout.startRowGap,
      y,
      totalW,
      startRowH,
    );
    y += startRowH + FixedLayout.gapAfterStart;

    // 再生 / ランプ / 停止（中央寄せ）
    const play = ItemSizes.playBtn;
    const lamp = ItemSizes.lampBtn;
    const stop = ItemSizes.stopBtn;
    final controlH = FixedLayout.controlRowHeight;
    final controlW =
        play.width +
        FixedLayout.controlGap +
        lamp.width +
        FixedLayout.controlGap +
        stop.width;
    double x = (canvas.width - controlW) / 2;
    map['play_btn'] = Rect.fromLTWH(
      x,
      y + (controlH - play.height) / 2,
      play.width,
      play.height,
    );
    x += play.width + FixedLayout.controlGap;
    map['lamp_btn'] = Rect.fromLTWH(
      x,
      y + (controlH - lamp.height) / 2,
      lamp.width,
      lamp.height,
    );
    x += lamp.width + FixedLayout.controlGap;
    map['stop_btn'] = Rect.fromLTWH(
      x,
      y + (controlH - stop.height) / 2,
      stop.width,
      stop.height,
    );
    y += controlH + FixedLayout.gapAfterControl;
  }

  // 増減ボタン列 + メインカウンタ
  const adj = ItemSizes.adjustBtn;
  const main = ItemSizes.mainCounter;
  final mainRowH = FixedLayout.mainRowHeight;
  final adjColH = adj.height * 3 + FixedLayout.adjustGap * 2;
  final mainRowW =
      adj.width +
      FixedLayout.mainGap +
      main.width +
      FixedLayout.mainGap +
      adj.width;
  final leftX = (canvas.width - mainRowW) / 2;
  final rightX =
      leftX +
      adj.width +
      FixedLayout.mainGap +
      main.width +
      FixedLayout.mainGap;
  final adjY = y + (mainRowH - adjColH) / 2;
  const decIds = ['dec_100', 'dec_10', 'dec_1'];
  const incIds = ['inc_100', 'inc_10', 'inc_1'];
  for (int i = 0; i < 3; i++) {
    final ry = adjY + i * (adj.height + FixedLayout.adjustGap);
    map[decIds[i]] = Rect.fromLTWH(leftX, ry, adj.width, adj.height);
    map[incIds[i]] = Rect.fromLTWH(rightX, ry, adj.width, adj.height);
  }
  map['main_counter'] = Rect.fromLTWH(
    leftX + adj.width + FixedLayout.mainGap,
    y,
    main.width,
    mainRowH,
  );
  y += mainRowH + FixedLayout.gapAfterMain;

  // 下部カウントボタン（残りの高さを敷き詰める）
  final gridH = (canvas.height - y - FixedLayout.bottomGap).clamp(
    60.0,
    double.infinity,
  );
  _addGridRects(map, buttonCount, y, gridH, pad, contentW);
  if (buttonCount < kMaxCounterButtons) {
    // 非表示のボタンにも位置を用意しておく（個数を増やしたときに左上に固まらないように）
    final full = <String, Rect>{};
    _addGridRects(full, kMaxCounterButtons, y, gridH, pad, contentW);
    for (int i = buttonCount; i < kMaxCounterButtons; i++) {
      map['counter_$i'] = full['counter_$i']!;
    }
  }
  return map;
}

void _addGridRects(
  Map<String, Rect> map,
  int count,
  double top,
  double height,
  double pad,
  double contentW,
) {
  final rows = bottomGridRows(count);
  const gap = FixedLayout.gridGap;
  final rowH = (height - (rows.length - 1) * gap) / rows.length;
  int index = 0;
  for (int r = 0; r < rows.length; r++) {
    final n = rows[r];
    final cellW = (contentW - (n - 1) * gap) / n;
    final rowY = top + r * (rowH + gap);
    for (int c = 0; c < n; c++) {
      map['counter_$index'] = Rect.fromLTWH(
        pad + c * (cellW + gap),
        rowY,
        cellW,
        rowH,
      );
      index++;
    }
  }
}

/// 自由配置レイアウトのデフォルト位置（固定レイアウトと同じ配置）。
/// canvas には実際に描画するキャンバスサイズを渡す（固定レイアウトと
/// ピクセル単位で一致させるため）。
/// （メモ帳は個数が可変のため、ここには含まれない。defaultMemoPosition() を使う）
Map<String, Offset> defaultPositions({
  Size canvas = kRefCanvas,
  int buttonCount = kMaxCounterButtons,
  bool simple = false,
}) {
  return fixedLayoutRects(canvas, buttonCount, simple: simple).map(
    (id, r) =>
        MapEntry(id, Offset(r.left / canvas.width, r.top / canvas.height)),
  );
}

/// 自由配置レイアウトのデフォルトの縦横倍率（固定レイアウトと同じ大きさ）。
Map<String, ItemScale> defaultScales({
  Size canvas = kRefCanvas,
  int buttonCount = kMaxCounterButtons,
  bool simple = false,
}) {
  return fixedLayoutRects(canvas, buttonCount, simple: simple).map((id, r) {
    final base = ItemSizes.forId(id);
    return MapEntry(
      id,
      ItemScale(r.width / base.width, r.height / base.height),
    );
  });
}

/// メモ帳の追加順(order: 0,1,2,...)に応じたデフォルト配置。
/// 複数追加しても重なりすぎないよう少しずつずらす。
Offset defaultMemoPosition(int order) {
  final baseX = 60.0 + (order % 4) * 26;
  final baseY = 130.0 + (order % 4) * 26;
  return Offset(baseX / kRefWidth, baseY / kRefHeight);
}

const ItemScale defaultMemoScale = ItemScale.uniform(1.0);

/// 中身を引き伸ばす(Transform)のではなく、与えられたサイズに合わせて
/// 描き直すアイテムかどうか。文字がにじまず、固定レイアウトと同じ見た目になる。
bool stretchesToSize(String id) =>
    id == 'start_box' ||
    id == 'total_box' ||
    id.startsWith('counter_') ||
    id.startsWith('memo_');

/// 指定した id のデフォルト位置／サイズ倍率を返す（静的アイテム用）。
/// メモ帳など可変IDのアイテムは呼び出し側で個別に解決する。
Offset? defaultPositionForId(String id) => defaultPositions()[id];
ItemScale defaultScaleForId(String id) =>
    defaultScales()[id] ?? const ItemScale.uniform(1.0);

/// SharedPreferences を使った自由配置レイアウトの永続化（位置＋サイズ）。
/// メモ帳など動的なIDにも対応するため、保存されている内容をそのまま返す
/// （デフォルト値の補完は呼び出し側で行う）。
class LayoutStore {
  static const _key = 'free_layout_v4';

  Future<({Map<String, Offset> positions, Map<String, ItemScale> scales})>
  load() async {
    final positions = <String, Offset>{};
    final scales = <String, ItemScale>{};
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      return (positions: positions, scales: scales);
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      decoded.forEach((id, v) {
        if (v is List && v.length >= 2) {
          positions[id] = Offset(
            (v[0] as num).toDouble(),
            (v[1] as num).toDouble(),
          );
          // [dx, dy, scale] は旧形式（縦横共通の倍率）。
          final sx = v.length >= 3 ? (v[2] as num).toDouble() : 1.0;
          final sy = v.length >= 4 ? (v[3] as num).toDouble() : sx;
          scales[id] = ItemScale(sx, sy);
        }
      });
      return (positions: positions, scales: scales);
    } catch (_) {
      return (positions: positions, scales: scales);
    }
  }

  Future<void> save(
    Map<String, Offset> positions,
    Map<String, ItemScale> scales,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = <String, List<double>>{};
    positions.forEach((id, offset) {
      final scale = scales[id] ?? const ItemScale.uniform(1.0);
      encoded[id] = [offset.dx, offset.dy, scale.x, scale.y];
    });
    await prefs.setString(_key, jsonEncode(encoded));
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_buttonCountKey);
  }

  // ---- 保存した配置が「何個ボタン用」かを覚えておく ----
  // 個数が変わると下部ボタンの並び自体が変わるため、古い配置は作り直す。
  static const _buttonCountKey = 'free_layout_button_count';

  Future<int?> loadButtonCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_buttonCountKey);
  }

  Future<void> saveButtonCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_buttonCountKey, count);
  }

  // ---- 自由配置レイアウトから削除されたアイテムID一覧（下部ボタンなど） ----
  static const _excludedKey = 'free_layout_excluded_v1';

  Future<Set<String>> loadExcluded() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_excludedKey) ?? []).toSet();
  }

  Future<void> saveExcluded(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_excludedKey, ids.toList());
  }
}

/// FreeItem のクランプ済みピクセル位置を計算する共通ロジック。
Offset clampedPixelPosition(Offset fraction, Size canvasSize, Size itemSize) {
  final maxLeft = (canvasSize.width - itemSize.width).clamp(
    0.0,
    double.infinity,
  );
  final maxTop = (canvasSize.height - itemSize.height).clamp(
    0.0,
    double.infinity,
  );
  final left = (fraction.dx * canvasSize.width).clamp(0.0, maxLeft);
  final top = (fraction.dy * canvasSize.height).clamp(0.0, maxTop);
  return Offset(left, top);
}

/// 名前を付けて保存したレイアウト一式（呼び出して再現できる）。
class LayoutPreset {
  final String name;
  final Map<String, Offset> positions;
  final Map<String, ItemScale> scales;
  final int buttonCount;
  final List<String> memoIds;
  final Map<String, String> memoTitles;
  final Map<String, String> memoTexts;
  final List<String> memoCollapsed;
  final List<String> excludedIds;
  // 保存時にシンプル表示だったか（古い保存データには無いので既定 false）
  final bool simpleLayout;
  final int savedAt; // 保存日時（ミリ秒）

  const LayoutPreset({
    required this.name,
    required this.positions,
    required this.scales,
    required this.buttonCount,
    required this.memoIds,
    required this.memoTitles,
    required this.memoTexts,
    required this.memoCollapsed,
    required this.excludedIds,
    this.simpleLayout = false,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'items': {
      for (final id in positions.keys)
        id: [
          positions[id]!.dx,
          positions[id]!.dy,
          (scales[id] ?? const ItemScale.uniform(1.0)).x,
          (scales[id] ?? const ItemScale.uniform(1.0)).y,
        ],
    },
    'buttonCount': buttonCount,
    'memoIds': memoIds,
    'memoTitles': memoTitles,
    'memoTexts': memoTexts,
    'memoCollapsed': memoCollapsed,
    'excludedIds': excludedIds,
    'simpleLayout': simpleLayout,
    'savedAt': savedAt,
  };

  factory LayoutPreset.fromJson(Map<String, dynamic> json) {
    final positions = <String, Offset>{};
    final scales = <String, ItemScale>{};
    (json['items'] as Map<String, dynamic>? ?? {}).forEach((id, v) {
      if (v is List && v.length >= 2) {
        positions[id] = Offset(
          (v[0] as num).toDouble(),
          (v[1] as num).toDouble(),
        );
        final sx = v.length >= 3 ? (v[2] as num).toDouble() : 1.0;
        final sy = v.length >= 4 ? (v[3] as num).toDouble() : sx;
        scales[id] = ItemScale(sx, sy);
      }
    });
    Map<String, String> strMap(dynamic v) =>
        (v as Map<String, dynamic>? ?? {}).map((k, e) => MapEntry(k, '$e'));
    List<String> strList(dynamic v) =>
        (v as List<dynamic>? ?? []).map((e) => '$e').toList();
    return LayoutPreset(
      name: json['name'] as String? ?? '',
      positions: positions,
      scales: scales,
      buttonCount: (json['buttonCount'] as num?)?.toInt() ?? 4,
      memoIds: strList(json['memoIds']),
      memoTitles: strMap(json['memoTitles']),
      memoTexts: strMap(json['memoTexts']),
      memoCollapsed: strList(json['memoCollapsed']),
      excludedIds: strList(json['excludedIds']),
      simpleLayout: json['simpleLayout'] as bool? ?? false,
      savedAt: (json['savedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 名前付きレイアウトの保存／呼び出し。
class LayoutPresetStore {
  static const _key = 'layout_presets_v1';

  Future<List<LayoutPreset>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => LayoutPreset.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveAll(List<LayoutPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(presets.map((e) => e.toJson()).toList()),
    );
  }

  /// 同じ名前があれば上書きする。
  Future<List<LayoutPreset>> save(LayoutPreset preset) async {
    final presets = await load();
    final index = presets.indexWhere((p) => p.name == preset.name);
    if (index >= 0) {
      presets[index] = preset;
    } else {
      presets.add(preset);
    }
    await _saveAll(presets);
    return presets;
  }

  Future<List<LayoutPreset>> delete(String name) async {
    final presets = await load();
    presets.removeWhere((p) => p.name == name);
    await _saveAll(presets);
    return presets;
  }
}
