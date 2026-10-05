import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pethotelbooking/core/constants/app_colors.dart';
import 'package:flutter_pethotelbooking/core/constants/app_tokens.dart';
import 'package:flutter_pethotelbooking/core/theme/app_theme.dart';
import 'package:flutter_pethotelbooking/core/theme/field_border.dart';
import 'package:flutter_pethotelbooking/core/widgets/widgets.dart';
import 'package:flutter_pethotelbooking/features/admin_screens/booking_management.dart';
import 'package:flutter_pethotelbooking/features/customer_screens/my_bookings.dart';
import 'package:flutter_pethotelbooking/features/customer_screens/pets_list_screen.dart';
import 'package:flutter_pethotelbooking/models/booking_model.dart';
import 'package:flutter_pethotelbooking/models/pet_model.dart';
import 'package:flutter_pethotelbooking/services/payment_service.dart';

/// Phase 1 — shared design foundation (Enhancement Spec §2, §3, §4, §7, §8).
void main() {
  final theme = AppTheme.lightTheme();

  group('Typography (§3)', () {
    test('Fredoka only for display / headline / titleLarge; Plus Jakarta Sans for the rest', () {
      final t = theme.textTheme;
      for (final s in [t.displaySmall, t.headlineSmall, t.titleLarge]) {
        expect(s!.fontFamily, 'Fredoka');
      }
      for (final s in [t.titleMedium, t.bodyLarge, t.bodyMedium, t.bodySmall, t.labelLarge, t.labelMedium, t.labelSmall]) {
        expect(s!.fontFamily, 'PlusJakartaSans');
      }
    });
    test('spec sizes and weights', () {
      final t = theme.textTheme;
      // Compact scale (owner request 2026-10-03): one step below spec §3.
      expect([t.displaySmall!.fontSize, t.headlineSmall!.fontSize, t.titleLarge!.fontSize, t.titleMedium!.fontSize], [24, 20, 16, 15]);
      expect([t.bodyLarge!.fontSize, t.bodyMedium!.fontSize, t.bodySmall!.fontSize], [14, 13, 12]);
      expect(t.bodyLarge!.fontWeight, FontWeight.w400, reason: 'typed values are never bold');
      expect(t.labelLarge!.fontWeight, FontWeight.w600);
    });
  });

  group('Colors (§2)', () {
    test('spec tokens and roles', () {
      expect(AppColors.cream, const Color(0xFFFAF3E6));
      expect(AppColors.surface, isNot(const Color(0xFFFFFFFF)), reason: 'no pure white (owner HCI requirement)');
      expect(AppColors.mustard, const Color(0xFFF5B21B));
      expect(theme.scaffoldBackgroundColor, AppColors.cream);
      expect(AppColors.onPrimary, AppColors.ink, reason: 'text on mustard is ink, never white');
    });
  });

  group('Fields (§8)', () {
    test('label floats INSIDE the box (border is not an outline that the label cuts into)', () {
      final d = theme.inputDecorationTheme;
      expect(d.enabledBorder, isA<FieldBorder>());
      expect(d.enabledBorder!.isOutline, isFalse);
      expect((d.focusedBorder as FieldBorder).glow, isTrue);
      expect(d.focusedBorder!.borderSide.width, AppBorders.width);
      expect((d.enabledBorder as FieldBorder).radius, AppRadius.field);
    });
  });

  group('Buttons and cards (§4, §7)', () {
    BoxDecoration? popDecoration(WidgetTester tester) {
      final c = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).first;
      return c.decoration as BoxDecoration?;
    }

    testWidgets('primary button has the pop shadow; disabled has none', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: theme, home: Scaffold(body: PrimaryButton(label: 'Book', onPressed: () {}))));
      expect(popDecoration(tester)!.boxShadow, AppShadows.pop);
      await tester.pumpWidget(MaterialApp(theme: theme, home: const Scaffold(body: PrimaryButton(label: 'Book', onPressed: null))));
      await tester.pumpAndSettle();
      expect(popDecoration(tester)!.boxShadow, isEmpty);
    });

    testWidgets('press scales to 0.97; reduced motion keeps scale 1', (tester) async {
      Future<double> pressedScale({required bool reduceMotion}) async {
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: Scaffold(body: Center(child: PrimaryButton(label: 'Book', onPressed: () {}, fullWidth: false))),
          ),
        ));
        final g = await tester.startGesture(tester.getCenter(find.text('Book')));
        await tester.pump(const Duration(milliseconds: 200));
        final s = tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
        await g.up();
        await tester.pumpAndSettle();
        return s;
      }

      expect(await pressedScale(reduceMotion: false), 0.97);
      expect(await pressedScale(reduceMotion: true), 1.0);
    });
  });

  group('No overflow at 320 dp with 1.3x text (spec §3, TC-17)', () {
    final future = DateTime.now().add(const Duration(days: 5));
    final b = BookingModel(
      bookingID: 'AbCdEfGh123',
      custID: 'c',
      petID: 'p',
      roomID: 'r',
      checkInDate: future,
      checkOutDate: future.add(const Duration(days: 3)),
      totalAmount: 2350,
      status: 'pending',
      customerName: 'Maria Clara Santos-Dela Cruz',
      petName: 'Buddy the Golden',
      roomNum: 'LX1',
      roomTypeName: 'Luxury VIP Suite With Garden View',
    );
    final pet = PetModel(petID: 'p', cusID: 'c', petName: 'Buddy the Golden Retriever', petType: 'Dog', breed: 'Golden Retriever', gender: 'Male', weightSize: 'Large (L)');

    testWidgets('booking cards, pet card, form section', (tester) async {
      tester.view.physicalSize = const Size(640, 3600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(320, 1800), textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: ListView(padding: const EdgeInsets.all(20), children: [
              BookingCard(booking: b, summary: BookingPaymentSummary(b, const [])),
              const SizedBox(height: 12),
              AdminBookingCard(booking: b, summary: BookingPaymentSummary(b, const [])),
              const SizedBox(height: 12),
              PetCard(pet: pet, ownerName: 'Maria Santos', actions: [
                SecondaryButton(label: 'Edit', onPressed: () {}),
                DestructiveButton(label: 'Delete', onPressed: () {}),
                PrimaryButton(label: 'Book', onPressed: () {}),
              ]),
              const SizedBox(height: 12),
              FormSection(title: 'Personal information', description: 'Your name as it appears on bookings.', icon: Icons.badge_outlined, children: [
                TextFormField(decoration: const InputDecoration(labelText: 'First name'), initialValue: 'Jaica'),
              ]),
            ]),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
