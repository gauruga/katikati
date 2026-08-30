import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spin_counter/free_layout_editor_page.dart';
import 'package:spin_counter/layout_positions.dart';

const _itemKey = ValueKey('item');

class _Harness extends StatelessWidget {
  final void Function(Map<String, Offset>, Map<String, ItemScale>) onSave;
  const _Harness({required this.onSave});

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
                  builder: (_) => FreeLayoutEditorPage(
                    itemIds: const ['counter_0'],
                    initialPositions: const {'counter_0': Offset(0.1, 0.1)},
                    initialScales: const {'counter_0': ItemScale.uniform(1.0)},
                    buildContent: (id, size) =>
                        const ColoredBox(key: _itemKey, color: Colors.blue),
                    previewOnly: false,
                    buttonCount: 1,
                    canvasSize: const Size(400, 800),
                    onSave: (p, s) async => onSave(p, s),
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

void main() {
  testWidgets('変更していなければ戻るボタンでそのまま閉じる', (tester) async {
    var saveCount = 0;
    await tester.pumpWidget(_Harness(onSave: (_, __) => saveCount++));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget); // 元の画面に戻っている
    expect(saveCount, 0);
  });

  testWidgets('編集後に戻るボタンを押すと破棄の確認が出る', (tester) async {
    var saveCount = 0;
    await tester.pumpWidget(_Harness(onSave: (_, __) => saveCount++));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // アイテムを動かす（＝編集あり）
    await tester.dragFrom(
      tester.getCenter(find.byKey(_itemKey)),
      const Offset(40, 40),
    );
    await tester.pumpAndSettle();
    expect(saveCount, 0); // 完了するまで保存されない

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('現在の編集が破棄されますが、よろしいですか？'), findsOneWidget);

    // 「編集を続ける」なら閉じない
    await tester.tap(find.text('編集を続ける'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    // 「破棄する」なら保存せずに閉じる
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('破棄する'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(saveCount, 0);
  });

  testWidgets('完了を押すと保存して閉じる', (tester) async {
    var saveCount = 0;
    Map<String, Offset>? savedPositions;
    await tester.pumpWidget(
      _Harness(
        onSave: (p, s) {
          saveCount++;
          savedPositions = p;
        },
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.dragFrom(
      tester.getCenter(find.byKey(_itemKey)),
      const Offset(40, 40),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('完了'));
    await tester.pumpAndSettle();

    expect(saveCount, 1);
    expect(savedPositions!['counter_0'], isNot(const Offset(0.1, 0.1)));
    expect(find.text('open'), findsOneWidget);
  });
}
