import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pethotelbooking/core/theme/app_theme.dart';
import 'package:flutter_pethotelbooking/features/customer_screens/services_row.dart';
import 'package:flutter_pethotelbooking/models/add_on_model.dart';
import 'package:flutter_pethotelbooking/models/user_model.dart';
import 'package:flutter_pethotelbooking/providers/session_provider.dart';

/// Phase 0.5 confirmed-defect regression tests.
void main() {
  group('Defect #2: customer profile without cusID', () {
    UserModel user(UserRole role, String? cusID) =>
        UserModel(userID: 'u1', username: 'jaica', email: 'j@example.com', role: role, cusID: cusID);

    test('customer with a cusID listens to the customer record', () {
      expect(SessionProvider.nextStepFor(user(UserRole.customer, 'cus_1')), ProfileStep.listenCustomer);
    });
    test('customer with an empty or missing cusID goes to "profile missing" (not stuck loading)', () {
      expect(SessionProvider.nextStepFor(user(UserRole.customer, '')), ProfileStep.missing);
      expect(SessionProvider.nextStepFor(user(UserRole.customer, null)), ProfileStep.missing);
      expect(SessionProvider.nextStepFor(user(UserRole.customer, '   ')), ProfileStep.missing);
    });
    test('admin is ready immediately', () {
      expect(SessionProvider.nextStepFor(user(UserRole.admin, null)), ProfileStep.ready);
    });
  });

  group('Defect #3: Home add-on row on loading failure', () {
    testWidgets('shows an error card with Try again, and retry recovers', (tester) async {
      var calls = 0;
      Stream<List<AddOnModel>> factory() {
        calls++;
        if (calls == 1) return Stream.error(Exception('unavailable: network'));
        return Stream.value([AddOnModel(addOnID: 'a1', addOnName: 'Grooming', price: 350)]);
      }

      await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme(), home: Scaffold(body: ServicesRow(streamFactory: factory))));
      await tester.pump();
      expect(find.text('Services could not be loaded'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Services could not be loaded'), findsNothing);
      expect(find.text('Grooming'), findsOneWidget);
      expect(calls, 2);
    });

    testWidgets('no add-ons yet: row stays hidden (not an error)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(body: ServicesRow(streamFactory: () => Stream.value(const <AddOnModel>[]))),
      ));
      await tester.pump();
      expect(find.text('Services we offer'), findsNothing);
      expect(find.text('Services could not be loaded'), findsNothing);
    });
  });
}
