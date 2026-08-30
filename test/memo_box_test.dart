import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spin_counter/layout_positions.dart';
import 'package:spin_counter/style_stores.dart';
import 'package:spin_counter/widgets/memo_box.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('デフォルトサイズは本文6行が収まる高さ', (tester) async {
    // 6行 + タイトル行 + 余白 が ItemSizes.memoBox の高さに収まっていること。
    expect(ItemSizes.memoBox.height, greaterThanOrEqualTo(
      MemoBox.heightForLines(6),
    ));
    expect(ItemSizes.memoBox.height, lessThan(MemoBox.heightForLines(7)));
    expect(kDefaultMemoText.split('\n').length, 6);
  });

  testWidgets('タイトルを書き換えるとコールバックが呼ばれる', (tester) async {
    String? changed;
    await tester.pumpWidget(_wrap(MemoBox(
      initialText: kDefaultMemoText,
      initialTitle: kDefaultMemoTitle,
      onChanged: (_) {},
      onTitleChanged: (t) => changed = t,
      collapsed: false,
      onCollapsedChanged: (_) {},
      width: ItemSizes.memoBox.width,
      height: ItemSizes.memoBox.height,
    )));

    expect(find.text(kDefaultMemoTitle), findsOneWidget);
    await tester.enterText(find.text(kDefaultMemoTitle), '小役');
    expect(changed, '小役');
  });

  testWidgets('隠すボタンで本文が消え、展開すると戻る', (tester) async {
    bool collapsed = false;
    await tester.pumpWidget(_wrap(StatefulBuilder(
      builder: (context, setState) => MemoBox(
        initialText: kDefaultMemoText,
        initialTitle: kDefaultMemoTitle,
        onChanged: (_) {},
        onTitleChanged: (_) {},
        collapsed: collapsed,
        onCollapsedChanged: (v) => setState(() => collapsed = v),
        width: ItemSizes.memoBox.width,
        height: ItemSizes.memoBox.height,
      ),
    )));

    // 展開時は本文（デフォルトの6行）が表示されている
    expect(find.text(kDefaultMemoText), findsOneWidget);
    final expandedHeight = tester.getSize(find.byType(Container).first).height;

    await tester.tap(find.byIcon(Icons.expand_less));
    await tester.pumpAndSettle();

    expect(collapsed, isTrue);
    expect(find.text(kDefaultMemoText), findsNothing);
    expect(find.text(kDefaultMemoTitle), findsOneWidget);
    final collapsedHeight = tester.getSize(find.byType(Container).first).height;
    expect(collapsedHeight, lessThan(expandedHeight));

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    expect(collapsed, isFalse);
    expect(find.text(kDefaultMemoText), findsOneWidget);
  });
}
