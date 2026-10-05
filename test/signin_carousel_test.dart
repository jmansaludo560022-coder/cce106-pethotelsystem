import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pethotelbooking/core/theme/app_theme.dart';
import 'package:flutter_pethotelbooking/features/customer_screens/cus_auth.dart';
import 'package:flutter_pethotelbooking/features/customer_screens/landing_screen.dart';

/// Sign-in order (email first, Google as the alternative below) and the
/// carousel's photo circles.
void main() {
  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('Sign-in order: Email, Password, Forgot, Sign in, "or continue with", Google, Sign up', (tester) async {
    await phone(tester);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme(), home: const LoginScreen()));
    await tester.pumpAndSettle();

    double top(Finder f) {
      expect(f, findsOneWidget);
      return tester.getTopLeft(f).dy;
    }

    final email = top(find.widgetWithText(TextFormField, 'Email'));
    final password = top(find.widgetWithText(TextFormField, 'Password'));
    final forgot = top(find.text('Forgot password?'));
    final signIn = top(find.text('Sign in'));
    final divider = top(find.text('or continue with'));
    final google = top(find.text('Continue with Google'));
    final signUp = top(find.text('Sign up'));

    expect(email < password, isTrue);
    expect(password < forgot, isTrue);
    expect(forgot < signIn, isTrue);
    expect(signIn < divider, isTrue);
    expect(divider < google, isTrue);
    expect(google < signUp, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sign-in fits a phone without scrolling', (tester) async {
    await phone(tester);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme(), home: const LoginScreen()));
    await tester.pumpAndSettle();
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(tester.getBottomLeft(find.text('Sign up')).dy, lessThan(screen.height));
  });

  testWidgets('Landing carousel shows the photo inside a 220 px circle (ClipOval), not a rectangle', (tester) async {
    await phone(tester);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme(), home: const LandingScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    final circle = find.byKey(const ValueKey('landing_photo_circle'));
    expect(circle, findsOneWidget);
    expect(tester.getSize(circle), const Size(kLandingCircle, kLandingCircle));
    expect(find.descendant(of: circle, matching: find.byType(ClipOval)), findsOneWidget);
    expect(find.descendant(of: circle, matching: find.byType(Image)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
