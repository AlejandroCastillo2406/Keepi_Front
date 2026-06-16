import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepi/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App arranca sin errores', (WidgetTester tester) async {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost\n');
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(KeepiApp(prefs: prefs));
    // Deja transcurrir el tiempo mínimo de splash (1500 ms).
    await tester.pump(const Duration(milliseconds: 1600));

    expect(find.byType(MaterialApp), findsWidgets);
  });
}
