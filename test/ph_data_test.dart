import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pethotelbooking/core/utils/ph_locations.dart';
import 'package:flutter_pethotelbooking/core/utils/ph_phone.dart';

/// Spec §10 Philippine data standards (TC-02 … TC-05).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PH mobile number (§10.1)', () {
    test('TC-02: 09171234567 is stored as +639171234567 and shown as +63 917 123 4567', () {
      expect(PhPhone.normalize('09171234567'), '+639171234567');
      expect(PhPhone.display('09171234567'), '+63 917 123 4567');
    });
    test('pasted forms are normalized', () {
      for (final v in ['+639171234567', '639171234567', '9171234567', '0917-123-4567', '+63 917 123 4567']) {
        expect(PhPhone.normalize(v), '+639171234567', reason: v);
      }
    });
    test('TC-03: 0812345678 or 9 digits are rejected', () {
      expect(PhPhone.normalize('0812345678'), isNull);
      expect(PhPhone.normalize('917123456'), isNull);
      expect(PhPhone.validateLocal('917 123 456'), PhPhone.errorText);
      expect(PhPhone.validateLocal('812 345 6789'), PhPhone.errorText);
      expect(PhPhone.validateLocal('917 123 4567'), isNull);
    });
    test('typing formatter: 9XX XXX XXXX, max 10 digits, paste-friendly', () {
      final f = PhLocalPhoneFormatter();
      TextEditingValue fmt(String s) => f.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: s));
      expect(fmt('9171234567').text, '917 123 4567');
      expect(fmt('917123456789').text, '917 123 4567');
      expect(fmt('09171234567').text, '917 123 4567');
      expect(fmt('+639171234567').text, '917 123 4567');
    });
    test('old stored formats are matched for duplicate checks', () {
      expect(PhPhone.storedVariants('+639171234567'), containsAll(['+639171234567', '09171234567']));
    });
  });

  group('PSGC address (§10.2)', () {
    late PhLocations loc;
    setUpAll(() async => loc = await PhLocations.load());

    PhPlace region(String contains) => loc.regions.firstWhere((r) => r.name.contains(contains));

    test('TC-04: Region XI → Davao del Sur → City of Davao', () {
      final r11 = region('Davao Region');
      final provinces = loc.provincesOf(r11.code);
      final dds = provinces.firstWhere((p) => p.name == 'Davao del Sur');
      final cities = loc.citiesOf(r11.code, provinceCode: dds.code);
      expect(cities.map((c) => c.name), contains('City of Davao'));
      // Filtering: a Davao del Sur list never contains another province's town.
      final ddn = provinces.firstWhere((p) => p.name == 'Davao del Norte');
      expect(loc.citiesOf(r11.code, provinceCode: ddn.code).map((c) => c.name), isNot(contains('City of Davao')));
    });

    test('TC-05: NCR has no provinces; cities are listed directly', () {
      final ncr = region('NCR');
      expect(loc.regionHasProvinces(ncr.code), isFalse);
      expect(loc.provincesOf(ncr.code), isEmpty);
      final cities = loc.citiesOf(ncr.code).map((c) => c.name);
      expect(cities, contains('City of Manila'));
      expect(cities.length, greaterThan(10));
    });

    test('independent cities outside NCR are reachable', () {
      final r9 = region('Zamboanga Peninsula');
      expect(loc.provincesOf(r9.code).last.code, PhLocations.independentCode);
      expect(loc.citiesOf(r9.code, provinceCode: PhLocations.independentCode).map((c) => c.name), contains('City of Isabela'));
    });

    test('formatted address fills the single-line address field', () {
      const a = PhAddress(
        regionCode: '110000000', regionName: 'Region XI – Davao Region',
        provinceCode: '112400000', provinceName: 'Davao del Sur',
        cityCode: '112402000', cityName: 'City of Davao',
        barangay: 'Matina Crossing', street: 'Blk 2 Lot 5, Acacia St.',
      );
      expect(a.isComplete, isTrue);
      expect(a.formatted, 'Blk 2 Lot 5, Acacia St., Brgy. Matina Crossing, City of Davao, Davao del Sur');
      expect(PhAddress.fromMap(a.toMap()).formatted, a.formatted);
    });
  });
}
