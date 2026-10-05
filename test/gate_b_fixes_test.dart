import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pethotelbooking/core/theme/app_theme.dart';
import 'package:flutter_pethotelbooking/features/customer_screens/my_bookings.dart';
import 'package:flutter_pethotelbooking/models/booking_model.dart';
import 'package:flutter_pethotelbooking/services/payment_service.dart';

/// Defects found in live end-to-end testing against the Firebase emulators
/// (Approval Gate B, 2026-10-03).
void main() {
  BookingModel booking(String status) => BookingModel(
        bookingID: 'OKcG2zDLlWiKx0M8oX4g',
        custID: 'c',
        petID: 'p',
        roomID: 'r',
        checkInDate: DateTime.now().add(const Duration(days: 17)),
        checkOutDate: DateTime.now().add(const Duration(days: 20)),
        totalAmount: 3450,
        status: status,
        petName: 'Choco',
        roomNum: 'S-101',
        roomTypeName: 'Standard Room',
      );

  Future<void> pumpCard(WidgetTester tester, BookingModel b) async {
    tester.view.physicalSize = const Size(640, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme(),
      home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: BookingCard(booking: b, summary: BookingPaymentSummary(b, const [])))),
    ));
    await tester.pump();
  }

  testWidgets('confirmed + unpaid: QR Pass is shown, and Cancel is still available', (tester) async {
    await pumpCard(tester, booking('approved'));
    expect(find.text('QR Pass'), findsOneWidget, reason: 'was hidden behind Cancel and Pay Now');
    expect(find.text('Pay Now'), findsOneWidget);
    expect(find.text('Cancel booking'), findsOneWidget, reason: 'cancel moves to a link, never disappears');
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending + unpaid: Cancel and Pay Now side by side (no QR yet)', (tester) async {
    await pumpCard(tester, booking('pending'));
    expect(find.text('QR Pass'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Pay Now'), findsOneWidget);
    expect(find.text('Cancel booking'), findsNothing);
  });
}
