import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spin_counter/billing.dart';
import 'package:spin_counter/main.dart';
import 'package:spin_counter/state_store.dart';

void main() {
  test('買い切りの保存値は古い onetime でも lifetime として読める', () async {
    SharedPreferences.setMockInitialValues({'premium_type': 'onetime'});
    expect((await StateStore().load())['premiumType'], 'lifetime');
  });

  test('保存値が無ければ none', () async {
    SharedPreferences.setMockInitialValues({});
    expect((await StateStore().load())['premiumType'], 'none');
  });

  test('商品IDと entitlement は RevenueCat の設定と揃えてある', () {
    expect(BillingService.entitlementId, 'spin_counter_pro');
    expect(BillingService.lifetimeId, 'lifetime');
    expect(BillingService.monthlyId, 'monthly');
  });

  testWidgets('買い切り済みならメニューに買い切りの契約状態が出る', (tester) async {
    SharedPreferences.setMockInitialValues({'premium_type': 'onetime'});
    await tester.pumpWidget(const SpinCounterApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // メニューは項目が多く、低い画面ではスクロールしないと最後まで出ない。
    await tester.dragUntilVisible(
      find.text('プレミアム会員（買い切り）'),
      find.byType(ListView),
      const Offset(0, -60),
    );
    await tester.pumpAndSettle();

    expect(find.text('プレミアム会員（買い切り）'), findsOneWidget);
  });

  testWidgets('ストアに繋がっていなければ課金はアプリ内のシートに戻る', (tester) async {
    SharedPreferences.setMockInitialValues({'premium_type': 'none'});
    await tester.pumpWidget(const SpinCounterApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    // ペイウォールも Customer Center も出せないので導線は隠す
    expect(find.text('ご契約の管理'), findsNothing);

    await tester.tap(find.text('課金'));
    await tester.pumpAndSettle();

    expect(find.text('小役カウンター プレミアム'), findsOneWidget);
    expect(find.textContaining('ストアに接続できていない'), findsOneWidget);
  });
}
