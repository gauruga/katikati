import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spin_counter/main.dart';
import 'package:spin_counter/widgets/counter_button.dart';

Future<void> _launch(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'button_layout': 4,
    'button_counts': ['0', '0', '0', '0'],
    'counter_hint_shown': true,
  });
  await tester.pumpWidget(const SpinCounterApp());
  await tester.pumpAndSettle();
}

Finder _flash() => find.byKey(const ValueKey('tap_flash'));

/// 指定したボタンの中の数字（大きい方の Text）を返す。
Text _countText(WidgetTester tester, int index, String value) {
  return tester.widget<Text>(
    find.descendant(
      of: find.byType(CounterButton).at(index),
      matching: find.text(value),
    ),
  );
}

void main() {
  testWidgets('押すと そのボタンの色で画面がフラッシュし、すぐ消える', (tester) async {
    await _launch(tester);

    // 何も押していないうちはフラッシュ層は出ていない
    expect(_flash(), findsNothing);

    // ボタン2（既定色は赤 #E53935）を押す
    await tester.tap(find.byType(CounterButton).at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    expect(_flash(), findsOneWidget);
    final box = tester.widget<ColoredBox>(_flash());
    expect(box.color.toARGB32() & 0x00FFFFFF, 0xE53935);
    expect(box.color.a, greaterThan(0.0));

    // 押しっぱなしにならず、短時間で消える
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(_flash(), findsNothing);
  });

  testWidgets('押したボタンの色でフラッシュする（ボタンごとに色が変わる）', (tester) async {
    await _launch(tester);

    // ボタン1 = 黄 #FFCA28
    await tester.tap(find.byType(CounterButton).at(0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(
      tester.widget<ColoredBox>(_flash()).color.toARGB32() & 0x00FFFFFF,
      0xFFCA28,
    );

    await tester.pumpAndSettle();

    // ボタン3 = 緑 #66BB6A
    await tester.tap(find.byType(CounterButton).at(2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(
      tester.widget<ColoredBox>(_flash()).color.toARGB32() & 0x00FFFFFF,
      0x66BB6A,
    );
  });

  testWidgets('押した直後は数字が発光し、収まると消える', (tester) async {
    await _launch(tester);

    // 押す前は影なし
    expect(_countText(tester, 0, '0').style?.shadows, isNull);

    await tester.tap(find.byType(CounterButton).at(0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    final glowing = _countText(tester, 0, '1').style?.shadows;
    expect(glowing, isNotNull);
    expect(glowing!, isNotEmpty);

    await tester.pumpAndSettle();
    expect(_countText(tester, 0, '1').style?.shadows, isNull);
  });

  testWidgets('フラッシュ層はタップを邪魔しない（連打できる）', (tester) async {
    await _launch(tester);

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byType(CounterButton).at(0));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();

    expect(
      tester.widget<CounterButton>(find.byType(CounterButton).first).count,
      5,
    );
  });
}
