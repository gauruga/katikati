import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spin_counter/main.dart';
import 'package:spin_counter/widgets/counter_button.dart';

Future<void> _launch(WidgetTester tester, Map<String, Object> prefs) async {
  // 実機に近い縦長にしておく（メニューが縦に長いため）
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    'button_layout': 4,
    'counter_hint_shown': true,
    ...prefs,
  });
  await tester.pumpWidget(const SpinCounterApp());
  await tester.pumpAndSettle();
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();
}

int _countOf(WidgetTester tester, int index) =>
    tester.widget<CounterButton>(find.byType(CounterButton).at(index)).count;

void main() {
  testWidgets('非課金だとレイアウトの保存は課金シートへ誘導する', (tester) async {
    await _launch(tester, {'premium_type': 'none'});
    await _openMenu(tester);

    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'レイアウトの保存'),
        matching: find.text('プレミアム限定'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('レイアウトの保存'));
    await tester.pumpAndSettle();

    expect(find.text('小役カウンター プレミアム'), findsOneWidget);
    expect(find.text('今の配置を保存'), findsNothing);
  });

  testWidgets('メニューから保存でき、保存しても今の数字は変わらない', (tester) async {
    await _launch(tester, {
      'premium_type': 'onetime',
      'total': 120,
      'button_counts': ['7', '0', '0', '0'],
    });
    await _openMenu(tester);
    await tester.tap(find.text('レイアウトの保存'));
    await tester.pumpAndSettle();

    expect(find.text('まだ保存されていません。'), findsOneWidget);

    await tester.tap(find.text('今の配置を保存'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'ジャグラー');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    // 一覧に出る
    expect(find.text('ジャグラー'), findsOneWidget);
    // 保存しても数字は保持される
    expect(find.text('120'), findsOneWidget);
    expect(_countOf(tester, 0), 7);
  });

  testWidgets('呼び出しはカウンターをリセットするか確認する', (tester) async {
    await _launch(tester, {
      'premium_type': 'onetime',
      'total': 120,
      'button_counts': ['7', '0', '0', '0'],
    });
    await _openMenu(tester);
    await tester.tap(find.text('レイアウトの保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('今の配置を保存'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'ジャグラー');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    // 呼び出すと確認ダイアログが出る
    await tester.tap(find.text('ジャグラー'));
    await tester.pumpAndSettle();
    expect(find.text('「ジャグラー」を呼び出しますか？'), findsOneWidget);
    expect(find.text('そのまま'), findsOneWidget);
    expect(find.text('リセットする'), findsOneWidget);

    // 「そのまま」なら数字は残る
    await tester.tap(find.text('そのまま'));
    await tester.pumpAndSettle();
    expect(_countOf(tester, 0), 7);

    // 「リセットする」なら数字がゼロに戻る
    await _openMenu(tester);
    await tester.tap(find.text('レイアウトの保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ジャグラー'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('リセットする'));
    await tester.pumpAndSettle();

    expect(_countOf(tester, 0), 0);
    expect(find.text('120'), findsNothing);
  });
}
