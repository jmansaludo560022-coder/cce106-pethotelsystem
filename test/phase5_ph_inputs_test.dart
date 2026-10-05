import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pethotelbooking/core/theme/app_theme.dart';
import 'package:flutter_pethotelbooking/core/utils/ph_locations.dart';
import 'package:flutter_pethotelbooking/core/utils/ph_phone.dart';
import 'package:flutter_pethotelbooking/core/widgets/ph_form_fields.dart';

/// Phase 5 — Philippine phone and address inputs (roadmap Phase 5, D2, D3).
void main() {
  group('Phone: both supported forms normalize to +639XXXXXXXXX', () {
    test('accepted inputs', () {
      for (final input in [
        '09171234567',
        '+639171234567',
        '639171234567',
        '9171234567',
        ' 0917 123 4567 ',
        '0917-123-4567',
        '(0917) 123.4567',
        '+63 917 123 4567',
        '+63 0917 123 4567', // country code + trunk 0
      ]) {
        expect(PhPhone.normalize(input), '+639171234567', reason: input);
      }
    });

    test('rejected inputs', () {
      for (final input in [
        '',
        '   ',
        '0917123456', // 10 digits with 0 = too short
        '091712345678', // too long
        '917123456', // 9 digits
        '08171234567', // landline-style prefix
        '+63 63 917 123 4567', // repeated country code
        '+1 917 123 4567',
        '0917a1234567', // letter
        '0917_123_4567',
        '0917+1234567', // + not at the start
      ]) {
        expect(PhPhone.normalize(input), isNull, reason: input);
      }
      expect(PhPhone.normalize(null), isNull);
    });

    test('field validator messages', () {
      expect(PhPhone.validateLocal(''), 'Mobile number is required.');
      expect(PhPhone.validateLocal('817 123 4567'), PhPhone.errorText);
      expect(PhPhone.validateLocal('917 123 4567'), isNull);
    });

    test('pasting any form into the +63 field keeps the 10 local digits', () {
      String paste(String s) => PhLocalPhoneFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: s)).text;
      expect(paste('09171234567'), '917 123 4567');
      expect(paste('+639171234567'), '917 123 4567');
      expect(paste('+63 0917 123 4567'), '917 123 4567');
      expect(paste('9171234567'), '917 123 4567');
    });
  });

  group('Address model (D2)', () {
    const full = PhAddress(
      regionCode: '110000000',
      regionName: 'Region XI – Davao Region',
      provinceCode: '112400000',
      provinceName: 'Davao del Sur',
      cityCode: '112402000',
      cityName: 'City of Davao',
      barangay: 'Matina Crossing',
      street: 'Acacia St.',
      houseUnit: 'Blk 2 Lot 5',
    );

    test('house/unit and street are separate and round-trip', () {
      final back = PhAddress.fromMap(full.toMap());
      expect(back.houseUnit, 'Blk 2 Lot 5');
      expect(back.street, 'Acacia St.');
      expect(back.formatted, 'Blk 2 Lot 5 Acacia St., Brgy. Matina Crossing, City of Davao, Davao del Sur');
    });

    test('records saved before D2 still load (no migration)', () {
      final legacy = full.toMap()
        ..remove('houseUnit')
        ..['street'] = 'Blk 2 Lot 5, Acacia St.';
      final a = PhAddress.fromMap(legacy);
      expect(a.houseUnit, '');
      expect(a.formatted, 'Blk 2 Lot 5, Acacia St., Brgy. Matina Crossing, City of Davao, Davao del Sur');
      expect(a.isComplete, isTrue);
    });

    test('house number is optional; street is required for a complete address', () {
      expect(full.copyWith(houseUnit: '').isComplete, isTrue);
      expect(full.copyWith(street: '').isComplete, isFalse);
    });
  });

  group('Address form', () {
    Future<PhAddress Function()> pump(WidgetTester tester, {PhAddress initial = PhAddress.empty}) async {
      await tester.runAsync(PhLocations.load);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      var latest = initial;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: PhAddressFields(initial: initial, onChanged: (a) => latest = a),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return () => latest;
    }

    Future<void> pick(WidgetTester tester, String label, String query, String option) async {
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, query);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, option));
      await tester.pumpAndSettle();
    }

    EditableText field(WidgetTester tester, String key) =>
        tester.widget<EditableText>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(EditableText)));

    testWidgets('barangay waits for a city, and is cleared when the city changes', (tester) async {
      final value = await pump(tester);
      expect(tester.widget<TextFormField>(find.byKey(const ValueKey('barangay'))).enabled, isFalse);
      expect(find.text('Choose a city or municipality first'), findsOneWidget);

      await pick(tester, 'Region', 'Davao Region', 'Region XI – Davao Region');
      await pick(tester, 'Province', 'Davao del Sur', 'Davao del Sur');
      await pick(tester, 'City / Municipality', 'Davao', 'City of Davao');
      expect(tester.widget<TextFormField>(find.byKey(const ValueKey('barangay'))).enabled, isTrue);

      await tester.enterText(find.byKey(const ValueKey('barangay')), 'Matina Crossing');
      await tester.enterText(find.byKey(const ValueKey('street')), 'Acacia St.');
      await tester.enterText(find.byKey(const ValueKey('houseUnit')), 'Blk 2 Lot 5');
      await tester.pump();
      expect(value().barangay, 'Matina Crossing');
      expect(value().street, 'Acacia St.');
      expect(value().houseUnit, 'Blk 2 Lot 5');

      // Changing the city clears the typed barangay; street and house stay.
      await pick(tester, 'City / Municipality', 'Digos', 'City of Digos');
      expect(value().cityName, 'City of Digos');
      expect(value().barangay, '');
      expect(field(tester, 'barangay').controller.text, '');
      expect(value().street, 'Acacia St.');
      expect(value().houseUnit, 'Blk 2 Lot 5');
    });

    testWidgets('changing the region clears province, city and barangay', (tester) async {
      const start = PhAddress(
        regionCode: '110000000',
        regionName: 'Region XI – Davao Region',
        provinceCode: '112400000',
        provinceName: 'Davao del Sur',
        cityCode: '112402000',
        cityName: 'City of Davao',
        barangay: 'Matina Crossing',
        street: 'Acacia St.',
      );
      final value = await pump(tester, initial: start);
      expect(field(tester, 'barangay').controller.text, 'Matina Crossing', reason: 'saved address reloads');

      await pick(tester, 'Region', 'National Capital', 'National Capital Region – NCR');
      expect(value().provinceCode, '');
      expect(value().cityCode, '');
      expect(value().barangay, '');
      expect(find.text('Province'), findsNothing, reason: 'NCR has no provinces');
      expect(value().street, 'Acacia St.');
    });

    testWidgets('street is required; house number is optional', (tester) async {
      await pump(tester);
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: SingleChildScrollView(child: Form(key: form, child: PhAddressFields(initial: PhAddress.empty, onChanged: (_) {}))),
        ),
      ));
      await tester.pumpAndSettle();
      form.currentState!.validate();
      await tester.pump();
      expect(find.text('Street is required.'), findsOneWidget);
      expect(find.textContaining('House / building / unit no.'), findsOneWidget);
      expect(find.textContaining('unit no. is required'), findsNothing);
    });
  });
}
