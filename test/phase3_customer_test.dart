import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pethotelbooking/core/logic/booking_views.dart';
import 'package:flutter_pethotelbooking/core/theme/app_theme.dart';
import 'package:flutter_pethotelbooking/core/widgets/widgets.dart';
import 'package:flutter_pethotelbooking/features/customer_screens/booking_wizard.dart';
import 'package:flutter_pethotelbooking/features/customer_screens/customer_shell.dart';
import 'package:flutter_pethotelbooking/features/customer_screens/my_bookings.dart';
import 'package:flutter_pethotelbooking/models/booking_model.dart';
import 'package:flutter_pethotelbooking/services/payment_service.dart';

/// Phase 3 — customer Home, My Bookings and booking flow (Enhancement Spec §6, §9.1–9.3).
void main() {
  final theme = AppTheme.lightTheme();
  final today = DateTime(2026, 10, 3);

  BookingModel booking(String id, String status, int inDays, {int nights = 2}) => BookingModel(
        bookingID: id,
        custID: 'c',
        petID: 'p',
        roomID: 'r',
        checkInDate: today.add(Duration(days: inDays)),
        checkOutDate: today.add(Duration(days: inDays + nights)),
        totalAmount: 1500,
        status: status,
        petName: 'Buddy',
        roomNum: '101',
        roomTypeName: 'Standard Room',
      );

  group('Booking views (Home hero, My Bookings tabs)', () {
    final all = [
      booking('later', 'approved', 9),
      booking('soon', 'pending', 3),
      booking('done', 'checked_out', -10),
      booking('cx', 'cancelled', 5),
      booking('no', 'rejected', 6),
    ];

    test('buckets and order', () {
      expect(BookingViews.upcoming(all).map((b) => b.bookingID), ['soon', 'later']);
      expect(BookingViews.completed(all).map((b) => b.bookingID), ['done']);
      expect(BookingViews.cancelled(all).map((b) => b.bookingID), ['cx', 'no']);
    });

    test('next stay: soonest upcoming, but a current stay wins', () {
      expect(BookingViews.nextStay(all)!.bookingID, 'soon');
      expect(BookingViews.nextStay([...all, booking('now', 'checked_in', -1)])!.bookingID, 'now');
      expect(BookingViews.nextStay([booking('done', 'checked_out', -3)]), isNull);
    });

    test('countdown labels', () {
      expect(BookingViews.countdown(booking('a', 'approved', 0), today), 'Today');
      expect(BookingViews.countdown(booking('a', 'approved', 1), today), 'Tomorrow');
      expect(BookingViews.countdown(booking('a', 'pending', 3), today.add(const Duration(hours: 20))), 'In 3 days');
      expect(BookingViews.countdown(booking('a', 'checked_in', -1), today), 'Staying now');
    });
  });

  group('Booking flow: Continue explains why it is disabled (TC-13)', () {
    String? reason(int step, {bool pet = true, bool dates = true, String? dateError, bool room = true, bool bookable = true}) =>
        BookingWizardScreen.blockedReason(step, hasPet: pet, hasDates: dates, dateError: dateError, hasRoom: room, roomBookable: bookable);

    test('each step', () {
      expect(reason(0, pet: false), 'Select a pet to continue');
      expect(reason(0), isNull);
      expect(reason(1, dates: false), 'Choose your stay dates to continue');
      expect(reason(1, dateError: 'Check-out must be after check-in.'), 'Check-out must be after check-in.');
      expect(reason(1, room: false), 'Choose a room to continue');
      expect(reason(1, bookable: false), 'This room is not available for these dates');
      expect(reason(2, pet: false, dates: false, room: false), isNull, reason: 'add-ons are optional');
      expect(reason(3, pet: false), 'Select a pet to continue');
      expect(reason(3), isNull);
    });
  });

  Widget host(Widget child, {double width = 375, double textScale = 1, bool reduceMotion = false}) => MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 800), textScaler: TextScaler.linear(textScale), disableAnimations: reduceMotion),
          child: Scaffold(body: child),
        ),
      );

  void phone(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width * 2, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  group('Shared Phase 3 widgets', () {
    testWidgets('segmented pills: counts, selection, no overflow at 320 dp / 1.3x', (tester) async {
      phone(tester, 320);
      var selected = 'up';
      await tester.pumpWidget(host(
        StatefulBuilder(
          builder: (context, set) => SegmentedPills<String>(
            selected: selected,
            onChanged: (v) => set(() => selected = v),
            segments: const [PillSegment('up', 'Upcoming', count: 2), PillSegment('done', 'Completed', count: 0), PillSegment('cx', 'Cancelled', count: 1), PillSegment('rev', 'Reviews')],
          ),
        ),
        width: 320,
        textScale: 1.3,
      ));
      expect(find.text('2'), findsOneWidget);
      expect(find.text('0'), findsNothing, reason: 'zero counts are hidden');
      // At 320 dp / 1.3x the pills scroll sideways; bring the target into view first.
      await tester.ensureVisible(find.text('Cancelled'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelled'));
      await tester.pumpAndSettle();
      expect(selected, 'cx');
      expect(find.bySemanticsLabel('Cancelled, 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('progress header shows step and fills completed segments', (tester) async {
      await tester.pumpWidget(host(const Padding(padding: EdgeInsets.all(20), child: BookingProgressHeader(title: 'Boarding Details', step: 1, total: 4))));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 4'), findsOneWidget);
      expect(find.text('Boarding Details'), findsOneWidget);
      final fills = tester.widgetList<AnimatedFractionallySizedBox>(find.byType(AnimatedFractionallySizedBox)).map((w) => w.widthFactor).toList();
      expect(fills, [1, 1, 0, 0]);
    });

    testWidgets('total rolls to the new amount; instant with reduced motion', (tester) async {
      const style = TextStyle(fontSize: 18);
      await tester.pumpWidget(host(const AnimatedPeso(value: 0, style: style)));
      expect(find.text('—'), findsOneWidget);
      await tester.pumpWidget(host(const AnimatedPeso(value: 2350, style: style)));
      await tester.pumpAndSettle();
      expect(find.text('₱2,350.00'), findsOneWidget);

      await tester.pumpWidget(host(const AnimatedPeso(value: 500, style: style), reduceMotion: true));
      await tester.pump();
      expect(find.text('₱500.00'), findsOneWidget);
    });

    testWidgets('selectable card pops its check badge when selected', (tester) async {
      Future<double> checkScale(bool selected) async {
        await tester.pumpWidget(host(SelectableCard(selected: selected, onTap: () {}, child: const Text('Buddy'))));
        await tester.pumpAndSettle();
        return tester.widget<AnimatedScale>(find.descendant(of: find.byType(SelectableCard), matching: find.byType(AnimatedScale)).last).scale;
      }

      expect(await checkScale(false), 0);
      expect(await checkScale(true), 1);
    });

    testWidgets('mascot empty state (upper third); still with reduced motion', (tester) async {
      await tester.pumpWidget(host(
        const EmptyState(icon: Icons.pets, mascot: MascotPose.sleep, topAligned: true, title: 'No pets yet', message: 'Register your pet.'),
        reduceMotion: true,
      ));
      await tester.pumpAndSettle(); // would time out if the breathing loop ran
      expect(find.byType(Mascot), findsOneWidget);
      final y = tester.getCenter(find.text('No pets yet')).dy;
      expect(y, lessThan(800 / 2), reason: 'placed above the middle');
    });
  });

  group('Customer navigation bar (spec §6)', () {
    testWidgets('five destinations, Book button, upcoming dot; fits 320 dp at 1.3x', (tester) async {
      phone(tester, 320);
      CustomerTab? tapped;
      var booked = false;
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(320, 800), textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            bottomNavigationBar: CustomerNavBar(
              current: CustomerTab.home,
              onSelect: (t) => tapped = t,
              onBook: () => booked = true,
              hasUpcoming: true,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      for (final l in ['Home', 'Pets', 'Account']) {
        expect(find.bySemanticsLabel(l), findsOneWidget);
      }
      expect(find.bySemanticsLabel('Bookings, upcoming stay'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Bookings, upcoming stay'));
      expect(tapped, CustomerTab.bookings);
      await tester.tap(find.bySemanticsLabel('Book a stay'));
      expect(booked, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('My Bookings card (spec §9.2)', () {
    testWidgets('upcoming card shows countdown, nights and total', (tester) async {
      phone(tester, 320);
      final b = BookingModel(
        bookingID: 'AbCdEfGh123',
        custID: 'c',
        petID: 'p',
        roomID: 'r',
        checkInDate: DateTime.now().add(const Duration(days: 3)),
        checkOutDate: DateTime.now().add(const Duration(days: 5)),
        totalAmount: 2350,
        status: 'approved',
        petName: 'Buddy',
        roomNum: '101',
        roomTypeName: 'Standard Room',
      );
      await tester.pumpWidget(host(
        SingleChildScrollView(padding: const EdgeInsets.all(20), child: BookingCard(booking: b, summary: BookingPaymentSummary(b, const []))),
        width: 320,
        textScale: 1.3,
      ));
      await tester.pump();
      expect(find.text('In 3 days'), findsOneWidget);
      expect(find.textContaining('2 nights'), findsOneWidget);
      expect(find.text('₱2,350.00'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
