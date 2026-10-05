import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pethotelbooking/core/theme/app_theme.dart';
import 'package:flutter_pethotelbooking/core/utils/ph_locations.dart';
import 'package:flutter_pethotelbooking/core/widgets/ph_form_fields.dart';
import 'package:flutter_pethotelbooking/core/widgets/widgets.dart';
import 'package:flutter_pethotelbooking/features/admin_screens/booking_management.dart';
import 'package:flutter_pethotelbooking/features/customer_screens/booking_summary.dart';
import 'package:flutter_pethotelbooking/features/customer_screens/my_bookings.dart';
import 'package:flutter_pethotelbooking/features/customer_screens/pets_list_screen.dart';
import 'package:flutter_pethotelbooking/features/customer_screens/room_widgets.dart';
import 'package:flutter_pethotelbooking/models/add_on_model.dart';
import 'package:flutter_pethotelbooking/models/booking_model.dart';
import 'package:flutter_pethotelbooking/models/payment_model.dart';
import 'package:flutter_pethotelbooking/models/pet_model.dart';
import 'package:flutter_pethotelbooking/models/room_model.dart';
import 'package:flutter_pethotelbooking/models/room_type_model.dart';
import 'package:flutter_pethotelbooking/services/catalog_service.dart';
import 'package:flutter_pethotelbooking/services/payment_service.dart';

/// Layout smoke tests (UI-004): key cards and detail screens must render
/// without overflow on small (320 pt) and common (375 pt) phone widths.
/// These widgets receive data directly, so no Firebase connection is needed.

final _future = DateTime.now().add(const Duration(days: 5));

BookingModel _booking(String status, {String name = 'Maria Clara Santos-Dela Cruz'}) => BookingModel(
      bookingID: 'AbCdEfGh12345',
      custID: 'cus1',
      petID: 'pet1',
      roomID: 'room1',
      checkInDate: _future,
      checkOutDate: _future.add(const Duration(days: 3)),
      totalAmount: 2350,
      status: status,
      customerName: name,
      customerEmail: 'maria.santos@example.com',
      customerPhone: '09171234567',
      petName: 'Buddy the Golden',
      petType: 'Dog',
      roomNum: 'LX1',
      roomTypeName: 'Luxury VIP Suite With Garden View',
      pricePerNight: 650,
      selectedAddOns: [SelectedAddOn(addOnID: 'a', addOnName: 'Grooming Service', price: 350, quantity: 1)],
      paymentMethod: 'On-site Cash',
    );

final _pet = PetModel(petID: 'pet1', cusID: 'cus1', petName: 'Buddy the Golden Retriever', petType: 'Dog', breed: 'Golden Retriever', gender: 'Male', weightSize: 'Large (L)');

final _room = RoomAvailability(
  room: RoomModel(roomID: 'room1', roomTypeID: 't1', roomNum: 'LX1'),
  type: RoomTypeModel(roomTypeID: 't1', typeName: 'Luxury VIP Suite', description: 'Air-conditioned suite with private play area and a daily walk.', pricePerNight: 1200, maxCapacity: 2),
  capacity: 2,
  slotsLeft: 1,
  guestsNow: 1,
);

Future<void> _pumpAt(WidgetTester tester, double width, Widget child) async {
  tester.view.physicalSize = Size(width * 2, 1600 * 2);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme(), home: Scaffold(body: child)));
  await tester.pump();
}

void main() {
  for (final width in [320.0, 375.0]) {
    group('at ${width.toInt()} pt', () {
      testWidgets('customer booking cards (all statuses)', (tester) async {
        await _pumpAt(
          tester,
          width,
          ListView(padding: const EdgeInsets.all(20), children: [
            for (final s in ['pending', 'approved', 'checked_in', 'checked_out', 'rejected'])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BookingCard(booking: _booking(s), summary: BookingPaymentSummary(_booking(s), const [])),
              ),
          ]),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('admin booking cards with Accept / Reject', (tester) async {
        await _pumpAt(
          tester,
          width,
          ListView(padding: const EdgeInsets.all(16), children: [
            AdminBookingCard(booking: _booking('pending'), summary: BookingPaymentSummary(_booking('pending'), const [])),
            AdminBookingCard(booking: _booking('approved')),
          ]),
        );
        expect(find.text('Accept'), findsOneWidget);
        expect(find.text('Reject'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('booking details body with payments', (tester) async {
        final b = _booking('approved');
        final pay = PaymentModel(paymentID: 'p', bookingID: b.bookingID, amount: 1000, paymentMethod: 'Cash', paymentStatus: 'Partial');
        await _pumpAt(tester, width, BookingDetailsBody(booking: b, summary: BookingPaymentSummary(b, [pay]), showCustomer: true, footer: [
          DestructiveButton(label: 'Cancel', onPressed: () {}),
          PrimaryButton(label: 'Payments', onPressed: () {}),
        ]));
        expect(find.text('PARTIAL'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('pet card with three actions', (tester) async {
        await _pumpAt(
          tester,
          width,
          Padding(
            padding: const EdgeInsets.all(20),
            child: PetCard(pet: _pet, ownerName: 'Maria Santos', actions: [
              SecondaryButton(label: 'Edit', onPressed: () {}),
              DestructiveButton(label: 'Delete', onPressed: () {}),
              PrimaryButton(label: 'Book', onPressed: () {}),
            ]),
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('room list card with slots badge', (tester) async {
        await _pumpAt(tester, width, Padding(padding: const EdgeInsets.all(20), child: RoomListCard(item: _room, onView: () {}, onBook: () {})));
        expect(find.text('1 slot left'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('grouped account sections (FormSection, address, read-only email)', (tester) async {
        await tester.runAsync(PhLocations.load);
        await _pumpAt(
          tester,
          width,
          ListView(padding: const EdgeInsets.all(20), children: [
            FormSection(title: 'Personal information', description: 'Your name as it appears on bookings.', icon: Icons.badge_outlined, children: [
              TextFormField(decoration: const InputDecoration(labelText: 'First name')),
              TextFormField(decoration: const InputDecoration(labelText: 'Last name')),
            ]),
            const SizedBox(height: 16),
            FormSection(title: 'Home address', description: 'Choose your region, province and city, then type your barangay and street.', icon: Icons.home_outlined, children: [
              PhAddressFields(initial: PhAddress.empty, legacyAddress: 'Baliok, Blk 15 Lot 6, Makar Davao City', onChanged: (_) {}),
            ]),
            const SizedBox(height: 16),
            FormSection(title: 'Sign-in & security', icon: Icons.lock_outline_rounded, children: [
              const ReadOnlyItem(label: 'Sign-in email', value: 'j.mansaludo.560022@umindanao.edu.ph', note: 'Contact the hotel if you need to change it.'),
              SecondaryButton(label: 'Sign Out', icon: Icons.logout_rounded, onPressed: () {}),
            ]),
          ]),
        );
        await tester.pump();
        expect(find.text('Home address'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('step indicator and stat tiles', (tester) async {
        await _pumpAt(
          tester,
          width,
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const StepIndicator(steps: ['Pet', 'Room', 'Add-ons', 'Review'], current: 2),
              const SizedBox(height: 12),
              Row(children: const [
                Expanded(child: StatTile(label: 'Active bookings', value: '12', icon: Icons.event)),
                SizedBox(width: 12),
                Expanded(child: StatTile(label: 'Total revenue', value: '₱128,450', icon: Icons.payments)),
              ]),
            ]),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    });
  }
}
