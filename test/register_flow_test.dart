import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pethotelbooking/core/theme/app_theme.dart';
import 'package:flutter_pethotelbooking/core/utils/ph_locations.dart';
import 'package:flutter_pethotelbooking/features/customer_screens/cus_auth.dart';

/// Two-step sign-up: personal info + address first, then the login details.
void main() {
  testWidgets('Step 1 blocks Next until personal info is valid; login fields are on step 2', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    // Load the bundled PSGC list for real (asset I/O) so the form is ready.
    await tester.runAsync(PhLocations.load);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme(), home: const RegisterScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 2 · Personal info'), findsOneWidget);
    // Login fields exist but are on the hidden second step.
    expect(find.text('Confirm password', skipOffstage: true), findsNothing);

    await tester.scrollUntilVisible(find.text('Next'), 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 2 · Personal info'), findsOneWidget);
    // Scroll back to the top of step 1 to see the first field's error.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(find.text('First name is required.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
