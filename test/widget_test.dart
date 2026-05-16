import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/app/car_sharing_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows login when no saved session', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const CarSharingApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Sign in'), findsWidgets);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
