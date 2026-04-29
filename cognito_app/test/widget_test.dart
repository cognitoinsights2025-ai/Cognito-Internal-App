import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cognito_app/main.dart';

void main() {
  testWidgets('App should render without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const CognitoApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
