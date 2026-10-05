import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_pethotelbooking/core/theme/app_theme.dart';
import 'package:flutter_pethotelbooking/core/widgets/widgets.dart';
import 'package:flutter_pethotelbooking/features/customer_screens/landing_screen.dart';
import 'package:flutter_pethotelbooking/features/launch/launch_screen.dart';
import 'package:flutter_pethotelbooking/main.dart';
import 'package:flutter_pethotelbooking/models/user_model.dart';
import 'package:flutter_pethotelbooking/providers/session_provider.dart';

/// Phase 2 — launch experience (Enhancement Spec §5, roadmap Phase 2).
void main() {
  final theme = AppTheme.lightTheme();

  group('Role routing after launch', () {
    test('every session state goes to the right place', () {
      expect(AuthGate.destinationFor(SessionState.loading, isAdmin: false), AuthDestination.loading);
      expect(AuthGate.destinationFor(SessionState.signedOut, isAdmin: false), AuthDestination.landing);
      expect(AuthGate.destinationFor(SessionState.profileMissing, isAdmin: false), AuthDestination.profileMissing);
      expect(AuthGate.destinationFor(SessionState.ready, isAdmin: true), AuthDestination.adminHome);
      expect(AuthGate.destinationFor(SessionState.ready, isAdmin: false), AuthDestination.customerHome);
    });

    test('customer with an empty cusID never reaches the customer area', () {
      final u = UserModel(userID: 'u', username: 'c', email: 'c@x.com', role: UserRole.customer, cusID: '  ');
      expect(SessionProvider.nextStepFor(u), ProfileStep.missing);
    });

    Future<void> pumpGate(WidgetTester tester, SessionProvider session) async {
      await tester.pumpWidget(ChangeNotifierProvider<SessionProvider>.value(
        value: session,
        child: MaterialApp(
          theme: theme,
          home: AuthGate(
            adminHome: (_) => const Text('ADMIN AREA'),
            customerHome: (_) => const Text('CUSTOMER AREA'),
            completeProfile: (_) => const Text('COMPLETE PROFILE'),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('signed out -> landing', (tester) async {
      await pumpGate(tester, SessionProvider.seeded(state: SessionState.signedOut));
      expect(find.byType(LandingScreen), findsOneWidget);
    });

    testWidgets('loading -> paw loader with message', (tester) async {
      await pumpGate(tester, SessionProvider.seeded(state: SessionState.loading));
      expect(find.text('Loading your account…'), findsOneWidget);
      expect(find.byType(PawLoader), findsOneWidget);
    });

    testWidgets('signed in without any profile (first Google sign-in) -> complete profile', (tester) async {
      await pumpGate(tester, SessionProvider.seeded(state: SessionState.profileMissing));
      expect(find.text('COMPLETE PROFILE'), findsOneWidget);
    });

    testWidgets('profile without a customer record -> setup screen with Sign out', (tester) async {
      final u = UserModel(userID: 'u', username: 'c', email: 'c@x.com', role: UserRole.customer, cusID: '');
      await pumpGate(tester, SessionProvider.seeded(state: SessionState.profileMissing, user: u));
      expect(find.text('Setting up your account…'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('admin -> admin area; customer -> customer area', (tester) async {
      final admin = UserModel(userID: 'a', username: 'admin', email: 'a@x.com', role: UserRole.admin);
      await pumpGate(tester, SessionProvider.seeded(state: SessionState.ready, user: admin));
      expect(find.text('ADMIN AREA'), findsOneWidget);

      final cus = UserModel(userID: 'c', username: 'cus', email: 'c@x.com', role: UserRole.customer, cusID: 'C1');
      await pumpGate(tester, SessionProvider.seeded(state: SessionState.ready, user: cus));
      expect(find.text('CUSTOMER AREA'), findsOneWidget);
      expect(find.text('ADMIN AREA'), findsNothing);
    });
  });

  group('Launch timing (min 1.2 s, max 3 s, never blocking)', () {
    test('decision table', () {
      expect(LaunchGate.shouldShowApp(ready: true, minElapsed: false, maxElapsed: false), isFalse);
      expect(LaunchGate.shouldShowApp(ready: true, minElapsed: true, maxElapsed: false), isTrue);
      expect(LaunchGate.shouldShowApp(ready: false, minElapsed: true, maxElapsed: false), isFalse);
      expect(LaunchGate.shouldShowApp(ready: false, minElapsed: true, maxElapsed: true), isTrue);
    });

    Widget gate(bool ready) => MaterialApp(theme: theme, home: LaunchGate(ready: ready, child: const Text('APP')));

    testWidgets('ready at once: splash for 1.2 s, then the app', (tester) async {
      await tester.pumpWidget(gate(true));
      expect(find.byType(LaunchScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(find.text('APP'), findsNothing);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('APP'), findsOneWidget);
      expect(find.byType(LaunchScreen), findsNothing);
    });

    testWidgets('becomes ready at 2 s: app shows then, not at 3 s', (tester) async {
      await tester.pumpWidget(gate(false));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('APP'), findsNothing);
      await tester.pumpWidget(gate(true));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('APP'), findsOneWidget);
    });

    testWidgets('never ready: app (with its own loading state) shows at 3 s', (tester) async {
      await tester.pumpWidget(gate(false));
      await tester.pump(const Duration(milliseconds: 2900));
      expect(find.text('APP'), findsNothing);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('APP'), findsOneWidget);
    });

    testWidgets('splash never returns once the app is shown', (tester) async {
      await tester.pumpWidget(gate(true));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(gate(false)); // e.g. signing in again
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('APP'), findsOneWidget);
      expect(find.byType(LaunchScreen), findsNothing);
    });
  });

  group('Launch screen and brand widgets', () {
    Widget launch({bool reduceMotion = false, double textScale = 1}) => MaterialApp(
          theme: theme,
          home: MediaQuery(
            data: MediaQueryData(size: const Size(320, 640), disableAnimations: reduceMotion, textScaler: TextScaler.linear(textScale)),
            child: const LaunchScreen(),
          ),
        );

    testWidgets('shows mascot, name, tagline and paw loader; no overflow at 320 dp / 1.3x', (tester) async {
      tester.view.physicalSize = const Size(640, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(launch(textScale: 1.3));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Mascot), findsOneWidget);
      expect(find.text(LaunchScreen.appName), findsOneWidget);
      expect(find.text(LaunchScreen.tagline), findsOneWidget);
      expect(find.byType(PawLoader), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion: no pop-in scaling, fade only', (tester) async {
      await tester.pumpWidget(launch(reduceMotion: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(LaunchScreen.popInKey), findsNothing);
      await tester.pumpWidget(launch());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(LaunchScreen.popInKey), findsOneWidget);
    });

    test('all mascot poses are bundled SVGs', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      for (final pose in MascotPose.values) {
        final svg = await rootBundle.loadString(Mascot.assetFor(pose));
        expect(svg, startsWith('<svg'), reason: pose.name);
      }
    });

    testWidgets('Mascot draws an SvgPicture and exposes its label', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Mascot(pose: MascotPose.cheer, size: 120, semanticLabel: 'Mascot cheering')));
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.bySemanticsLabel('Mascot cheering'), findsOneWidget);
    });

    test('paw dots light up one after another', () {
      // Paw 0 peaks at t = 0.25; each next paw a third of a cycle later.
      expect(_brightest(0.25), 0);
      expect(_brightest(0.25 + 1 / 3), 1);
      expect(_brightest(0.25 + 2 / 3), 2);
    });

    testWidgets('paw loader: reduced motion keeps paws still (fade only)', (tester) async {
      Future<List<double>> offsets(bool reduced) async {
        await tester.pumpWidget(MaterialApp(home: MediaQuery(data: MediaQueryData(disableAnimations: reduced), child: const Center(child: PawLoader()))));
        await tester.pump(const Duration(milliseconds: 300));
        return tester.widgetList<Transform>(find.descendant(of: find.byType(PawLoader), matching: find.byType(Transform)))
            .map((t) => t.transform.getTranslation().y)
            .toList();
      }

      expect((await offsets(true)).every((y) => y == 0), isTrue);
      expect((await offsets(false)).any((y) => y != 0), isTrue);
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    });
  });
}

int _brightest(double t) {
  var best = 0;
  for (var i = 1; i < 3; i++) {
    if (pawLit(i, t) > pawLit(best, t)) best = i;
  }
  return best;
}

double pawLit(int i, double t) => PawLoader.litAt(i, t);
