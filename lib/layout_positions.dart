import 'dart:convert';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';

/// 自由配置レイアウトの各アイテムのデフォルトサイズ定義（論理ピクセル）。
class ItemSizes {
  static const Size startBox = Size(150, 50);
  static const Size totalBox = Size(150, 50);
  static const Size playBtn = Size(64, 64);
  static const Size lampBtn = Size(76, 76);
  static const Size stopBtn = Size(64, 64);
  static const Size adjustBtn = Size(64, 44);
  static const Size mainCounter = Size(168, 168);
  static const Size counterBtn = Size(100, 100);
  static const Size memoBox = Size(200, 140);

  static Size forId(String id) {
    if (id == 'start_box') return startBox;
    if (id == 'total_box') return totalBox;
    if (id == 'play_btn') return playBtn;
    if (id == 'lamp_btn') return lampBtn;
    if (id == 'stop_btn') return stopBtn;
    if (id == 'main_counter') return mainCounter;
    if (id.startsWith('memo_')) return memoBox;
    if (id.startsWith('counter_')) return counterBtn;
    return adjustBtn; // dec_/inc_
  }
}

/// 参照キャンバスサイズ（デフォルト位置の計算基準）。
/// 元の（メモ帳機能追加前の）サイズ感に戻している。
const double kRefWidth = 380.0;
const double kRefHeight = 820.0;

const int kMaxCounterButtons = 9;
const double kMinScale = 0.6;
const double kMaxScale = 1.9;

/// 指定したボタン数に応じた下部カウントボタンの列数を返す。
/// 固定レイアウトのグリッド(1個=1列, 2or4個=2列, それ以外=3列)と揃える。
int colsForButtonCount(int buttonCount) {
  if (buttonCount <= 1) return 1;
  if (buttonCount == 2 || buttonCount == 4) return 2;
  return 3;
}

/// 常に最大数(9個)分のデフォルト位置を計算する。
/// buttonCount を渡すと、その個数に最適な列数（固定レイアウトと同じ規則）で
/// 下部カウントボタンを並べる（例: 4個なら2×2）。
/// （メモ帳は個数が可変のため、ここには含まれない。defaultMemoPosition() を使う）
Map<String, Offset> defaultPositions({int buttonCount = kMaxCounterButtons}) {
  final map = <String, Offset>{};

  map['start_box'] = const Offset(14 / kRefWidth, 10 / kRefHeight);
  map['total_box'] = const Offset(216 / kRefWidth, 10 / kRefHeight);

  map['play_btn'] = const Offset(58 / kRefWidth, 82 / kRefHeight);
  map['lamp_btn'] = const Offset(152 / kRefWidth, 78 / kRefHeight);
  map['stop_btn'] = const Offset(258 / kRefWidth, 82 / kRefHeight);

  map['dec_100'] = const Offset(8 / kRefWidth, 210 / kRefHeight);
  map['dec_10'] = const Offset(8 / kRefWidth, 262 / kRefHeight);
  map['dec_1'] = const Offset(8 / kRefWidth, 314 / kRefHeight);

  map['inc_100'] = const Offset(308 / kRefWidth, 210 / kRefHeight);
  map['inc_10'] = const Offset(308 / kRefWidth, 262 / kRefHeight);
  map['inc_1'] = const Offset(308 / kRefWidth, 314 / kRefHeight);

  map['main_counter'] = const Offset(106 / kRefWidth, 198 / kRefHeight);

  // 下部カウントボタン：固定レイアウトと同じ列数regelで配置し、
  // 列数が少ないほどボタンを大きくして良い感じのサイズ感にする（最初のバージョン相当）。
  final cols = colsForButtonCount(buttonCount);
  const gap = 10.0;
  // 3列基準(100px)を保ちつつ、列数が少ない場合は横幅いっぱいまでボタンを拡大する。
  final btnSize = ((kRefWidth - (cols - 1) * gap) / cols).clamp(100.0, 170.0);
  final totalW = cols * btnSize + (cols - 1) * gap;
  final startX = (kRefWidth - totalW) / 2;
  const startY = 410.0;

  for (int i = 0; i < kMaxCounterButtons; i++) {
    final col = i % cols;
    final row = i ~/ cols;
    final x = startX + col * (btnSize + gap);
    final y = startY + row * (btnSize + gap);
    map['counter_$i'] = Offset(x / kRefWidth, y / kRefHeight);
  }

  return map;
}

Map<String, double> defaultScales() {
  final map = <String, double>{};
  for (final id in [
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
    for (int i = 0; i < kMaxCounterButtons; i++) 'counter_$i',
  ]) {
    map[id] = 1.0;
  }
  return map;
}

/// メモ帳の追加順(order: 0,1,2,...)に応じたデフォルト配置。
/// 複数追加しても重なりすぎないよう少しずつずらす。
Offset defaultMemoPosition(int order) {
  final baseX = 60.0 + (order % 4) * 26;
  final baseY = 130.0 + (order % 4) * 26;
  return Offset(baseX / kRefWidth, baseY / kRefHeight);
}

const double defaultMemoScale = 1.0;

/// 指定した id のデフォルト位置／サイズ倍率を返す（静的アイテム用）。
/// メモ帳など可変IDのアイテムは呼び出し側で個別に解決する。
Offset? defaultPositionForId(String id) => defaultPositions()[id];
double defaultScaleForId(String id) => defaultScales()[id] ?? 1.0;

/// SharedPreferences を使った自由配置レイアウトの永続化（位置＋サイズ）。
/// メモ帳など動的なIDにも対応するため、保存されている内容をそのまま返す
/// （デフォルト値の補完は呼び出し側で行う）。
class LayoutStore {
  static const _key = 'free_layout_v4';

  Future<({Map<String, Offset> positions, Map<String, double> scales})>
      load() async {
    final positions = <String, Offset>{};
    final scales = <String, double>{};
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
          scales[id] = v.length >= 3 ? (v[2] as num).toDouble() : 1.0;
        }
      });
      return (positions: positions, scales: scales);
    } catch (_) {
      return (positions: positions, scales: scales);
    }
  }

  Future<void> save(
    Map<String, Offset> positions,
    Map<String, double> scales,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = <String, List<double>>{};
    positions.forEach((id, offset) {
      encoded[id] = [offset.dx, offset.dy, scales[id] ?? 1.0];
    });
    await prefs.setString(_key, jsonEncode(encoded));
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
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
Offset clampedPixelPosition(
  Offset fraction,
  Size canvasSize,
  Size itemSize,
) {
  final maxLeft =
      (canvasSize.width - itemSize.width).clamp(0.0, double.infinity);
  final maxTop =
      (canvasSize.height - itemSize.height).clamp(0.0, double.infinity);
  final left = (fraction.dx * canvasSize.width).clamp(0.0, maxLeft);
  final top = (fraction.dy * canvasSize.height).clamp(0.0, maxTop);
  return Offset(left, top);
}
