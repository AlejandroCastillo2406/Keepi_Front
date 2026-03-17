import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepi/main.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await tester.pumpWidget(const KeepiApp());
    expect(find.text('Keepi – listo para empezar'), findsOneWidget);
  });
}
