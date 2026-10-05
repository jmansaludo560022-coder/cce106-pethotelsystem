import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pethotelbooking/core/theme/app_theme.dart';
import 'package:flutter_pethotelbooking/features/customer_screens/qr_pass.dart';
import 'package:flutter_pethotelbooking/models/booking_model.dart';

BookingModel _booking(String status) => BookingModel(
      bookingID: 'BKTEST0001XYZ',
      custID: 'cus_1',
      petID: 'pet_1',
      roomID: 'room_1',
      checkInDate: DateTime(2026, 10, 1),
      checkOutDate: DateTime(2026, 10, 3),
      totalAmount: 900.0,
      status: status,
      petName: 'Milo',
      roomNum: 'RC1',
    );

Future<void> _pump(WidgetTester tester, BookingModel b) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme(), home: Scaffold(body: QrPassView(booking: b))));
}

void main() {
  testWidgets('QR pass is locked while the booking is pending', (tester) async {
    await _pump(tester, _booking('pending'));
    expect(find.text('Pass locked'), findsOneWidget);
    expect(find.text('Check-in QR'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('QR pass shows an active check-in code once approved', (tester) async {
    await _pump(tester, _booking('approved'));
    expect(find.text('Check-in QR'), findsOneWidget);
    expect(find.text('Check-out QR'), findsOneWidget);
    expect(find.text('SHOW AT ARRIVAL'), findsOneWidget);
    expect(find.text('AVAILABLE AFTER CHECK-IN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('After check-in the check-out code becomes active', (tester) async {
    await _pump(tester, _booking('checked_in'));
    expect(find.text('SHOW AT PICK-UP'), findsOneWidget);
    expect(find.text('USED'), findsOneWidget);
  });

  testWidgets('QR pass renders without overflow on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 640 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme(), home: Scaffold(body: QrPassView(booking: _booking('approved')))));
    expect(tester.takeException(), isNull);
  });
}
