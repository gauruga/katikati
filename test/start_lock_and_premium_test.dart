import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spin_counter/main.dart';
import 'package:spin_counter/widgets/labeled_box.dart';

Finder _startBox() => find.byWidgetPredicate(
      (w) => w is LabeledBox && w.label == '開始ゲーム数',
    );

Future<void> _launch(WidgetTester tester, Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  await tester.pumpWidget(const SpinCounterApp());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('合計が1以上でも開始ゲーム数のロックは解除できる', (tester) async {
    await _launch(tester, {
      'start_count': 120,
      'start_entered': true,
      'total': 35,
    });

    await tester.tap(
      find.descendant(of: _startBox(), matching: find.byIcon(Icons.lock)),
    );
    await tester.pumpAndSettle();

    // 「変更できません」ではなく解除の確認を出す
    expect(find.text('ロックを解除しますか？'), findsOneWidget);
    expect(find.textContaining('変更できません'), findsNothing);
    // 合計が残ることの注意書きを添える
    expect(find.textContaining('合計（Total）はそのまま残ります'), findsOneWidget);

    await tester.tap(find.text('解除する'));
    await tester.pumpAndSettle();

    // 解除後は再入力できる
    expect(find.descendant(of: _startBox(), matching: find.byType(TextField)),
        findsOneWidget);
  });

  testWidgets('経過秒数の濃さは非課金だと課金シートに誘導される', (tester) async {
    await _launch(tester, {'premium_type': 'none'});

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('プレミアム限定'), findsOneWidget);

    await tester.tap(find.text('経過秒数の濃さ'));
    await tester.pumpAndSettle();

    expect(find.text('小役カウンター プレミアム'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('経過秒数の濃さは課金済みなら調整シートが開く', (tester) async {
    await _launch(tester, {'premium_type': 'onetime', 'elapsed_opacity': 0.5});

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('50%'), findsOneWidget);

    await tester.tap(find.text('経過秒数の濃さ'));
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('小役カウンター プレミアム'), findsNothing);
  });
}
