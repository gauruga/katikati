import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spin_counter/layout_settings_page.dart';

class _Harness extends StatelessWidget {
  final ValueChanged<int> onButtonCountChanged;
  final void Function(bool fromDefault) onOpenFreeEditor;

  const _Harness({
    required this.onButtonCountChanged,
    required this.onOpenFreeEditor,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) => LayoutSettingsPage(
                    initialButtonCount: 3,
                    isPremium: true,
                    layoutMode: 'free',
                    onUseFixedLayout: () {},
                    onOpenFreeEditor: onOpenFreeEditor,
                    onButtonCountChanged: onButtonCountChanged,
                    onUpgrade: () {},
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openSettings(WidgetTester tester, Widget harness) async {
  await tester.pumpWidget(harness);
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('固定レイアウト: 数字を選んだだけでは反映せず、適用で反映してホームへ戻る', (tester) async {
    final applied = <int>[];
    await _openSettings(
      tester,
      _Harness(onButtonCountChanged: applied.add, onOpenFreeEditor: (_) {}),
    );

    await tester.tap(find.text('6'));
    await tester.pumpAndSettle();
    expect(applied, isEmpty); // 適用を押すまで反映しない

    await tester.tap(find.text('適用'));
    await tester.pumpAndSettle();
    expect(applied, [6]);
    expect(find.text('open'), findsOneWidget); // ホーム画面に戻る
  });

  testWidgets('自由配置: 今の配置から編集するは下部ボタン数の影響を受けない', (tester) async {
    final applied = <int>[];
    final opened = <bool>[];
    await _openSettings(
      tester,
      _Harness(onButtonCountChanged: applied.add, onOpenFreeEditor: opened.add),
    );

    await tester.tap(find.text('自由配置レイアウト'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('7'));
    await tester.pumpAndSettle();
    expect(applied, isEmpty);

    await tester.tap(find.text('今の配置から編集する'));
    await tester.pumpAndSettle();
    expect(applied, isEmpty); // ボタン数は変更されない
    expect(opened, [false]);
  });

  testWidgets('自由配置: デフォルト配置から編集するときだけ下部ボタン数を反映する', (tester) async {
    final applied = <int>[];
    final opened = <bool>[];
    await _openSettings(
      tester,
      _Harness(onButtonCountChanged: applied.add, onOpenFreeEditor: opened.add),
    );

    await tester.tap(find.text('自由配置レイアウト'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('7'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('デフォルト配置から編集する'));
    await tester.pumpAndSettle();

    expect(applied, [7]);
    expect(opened, [true]);
  });
}
