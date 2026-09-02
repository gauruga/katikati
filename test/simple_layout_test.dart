import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spin_counter/gogo_lamp_button.dart';
import 'package:spin_counter/layout_positions.dart';
import 'package:spin_counter/main.dart';
import 'package:spin_counter/widgets/counter_button.dart';

Future<void> _launch(WidgetTester tester, {bool simple = false}) async {
  SharedPreferences.setMockInitialValues({
    'button_layout': 4,
    'counter_hint_shown': true,
    'simple_layout': simple,
  });
  await tester.pumpWidget(const SpinCounterApp());
  await tester.pumpAndSettle();
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();
}

/// シンプル表示で取り払われる5つが出ているか。
void _expectFullItems(Matcher matcher) {
  expect(find.text('開始ゲーム数'), matcher);
  expect(find.text('合計'), matcher);
  expect(find.byIcon(Icons.play_arrow_rounded), matcher);
  expect(find.byIcon(Icons.stop_rounded), matcher);
  expect(find.byType(GogoLampButton), matcher);
}

void main() {
  testWidgets('既定は今まで通りの表示（開始ゲーム数・合計・再生・停止・ボーナスが出る）', (tester) async {
    await _launch(tester);
    _expectFullItems(findsOneWidget);
    expect(find.byType(CounterButton), findsNWidgets(4));
  });

  testWidgets('メニューのシンプル表示をオンにすると5つが消え、オフで戻る', (tester) async {
    await _launch(tester);

    await _openMenu(tester);
    await tester.tap(find.text('シンプル表示'));
    await tester.pumpAndSettle();
    // ドロワーを閉じてホーム画面を確認する
    await tester.tapAt(const Offset(700, 300));
    await tester.pumpAndSettle();

    _expectFullItems(findsNothing);
    // カウントボタンと増減ボタン・メインカウンタは残る
    expect(find.byType(CounterButton), findsNWidgets(4));
    expect(find.text('+100'), findsOneWidget);
    expect(find.text('-100'), findsOneWidget);

    await _openMenu(tester);
    await tester.tap(find.text('シンプル表示'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(700, 300));
    await tester.pumpAndSettle();

    _expectFullItems(findsOneWidget);
  });

  testWidgets('シンプル表示は保存され、次の起動でも続く', (tester) async {
    await _launch(tester);

    await _openMenu(tester);
    await tester.tap(find.text('シンプル表示'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('simple_layout'), isTrue);

    // 保存済みの状態から起動し直しても消えたまま
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const SpinCounterApp());
    await tester.pumpAndSettle();
    _expectFullItems(findsNothing);
  });

  testWidgets('シンプル表示だとカウントボタンが縦に大きくなる', (tester) async {
    await _launch(tester);
    final normalHeight = tester
        .getSize(find.byType(CounterButton).first)
        .height;

    await _openMenu(tester);
    await tester.tap(find.text('シンプル表示'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(700, 300));
    await tester.pumpAndSettle();

    final simpleHeight = tester
        .getSize(find.byType(CounterButton).first)
        .height;
    expect(simpleHeight, greaterThan(normalHeight));
  });

  testWidgets('停止ボタンが消える前に、自動カウントは止まる', (tester) async {
    await _launch(tester);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();

    await _openMenu(tester);
    await tester.tap(find.text('シンプル表示'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(700, 300));
    await tester.pumpAndSettle();

    // タイマーが動いたままだと pumpAndSettle が終わらない／保留タイマーで落ちる。
    expect(find.byIcon(Icons.stop_rounded), findsNothing);
  });

  test('シンプル表示の既定配置には取り払う5つが含まれない', () {
    const canvas = Size(411, 774);
    final full = fixedLayoutRects(canvas, 4);
    final simple = fixedLayoutRects(canvas, 4, simple: true);

    for (final id in kSimpleHiddenIds) {
      expect(full.containsKey(id), isTrue, reason: id);
      expect(simple.containsKey(id), isFalse, reason: id);
    }
    // メインカウンタは上に詰められ、カウントボタンはその分だけ高くなる
    expect(simple['main_counter']!.top, lessThan(full['main_counter']!.top));
    expect(simple['counter_0']!.height, greaterThan(full['counter_0']!.height));
    // 一番下の余白は変わらない
    expect(
      simple['counter_3']!.bottom,
      closeTo(canvas.height - FixedLayout.bottomGap, 0.01),
    );
  });

  test('下部ボタンは12個まで並べられる', () {
    expect(kMaxCounterButtons, 12);
    for (int n = 1; n <= kMaxCounterButtons; n++) {
      final rows = bottomGridRows(n);
      expect(rows.fold<int>(0, (a, b) => a + b), n, reason: '$n個');
    }
    expect(bottomGridRows(12), [4, 4, 4]);
    // 上限を超えても最大の並びに丸められる
    expect(bottomGridRows(99), bottomGridRows(kMaxCounterButtons));
  });
}
