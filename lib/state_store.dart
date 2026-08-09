import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences を使った永続化ヘルパー。
class StateStore {
  static const _kStartCount = 'start_count';
  static const _kStartEntered = 'start_entered';
  static const _kMainCount = 'main_count';
  static const _kTotal = 'total';
  static const _kButtonCounts = 'button_counts';
  static const _kButtonLayout = 'button_layout';
  static const _kPremiumType = 'premium_type'; // none | onetime | monthly
  static const _kLayoutMode = 'layout_mode'; // fixed | free

  Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'startCount': prefs.getInt(_kStartCount) ?? 0,
      'startEntered': prefs.getBool(_kStartEntered) ?? false,
      'mainCount': prefs.getInt(_kMainCount) ?? 0,
      'total': prefs.getInt(_kTotal) ?? 0,
      'buttonCounts':
          (prefs.getStringList(_kButtonCounts) ?? List.filled(9, '0'))
              .map((e) => int.tryParse(e) ?? 0)
              .toList(),
      'buttonLayout': prefs.getInt(_kButtonLayout) ?? 4,
      'premiumType': prefs.getString(_kPremiumType) ?? 'none',
      'layoutMode': prefs.getString(_kLayoutMode) ?? 'fixed',
    };
  }

  Future<void> save({
    required int startCount,
    required bool startEntered,
    required int mainCount,
    required int total,
    required List<int> buttonCounts,
    required int buttonLayout,
    required String premiumType,
    required String layoutMode,
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
  }
}
