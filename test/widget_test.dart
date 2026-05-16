// Basic smoke test for Car Sharing shell.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('bottom navigation shell is shown', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Catalog'), findsWidgets);
    expect(find.text('Wallet'), findsOneWidget);
  });
}
