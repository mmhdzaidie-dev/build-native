import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ZEIA smoke test', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('ZEIA'))));
    expect(find.text('ZEIA'), findsOneWidget);
  });
}
