import 'package:shared_preferences/shared_preferences.dart';

import 'layout_positions.dart';

/// SharedPreferences を使った永続化ヘルパー。
class StateStore {
  static const _kStartCount = 'start_count';
  static const _kStartEntered = 'start_entered';
  static const _kMainCount = 'main_count';
  static const _kTotal = 'total';
  static const _kButtonCounts = 'button_counts';
  static const _kButtonLayout = 'button_layout';
  static const _kPremiumType = 'premium_type'; // none | lifetime | monthly
  static const _kLayoutMode = 'layout_mode'; // fixed | free
  // シンプル表示（開始ゲーム数・合計・再生／停止・ボーナスを隠す）
  static const _kSimpleLayout = 'simple_layout';
  // メインカウンタ下の経過秒数表示の濃さ（0.0=非表示 〜 1.0=くっきり）
  static const _kElapsedOpacity = 'elapsed_opacity';
  // 「下部ボタンは長押しで修正できる」ヒントを一度出したか
  static const _kCounterHintShown = 'counter_hint_shown';

  Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'startCount': prefs.getInt(_kStartCount) ?? 0,
      'startEntered': prefs.getBool(_kStartEntered) ?? false,
      'mainCount': prefs.getInt(_kMainCount) ?? 0,
      'total': prefs.getInt(_kTotal) ?? 0,
      'buttonCounts':
          (prefs.getStringList(_kButtonCounts) ??
                  List.filled(kMaxCounterButtons, '0'))
              .map((e) => int.tryParse(e) ?? 0)
              .toList(),
      'buttonLayout': prefs.getInt(_kButtonLayout) ?? 4,
      'premiumType': _premiumTypeOf(prefs.getString(_kPremiumType)),
      'layoutMode': prefs.getString(_kLayoutMode) ?? 'fixed',
      'simpleLayout': prefs.getBool(_kSimpleLayout) ?? false,
      'elapsedOpacity': (prefs.getDouble(_kElapsedOpacity) ?? 1.0).clamp(
        0.0,
        1.0,
      ),
    };
  }

  /// 買い切りプランは以前 'onetime' で保存していた。
  /// 商品IDを 'lifetime' に合わせたので、古い値はここで読み替える。
  static String _premiumTypeOf(String? stored) =>
      stored == null || stored.isEmpty
      ? 'none'
      : stored == 'onetime'
      ? 'lifetime'
      : stored;

  Future<void> save({
    required int startCount,
    required bool startEntered,
    required int mainCount,
    required int total,
    required List<int> buttonCounts,
    required int buttonLayout,
    required String premiumType,
    required String layoutMode,
    required bool simpleLayout,
    required double elapsedOpacity,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kStartCount, startCount);
    await prefs.setBool(_kStartEntered, startEntered);
    await prefs.setInt(_kMainCount, mainCount);
    await prefs.setInt(_kTotal, total);
    await prefs.setStringList(
      _kButtonCounts,
      buttonCounts.map((e) => e.toString()).toList(),
    );
    await prefs.setInt(_kButtonLayout, buttonLayout);
    await prefs.setString(_kPremiumType, premiumType);
    await prefs.setString(_kLayoutMode, layoutMode);
    await prefs.setBool(_kSimpleLayout, simpleLayout);
    await prefs.setDouble(_kElapsedOpacity, elapsedOpacity);
  }

  Future<bool> loadCounterHintShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kCounterHintShown) ?? false;
  }

  Future<void> markCounterHintShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCounterHintShown, true);
  }
}
