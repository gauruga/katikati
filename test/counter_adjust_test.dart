import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spin_counter/main.dart';
import 'package:spin_counter/widgets/counter_button.dart';

int _countOfFirstButton(WidgetTester tester) =>
    tester.widget<CounterButton>(find.byType(CounterButton).first).count;

Future<void> _launch(WidgetTester tester, {int first = 5}) async {
  SharedPreferences.setMockInitialValues({
    'button_layout': 4,
    'button_counts': ['$first', '0', '0', '0'],
    'total': 200,
    // ヒントのスナックバーが被らないように既読にしておく
    'counter_hint_shown': true,
  });
  await tester.pumpWidget(const SpinCounterApp());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('通常タップは今までどおり +1（パネルは開かない）', (tester) async {
    await _launch(tester);

    await tester.tap(find.byType(CounterButton).first);
    await tester.pumpAndSettle();

    expect(_countOfFirstButton(tester), 6);
    expect(find.text('小役確率'), findsNothing);
  });

  testWidgets('長押しの修正パネルから −1 できる', (tester) async {
    await _launch(tester);

    await tester.longPress(find.byType(CounterButton).first);
    await tester.pumpAndSettle();
    expect(find.text('小役確率'), findsOneWidget);
    expect(find.text('ボタン1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完了'));
    await tester.pumpAndSettle();

    expect(_countOfFirstButton(tester), 4);
  });

  testWidgets('0 のボタンは −1 も 0にリセットも押せない', (tester) async {
    await _launch(tester, first: 0);

    await tester.longPress(find.byType(CounterButton).first);
    await tester.pumpAndSettle();

    // マイナスを押しても 0 のまま（負の回数にはならない）
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsWidgets);

    final reset = tester.widget<TextButton>(
      find.ancestor(of: find.text('0にリセット'), matching: find.byType(TextButton)),
    );
    expect(reset.onPressed, isNull);

    await tester.tap(find.text('完了'));
    await tester.pumpAndSettle();
    expect(_countOfFirstButton(tester), 0);
  });

  testWidgets('0にリセットは確認してから実行される', (tester) async {
    await _launch(tester, first: 9);

    await tester.longPress(find.byType(CounterButton).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('0にリセット'));
    await tester.pumpAndSettle();
    expect(find.text('0に戻しますか？'), findsOneWidget);

    // キャンセルしたら変わらない
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(_countOfFirstButton(tester), 9);

    await tester.tap(find.text('0にリセット'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0に戻す'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完了'));
    await tester.pumpAndSettle();

    expect(_countOfFirstButton(tester), 0);
  });

  testWidgets('自由配置レイアウトでも長押しで修正できる', (tester) async {
    // 自由配置は画面の縦横比で並びが変わるので、実機に近い縦長にしておく
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      'button_layout': 4,
      'button_counts': ['5', '0', '0', '0'],
      'layout_mode': 'free',
      'premium_type': 'onetime',
      'counter_hint_shown': true,
    });
    await tester.pumpWidget(const SpinCounterApp());
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(CounterButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完了'));
    await tester.pumpAndSettle();

    expect(_countOfFirstButton(tester), 4);
  });

  testWidgets('初回のカウントだけ長押しヒントを出す', (tester) async {
    SharedPreferences.setMockInitialValues({
      'button_layout': 4,
      'button_counts': ['0', '0', '0', '0'],
    });
    await tester.pumpWidget(const SpinCounterApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CounterButton).first);
    await tester.pump();
    expect(find.textContaining('長押しすると回数を修正できます'), findsOneWidget);

    // 表示アニメーションを終わらせてから、自動で閉じるまで待つ
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.textContaining('長押しすると回数を修正できます'), findsNothing);

    // 2回目以降は出さない
    await tester.tap(find.byType(CounterButton).first);
    await tester.pump();
    expect(find.textContaining('長押しすると回数を修正できます'), findsNothing);
  });

  testWidgets('小役確率メモは課金済みなら設定1〜6の分母を編集できる', (tester) async {
    SharedPreferences.setMockInitialValues({
      'button_layout': 4,
      'button_counts': ['3', '0', '0', '0'],
      'premium_type': 'onetime',
      'counter_hint_shown': true,
      // 開始ゲーム数の入力欄が裏に残ると TextField の指定がぶれるのでロックしておく
      'start_entered': true,
      'start_count': 100,
    });
    await tester.pumpWidget(const SpinCounterApp());
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(CounterButton).first);
    await tester.pumpAndSettle();

    // 設定6〜設定1 の 6 枠が並ぶ
    for (final n in [1, 2, 3, 4, 5, 6]) {
      expect(find.text('設定$n'), findsOneWidget);
    }
    expect(find.text('1/'), findsNWidgets(6));
    // 削除した文言は出ない
    expect(find.textContaining('間違えて押してしまった分'), findsNothing);

    // メモ欄は 6 枠だけ（開始ゲーム数はロック済み）
    expect(find.byType(TextField), findsNWidgets(6));

    // 設定6（先頭の枠）に分母を入れる
    await tester.enterText(find.byType(TextField).first, '5.69');
    await tester.pumpAndSettle();

    await tester.tap(find.text('完了'));
    await tester.pumpAndSettle();

    // 開き直しても残っている
    await tester.longPress(find.byType(CounterButton).first);
    await tester.pumpAndSettle();
    expect(find.text('5.69'), findsOneWidget);
  });

  testWidgets('小役確率メモは非課金だと編集できず課金シートへ誘導する', (tester) async {
    SharedPreferences.setMockInitialValues({
      'button_layout': 4,
      'button_counts': ['3', '0', '0', '0'],
      'premium_type': 'none',
      'counter_hint_shown': true,
      'start_entered': true,
      'start_count': 100,
    });
    await tester.pumpWidget(const SpinCounterApp());
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(CounterButton).first);
    await tester.pumpAndSettle();

    expect(find.text('プレミアム限定'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).enabled,
      isFalse,
    );

    await tester.tap(find.text('小役確率'));
    await tester.pumpAndSettle();
    expect(find.text('小役カウンター プレミアム'), findsOneWidget);
  });
}
