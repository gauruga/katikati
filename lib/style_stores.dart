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

/// メモ帳（複数可）の内容保存。
/// 各メモは 'memo_0', 'memo_1', ... のような一意なIDで管理される。
class MemoStore {
  static const _idsKey = 'memo_ids_v1';
  static const _textsKey = 'memo_texts_v1';
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
    await prefs.remove(_counterKey);
  }
}
