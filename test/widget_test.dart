import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localport/ui/theme.dart';

void main() {
  testWidgets('theme renders the product name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark),
        home: const Scaffold(body: Text('LocalPort')),
      ),
    );
    expect(find.text('LocalPort'), findsOneWidget);
  });
}
