import 'package:device_preview/device_preview.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_config.dart';
import 'core/constants/app_text_styles.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/widgets.dart';
import 'features/admin_screens/admin_shell.dart';
import 'features/customer_screens/complete_profile.dart';
import 'features/customer_screens/customer_shell.dart';
import 'features/customer_screens/landing_screen.dart';
import 'features/launch/launch_screen.dart';
import 'firebase_options.dart';
import 'providers/accessibility_provider.dart';
import 'providers/session_provider.dart';

/// Development only. Building with `--dart-define=USE_FIREBASE_EMULATORS=true`
/// connects the app to the Firebase Local Emulator Suite on this computer
/// (demo data, automated tests and documentation screenshots). Normal builds
/// leave this false and use the live Firebase project.
const bool kUseFirebaseEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? initError;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    if (kUseFirebaseEmulators) {
      // Web/desktop reach the emulators on localhost (an Android emulator would need 10.0.2.2).
      await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
      FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
      await FirebaseStorage.instance.useStorageEmulator('127.0.0.1', 9199);
      debugPrint('[PetHotel] Using the local Firebase emulators.');
    }
    kFirebaseReady = true;
  } catch (e) {
    kFirebaseReady = false;
    initError = e;
    debugPrint('[PetHotel] Firebase failed to initialize: $e');
  }

  // DATA-003: no silent "mock mode" any more. If Firebase cannot start, the
  // app says so instead of pretending to work with fake data.
  if (!kFirebaseReady) {
    runApp(FirebaseErrorApp(error: initError));
    return;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AccessibilityProvider()),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
      ],
      // Device Preview only in debug builds (was always on, even in release).
      child: DevicePreview(enabled: !kReleaseMode, builder: (context) => const PetHotelApp()),
    ),
  );
}

class PetHotelApp extends StatelessWidget {
  const PetHotelApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scale = context.watch<AccessibilityProvider>().scaleFactor;
    return MaterialApp(
      locale: DevicePreview.locale(context),
      builder: (context, child) {
        final previewed = DevicePreview.appBuilder(context, child);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: previewed,
        );
      },
      title: 'Pet Hotel Booking',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      // Phase 2: animated launch screen in front of the normal routing.
      home: Selector<SessionProvider, bool>(
        selector: (_, s) => s.state != SessionState.loading,
        builder: (_, ready, _) => LaunchGate(ready: ready, child: const AuthGate()),
      ),
    );
  }
}

enum AuthDestination { loading, landing, profileMissing, adminHome, customerHome }

/// Decides which area to show from the session (AUTH-002, AUTH-006).
/// Admin and customer areas are completely separate (Q-19: no role switching).
class AuthGate extends StatelessWidget {
  /// Test hooks only; the app always uses the real shells.
  final WidgetBuilder? adminHome;
  final WidgetBuilder? customerHome;
  final WidgetBuilder? completeProfile;

  const AuthGate({super.key, this.adminHome, this.customerHome, this.completeProfile});

  /// Pure routing decision, unit-tested for every session state.
  static AuthDestination destinationFor(SessionState state, {required bool isAdmin}) => switch (state) {
        SessionState.loading => AuthDestination.loading,
        SessionState.signedOut => AuthDestination.landing,
        SessionState.profileMissing => AuthDestination.profileMissing,
        SessionState.ready => isAdmin ? AuthDestination.adminHome : AuthDestination.customerHome,
      };

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    switch (destinationFor(session.state, isAdmin: session.isAdmin)) {
      case AuthDestination.loading:
        return const Scaffold(body: LoadingState(message: 'Loading your account…'));
      case AuthDestination.landing:
        return const LandingScreen();
      case AuthDestination.profileMissing:
        // Signed in but no profile yet (first Google sign-in): collect it.
        if (session.user == null) return completeProfile?.call(context) ?? const CompleteProfileScreen();
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const PawLoader(semanticLabel: 'Setting up your account'),
                  const SizedBox(height: 18),
                  const Text('Setting up your account…', style: AppTextStyles.headingSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  const Text('If this takes too long, your profile may be missing. Sign out and try again, or contact the hotel.',
                      style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  SecondaryButton(label: 'Sign out', icon: Icons.logout_rounded, fullWidth: false, onPressed: session.signOut),
                ]),
              ),
            ),
          ),
        );
      case AuthDestination.adminHome:
        return adminHome?.call(context) ?? const AdminShell();
      case AuthDestination.customerHome:
        return customerHome?.call(context) ?? const CustomerShell();
    }
  }
}

/// Shown only when Firebase cannot initialise.
class FirebaseErrorApp extends StatelessWidget {
  final Object? error;
  const FirebaseErrorApp({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      home: Scaffold(
        body: ErrorState(
          title: 'Cannot connect to the Pet Hotel server',
          message: 'Firebase could not start on this device. Check your internet connection and the Firebase configuration, then restart the app.\n\n${error ?? ''}',
        ),
      ),
    );
  }
}
