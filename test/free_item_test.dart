import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spin_counter/layout_positions.dart';
import 'package:spin_counter/widgets/free_item.dart';

Widget _wrap({
  required ItemScale scale,
  required ValueChanged<ItemScale> onScaleUpdate,
  Size canvas = const Size(400, 800),
  Size base = const Size(100, 100),
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: canvas.width,
        height: canvas.height,
        child: Stack(
          children: [
            FreeItem(
              fraction: const Offset(0.1, 0.1),
              scale: scale,
              canvasSize: canvas,
              baseItemSize: base,
              editing: true,
              onDragUpdate: (_) {},
              onScaleUpdate: onScaleUpdate,
              child: const ColoredBox(color: Colors.blue),
            ),
          ],
        ),
      ),
    ),
  );
}

/// タッチスロップぶんを先に消化してから、狙った距離だけドラッグする。
Future<void> _dragHandle(
    WidgetTester tester, IconData icon, Offset delta) async {
  final gesture = await tester.startGesture(tester.getCenter(find.byIcon(icon)));
  await gesture.moveBy(const Offset(kDragSlopDefault, kDragSlopDefault));
  await tester.pump();
  await gesture.moveBy(delta);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('横ハンドルのドラッグで横倍率だけが変わる', (tester) async {
    ItemScale? updated;
    await tester.pumpWidget(_wrap(
      scale: const ItemScale.uniform(1.0),
      onScaleUpdate: (s) => updated = s,
    ));

    await _dragHandle(tester, Icons.swap_horiz, const Offset(50, 0));

    expect(updated, isNotNull);
    // 基準幅100pxに対して+50px → 倍率は 1.0 → 1.5
    expect(updated!.x, closeTo(1.5, 0.01));
    expect(updated!.y, 1.0);
  });

  testWidgets('縦ハンドルのドラッグで縦倍率だけが変わる', (tester) async {
    ItemScale? updated;
    await tester.pumpWidget(_wrap(
      scale: const ItemScale.uniform(1.0),
      onScaleUpdate: (s) => updated = s,
    ));

    await _dragHandle(tester, Icons.swap_vert, const Offset(0, 80));

    expect(updated, isNotNull);
    expect(updated!.y, closeTo(1.8, 0.01));
    expect(updated!.x, 1.0);
  });

  testWidgets('右下ハンドルは縦横そろえて変わる', (tester) async {
    ItemScale? updated;
    await tester.pumpWidget(_wrap(
      scale: const ItemScale.uniform(1.0),
      onScaleUpdate: (s) => updated = s,
    ));

    await _dragHandle(tester, Icons.open_in_full, const Offset(40, 40));

    expect(updated, isNotNull);
    expect(updated!.x, closeTo(1.4, 0.01));
    expect(updated!.y, closeTo(1.4, 0.01));
  });

  test('自由配置のデフォルトは固定レイアウトと同じ並び', () {
    // 実際の画面サイズ（参照サイズとは違う）でも隙間なく敷き詰められること。
    const canvas = Size(411, 774);
    final positions = defaultPositions(canvas: canvas, buttonCount: 5);
    final scales = defaultScales(canvas: canvas, buttonCount: 5);
    final rows = bottomGridRows(5);
    expect(rows, [2, 3]);

    double widthOf(String id) => ItemSizes.forId(id).width * scales[id]!.x;
    double leftOf(String id) => positions[id]!.dx * canvas.width;

    // 1行目(2個)と2行目(3個)がそれぞれ画面幅いっぱいに広がっている
    final row1 = leftOf('counter_0') + widthOf('counter_0') +
        FixedLayout.gridGap + widthOf('counter_1');
    final row2 = leftOf('counter_2') +
        widthOf('counter_2') +
        FixedLayout.gridGap +
        widthOf('counter_3') +
        FixedLayout.gridGap +
        widthOf('counter_4');
    expect(row1, closeTo(canvas.width - FixedLayout.hPadding, 0.01));
    expect(row2, closeTo(canvas.width - FixedLayout.hPadding, 0.01));
    expect(leftOf('counter_0'), closeTo(FixedLayout.hPadding, 0.01));

    // 一番下の行が画面下端の余白ぴったりで終わる
    final lastBottom = positions['counter_4']!.dy * canvas.height +
        ItemSizes.forId('counter_4').height * scales['counter_4']!.y;
    expect(lastBottom, closeTo(canvas.height - FixedLayout.bottomGap, 0.01));

    // メインカウンタ等はそのままの大きさ（引き伸ばさない）
    expect(scales['main_counter']!.x, closeTo(1.0, 0.001));
    expect(scales['main_counter']!.y, closeTo(1.0, 0.001));
    expect(scales['play_btn']!.x, closeTo(1.0, 0.001));
  });
}
