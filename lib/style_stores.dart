import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 各アイテム（ボタンなど）のカスタムカラー/グラデーション設定。
class ItemStyle {
  final String mode; // 'default' | 'solid' | 'gradient'
  final List<Color> colors;

  const ItemStyle({this.mode = 'default', this.colors = const []});

  List<Color> resolve(List<Color> fallback) {
    if (mode == 'solid' && colors.isNotEmpty) {
      return [colors[0], colors[0]];
    }
    if (mode == 'gradient' && colors.length >= 2) {
      return [colors[0], colors[1]];
    }
    return fallback;
  }

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'colors': colors.map((c) => c.toARGB32()).toList(),
  };

  factory ItemStyle.fromJson(Map<String, dynamic> json) {
    return ItemStyle(
      mode: json['mode'] as String? ?? 'default',
      colors: (json['colors'] as List<dynamic>? ?? [])
          .map((v) => Color(v as int))
          .toList(),
    );
  }
}

class ItemStyleStore {
  static const _key = 'item_styles_v1';

  Future<Map<String, ItemStyle>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(k, ItemStyle.fromJson(v as Map<String, dynamic>)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> save(Map<String, ItemStyle> styles) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = styles.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_key, jsonEncode(encoded));
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// アプリ全体の背景設定（プレミアム限定）。
class BackgroundSetting {
  final String mode; // 'default' | 'color' | 'gradient' | 'image'
  final List<Color> colors;
  final String? imageBase64;

  const BackgroundSetting({
    this.mode = 'default',
    this.colors = const [],
    this.imageBase64,
  });

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'colors': colors.map((c) => c.toARGB32()).toList(),
    'imageBase64': imageBase64,
  };

  factory BackgroundSetting.fromJson(Map<String, dynamic> json) {
    return BackgroundSetting(
      mode: json['mode'] as String? ?? 'default',
      colors: (json['colors'] as List<dynamic>? ?? [])
          .map((v) => Color(v as int))
          .toList(),
      imageBase64: json['imageBase64'] as String?,
    );
  }
}

class BackgroundStore {
  static const _key = 'background_setting_v1';

  Future<BackgroundSetting> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const BackgroundSetting();
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return BackgroundSetting.fromJson(decoded);
    } catch (_) {
      return const BackgroundSetting();
    }
  }

  Future<void> save(BackgroundSetting setting) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(setting.toJson()));
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// メモ帳のデフォルトタイトル。
const String kDefaultMemoTitle = 'メモ帳';

/// メモ帳の初期内容（6行）。
const String kDefaultMemoText = '6 1/\n5 1/\n4 1/\n3 1/\n2 1/\n1 1/';

/// メモ帳（複数可）の内容保存。
/// 各メモは 'memo_0', 'memo_1', ... のような一意なIDで管理される。
class MemoStore {
  static const _idsKey = 'memo_ids_v1';
  static const _textsKey = 'memo_texts_v1';
  static const _titlesKey = 'memo_titles_v1';
  static const _collapsedKey = 'memo_collapsed_v1';
  static const _counterKey = 'memo_counter_v1';

  Future<List<String>> loadIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_idsKey) ?? [];
  }

  Future<void> saveIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_idsKey, ids);
  }

  Future<Map<String, String>> loadTexts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_textsKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveTexts(Map<String, String> texts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_textsKey, jsonEncode(texts));
  }

  Future<Map<String, String>> loadTitles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_titlesKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveTitles(Map<String, String> titles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_titlesKey, jsonEncode(titles));
  }

  /// 折りたたみ（隠す）状態のメモID一覧。
  Future<Set<String>> loadCollapsed() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_collapsedKey) ?? []).toSet();
  }

  Future<void> saveCollapsed(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_collapsedKey, ids.toList());
  }

  /// 新しいメモ用の一意な連番を返す（削除しても再利用しない）。
  Future<int> nextCounter() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_counterKey) ?? 0;
    await prefs.setInt(_counterKey, current + 1);
    return current;
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_idsKey);
    await prefs.remove(_textsKey);
    await prefs.remove(_titlesKey);
    await prefs.remove(_collapsedKey);
    await prefs.remove(_counterKey);
  }
}

/// 下部ボタンごとの小役確率メモ。
///
/// 「設定6 1/5.69」のように設定1〜6の枠は固定で、分母だけを持つ。
/// 値は入力されたままの文字列（'5.69' など）。未入力は空文字。
class CounterProbStore {
  static const _key = 'counter_probs_v1';

  /// 設定6→設定1 の 6 枠。
  static const slots = 6;

  Future<Map<String, List<String>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) {
        final list = (v as List<dynamic>).map((e) => e as String).toList();
        return MapEntry(k, normalize(list));
      });
    } catch (_) {
      return {};
    }
  }

  Future<void> save(Map<String, List<String>> probs) async {
    final prefs = await SharedPreferences.getInstance();
    // すべて空の行しかないボタンは保存しない（無駄なキーを残さない）
    final trimmed = <String, List<String>>{};
    probs.forEach((k, v) {
      if (v.any((e) => e.trim().isNotEmpty)) trimmed[k] = v;
    });
    await prefs.setString(_key, jsonEncode(trimmed));
  }

  /// 6 枠にそろえる（保存形式が変わっても壊れないように）。
  static List<String> normalize(List<String> values) {
    final out = List<String>.filled(slots, '');
    for (int i = 0; i < slots && i < values.length; i++) {
      out[i] = values[i];
    }
    return out;
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// 下部ボタンに付けた名前（'counter_0' → 'ベル' など）。
///
/// 未設定のボタンは持たない。表示側で「ボタンN」に読み替える。
class CounterNameStore {
  static const _key = 'counter_names_v1';

  Future<Map<String, String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, '$v'));
    } catch (_) {
      return {};
    }
  }

  Future<void> save(Map<String, String> names) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = <String, String>{};
    names.forEach((k, v) {
      if (v.trim().isNotEmpty) trimmed[k] = v.trim();
    });
    await prefs.setString(_key, jsonEncode(trimmed));
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
