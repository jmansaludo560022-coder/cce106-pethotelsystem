import 'dart:convert';

import 'package:flutter/services.dart';

/// One PSGC place (region, province or city/municipality).
class PhPlace {
  final String code;
  final String name;
  const PhPlace(this.code, this.name);
}

/// Philippine Standard Geographic Code data for the address form (spec §10.2),
/// bundled as `assets/psgc/ph_locations.json` so it works offline. Barangays
/// are typed by the user (owner decision), so only regions, provinces and
/// cities/municipalities are included.
class PhLocations {
  /// Pseudo-province for cities that belong to no province outside NCR
  /// (e.g. City of Isabela, City of Cotabato).
  static const String independentCode = '__independent__';
  static const String independentName = 'Independent city (no province)';

  final List<PhPlace> regions;
  final List<(PhPlace, String)> _provinces; // (province, regionCode)
  final List<(PhPlace, String, String)> _cities; // (city, regionCode, provinceCode)

  PhLocations._(this.regions, this._provinces, this._cities);

  static PhLocations? _cache;

  static Future<PhLocations> load() async {
    if (_cache != null) return _cache!;
    final raw = jsonDecode(await rootBundle.loadString('assets/psgc/ph_locations.json')) as Map<String, dynamic>;
    final regions = [for (final r in raw['regions'] as List) PhPlace(r[0] as String, r[1] as String)];
    final provinces = [for (final p in raw['provinces'] as List) (PhPlace(p[0] as String, p[1] as String), p[2] as String)];
    final cities = [for (final c in raw['cities'] as List) (PhPlace(c[0] as String, c[1] as String), c[2] as String, c[3] as String)];
    return _cache = PhLocations._(regions, provinces, cities);
  }

  /// Provinces of a region. Empty for NCR (no provinces), so the province
  /// field is hidden. Regions that also have province-less cities get an
  /// extra "Independent city" choice.
  List<PhPlace> provincesOf(String regionCode) {
    final list = [for (final p in _provinces) if (p.$2 == regionCode) p.$1];
    if (list.isEmpty) return list;
    final hasIndependent = _cities.any((c) => c.$2 == regionCode && c.$3.isEmpty);
    if (hasIndependent) list.add(const PhPlace(independentCode, independentName));
    return list;
  }

  bool regionHasProvinces(String regionCode) => _provinces.any((p) => p.$2 == regionCode);

  /// Cities/municipalities filtered by province, or by region for NCR.
  List<PhPlace> citiesOf(String regionCode, {String? provinceCode}) {
    if (!regionHasProvinces(regionCode)) {
      return [for (final c in _cities) if (c.$2 == regionCode) c.$1];
    }
    final p = provinceCode == independentCode ? '' : provinceCode;
    if (p == null) return const [];
    return [for (final c in _cities) if (c.$2 == regionCode && c.$3 == p) c.$1];
  }
}

/// A structured Philippine address (spec §10.2). Stored as separate fields on
/// the customer record; [formatted] also fills the existing single-line
/// `address` field so current screens and logic keep working.
class PhAddress {
  final String regionCode;
  final String regionName;
  final String provinceCode; // '' for NCR
  final String provinceName;
  final String cityCode;
  final String cityName;
  final String barangay;

  /// Street, subdivision, purok or sitio (decision D2: kept separate from the
  /// house number). Older records stored the whole first line here.
  final String street;

  /// House / building / unit number (decision D2). Optional, because many
  /// rural addresses have none. Empty on records saved before D2.
  final String houseUnit;

  const PhAddress({
    this.regionCode = '',
    this.regionName = '',
    this.provinceCode = '',
    this.provinceName = '',
    this.cityCode = '',
    this.cityName = '',
    this.barangay = '',
    this.street = '',
    this.houseUnit = '',
  });

  static const empty = PhAddress();

  bool get isComplete => regionCode.isNotEmpty && cityCode.isNotEmpty && barangay.trim().isNotEmpty && street.trim().isNotEmpty;

  /// First line: "Blk 2 Lot 5 Acacia St." (house/unit, then street).
  String get line1 => [houseUnit.trim(), street.trim()].where((s) => s.isNotEmpty).join(' ');

  /// "Blk 2 Lot 5 Acacia St., Brgy. Matina Crossing, City of Davao, Davao del Sur"
  String get formatted {
    final province = (provinceName.isEmpty || provinceCode == PhLocations.independentCode) ? '' : provinceName;
    final parts = [
      line1,
      if (barangay.trim().isNotEmpty) 'Brgy. ${barangay.trim()}',
      cityName,
      province,
      if (province.isEmpty) regionName,
    ].where((s) => s.trim().isNotEmpty);
    return parts.join(', ');
  }

  PhAddress copyWith({
    String? regionCode,
    String? regionName,
    String? provinceCode,
    String? provinceName,
    String? cityCode,
    String? cityName,
    String? barangay,
    String? street,
    String? houseUnit,
  }) =>
      PhAddress(
        regionCode: regionCode ?? this.regionCode,
        regionName: regionName ?? this.regionName,
        provinceCode: provinceCode ?? this.provinceCode,
        provinceName: provinceName ?? this.provinceName,
        cityCode: cityCode ?? this.cityCode,
        cityName: cityName ?? this.cityName,
        barangay: barangay ?? this.barangay,
        street: street ?? this.street,
        houseUnit: houseUnit ?? this.houseUnit,
      );

  Map<String, dynamic> toMap() => {
        'regionCode': regionCode,
        'regionName': regionName,
        'provinceCode': provinceCode,
        'provinceName': provinceName,
        'cityCode': cityCode,
        'cityName': cityName,
        'barangay': barangay.trim(),
        'street': street.trim(),
        'houseUnit': houseUnit.trim(),
      };

  factory PhAddress.fromMap(Map<String, dynamic> m) => PhAddress(
        regionCode: m['regionCode'] ?? '',
        regionName: m['regionName'] ?? '',
        provinceCode: m['provinceCode'] ?? '',
        provinceName: m['provinceName'] ?? '',
        cityCode: m['cityCode'] ?? '',
        cityName: m['cityName'] ?? '',
        barangay: m['barangay'] ?? '',
        street: m['street'] ?? '',
        houseUnit: m['houseUnit'] ?? '',
      );
}
