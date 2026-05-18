// Basic smoke test for the Crew app.

import 'package:flutter_test/flutter_test.dart';

import 'package:crew_app/main.dart';

void main() {
  testWidgets('App boots', (WidgetTester tester) async {
    await tester.pumpWidget(const CrewApp());
    expect(find.text('CREW'), findsWidgets);
  });
}
