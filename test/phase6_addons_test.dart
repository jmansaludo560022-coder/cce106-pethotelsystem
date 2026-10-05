import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pethotelbooking/core/logic/booking_rules.dart';
import 'package:flutter_pethotelbooking/core/theme/app_theme.dart';
import 'package:flutter_pethotelbooking/features/admin_screens/add_ons.dart';
import 'package:flutter_pethotelbooking/features/customer_screens/services_row.dart';
import 'package:flutter_pethotelbooking/models/add_on_model.dart';

/// Phase 6 — add-on description, unit and active flag (decision D6).
void main() {
  final grooming = AddOnModel(addOnID: 'g', addOnName: 'Grooming', price: 500, description: 'Bath, blow-dry and nail trim');
  final daycare = AddOnModel(addOnID: 'd', addOnName: 'Daycare play', price: 200, unit: AddOnUnits.perDay);
  final retired = AddOnModel(addOnID: 'r', addOnName: 'Pet taxi', price: 300, isActive: false);

  group('Pricing', () {
    test('per-stay once, per-day × nights', () {
      const nights = 3;
      final lines = [
        SelectedAddOn(addOnID: 'g', addOnName: 'Grooming', price: 500, quantity: 1, unit: AddOnUnits.perStay, days: AddOnUnits.daysFor(AddOnUnits.perStay, nights)),
        SelectedAddOn(addOnID: 'd', addOnName: 'Daycare play', price: 200, quantity: 2, unit: AddOnUnits.perDay, days: AddOnUnits.daysFor(AddOnUnits.perDay, nights)),
      ];
      expect(lines[0].subtotal, 500);
      expect(lines[1].subtotal, 1200); // 200 × 2 × 3
      expect(calculateBookingTotal(pricePerNight: 1000, nights: nights, addOns: lines.map((l) => l.line)), 4700);
      expect(lines[1].lineLabel, 'Daycare play × 2 · 3 days');
      expect(lines[0].lineLabel, 'Grooming × 1');
    });

    test('per-day follows the nights; never below 1', () {
      expect(AddOnUnits.daysFor(AddOnUnits.perDay, 5), 5);
      expect(AddOnUnits.daysFor(AddOnUnits.perDay, 0), 1);
      expect(AddOnUnits.daysFor(AddOnUnits.perStay, 5), 1);
      expect(AddOnUnits.daysFor(null, 5), 1, reason: 'missing unit = per stay');
    });

    test('bookings saved before D6 keep their exact totals', () {
      final legacy = SelectedAddOn.fromMap({'addOnID': 'g', 'addOnName': 'Grooming', 'price': 500, 'quantity': 2});
      expect(legacy.unit, AddOnUnits.perStay);
      expect(legacy.days, 1);
      expect(legacy.subtotal, 1000);
      expect(calculateBookingTotal(pricePerNight: 800, nights: 2, addOns: [const AddOnLine(500, 2)]), 2600, reason: 'old two-argument lines unchanged');
    });

    test('booking snapshot stores unit and days', () {
      final m = SelectedAddOn(addOnID: 'd', addOnName: 'Daycare play', price: 200, quantity: 1, unit: AddOnUnits.perDay, days: 4).toMap();
      expect(m['unit'], 'day');
      expect(m['days'], 4);
      expect(SelectedAddOn.fromMap(m).subtotal, 800);
    });
  });

  group('Active flag', () {
    test('customers only see active add-ons', () {
      expect(AddOnModel.activeOnly([grooming, daycare, retired]).map((a) => a.addOnID), ['g', 'd']);
    });

    test('add-ons saved before D6 default to active, per stay', () {
      final a = AddOnModel(addOnID: 'x', addOnName: 'Old', price: 100);
      expect(a.isActive, isTrue);
      expect(a.unitLabel, 'per stay');
      expect(a.toMap()['isActive'], isTrue);
    });
  });

  group('Screens', () {
    final theme = AppTheme.lightTheme();

    testWidgets('Home services show unit; details show description and charge', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(body: ServicesRow(streamFactory: () => Stream.value([grooming, daycare]))),
      ));
      await tester.pumpAndSettle();
      expect(find.text('₱500 per stay'), findsOneWidget);
      expect(find.text('₱200 per day'), findsOneWidget);
      await tester.tap(find.text('Grooming'));
      await tester.pumpAndSettle();
      expect(find.text('Bath, blow-dry and nail trim'), findsOneWidget);
      expect(find.text('Once per stay'), findsOneWidget);
    });

    testWidgets('admin form: description, unit and "Offered to customers"', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: theme, home: AddOnFormScreen(existing: retired)));
      await tester.pumpAndSettle();
      expect(find.text('Short description (optional)'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
      expect(find.textContaining('Hidden from customers'), findsOneWidget);

      await tester.tap(find.text('Per day'));
      await tester.pumpAndSettle();
      expect(find.text('Price × quantity × number of nights.'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.text('Shown on Home and in the booking flow.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
