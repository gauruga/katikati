import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spin_counter/main.dart';

Future<void> _openMenu(WidgetTester tester, {required bool premium}) async {
  SharedPreferences.setMockInitialValues({
    if (premium) 'premium_type': 'lifetime',
    'counter_hint_shown': true,
  });
  await tester.pumpWidget(const SpinCounterApp());
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('フィードバックの項目は出さない', (tester) async {
    await _openMenu(tester, premium: false);
    expect(find.text('フィードバック'), findsNothing);
  });

  testWidgets('非課金だと背景変更にもプレミアム限定と出る', (tester) async {
    await _openMenu(tester, premium: false);

    expect(find.text('背景変更'), findsOneWidget);
    // 他のプレミアム項目と同じ書き方で並ぶ
    expect(find.text('プレミアム限定'), findsNWidgets(3));
    final tile = tester.widget<ListTile>(
      find.ancestor(of: find.text('背景変更'), matching: find.byType(ListTile)),
    );
    expect((tile.subtitle as Text?)?.data, 'プレミアム限定');
  });

  testWidgets('課金済みなら背景変更に注記は出ない', (tester) async {
    await _openMenu(tester, premium: true);

    final tile = tester.widget<ListTile>(
      find.ancestor(of: find.text('背景変更'), matching: find.byType(ListTile)),
    );
    expect(tile.subtitle, isNull);
    expect(find.text('プレミアム限定'), findsNothing);
  });
}
