import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spin_counter/main.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const SpinCounterApp());
    await tester.pump();
    expect(find.byIcon(Icons.menu), findsOneWidget);
  });
}
