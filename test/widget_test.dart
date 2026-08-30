import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spin_counter/main.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    // 保存済みデータの読み込みが終わるまでは読み込み中表示なので、
    // SharedPreferences をモックしてから待つ。
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SpinCounterApp());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.menu), findsOneWidget);
  });
}
