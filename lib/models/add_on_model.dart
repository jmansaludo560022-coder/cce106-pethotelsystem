import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/logic/booking_rules.dart';

class AddOnModel {
  final String addOnID;
  final String addOnName; // 'Grooming', 'Nail Trimming', 'Training Session'
  final double price;
  final int timesUsed;

  /// Short customer-facing description (decision D6). Optional.
  final String description;

  /// [AddOnUnits.perStay] or [AddOnUnits.perDay] (decision D6).
  final String unit;

  /// Inactive add-ons are hidden from customers and new bookings, but kept so
  /// past bookings and reports still make sense (decision D6).
  final bool isActive;

  AddOnModel({
    required this.addOnID,
    required this.addOnName,
    required this.price,
    this.timesUsed = 0,
    this.description = '',
    this.unit = AddOnUnits.perStay,
    this.isActive = true,
  });

  String get unitLabel => AddOnUnits.label(unit);

  static const int maxDescriptionLength = 120;

  /// Decision D6: what customers may see and book.
  static List<AddOnModel> activeOnly(Iterable<AddOnModel> list) => list.where((a) => a.isActive).toList();

  factory AddOnModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AddOnModel(
      addOnID: doc.id,
      addOnName: data['addOnName'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      timesUsed: (data['timesUsed'] as num?)?.toInt() ?? 0,
      // Records saved before D6 lack these fields: no description, per stay, active.
      description: (data['description'] as String?)?.trim() ?? '',
      unit: AddOnUnits.normalize(data['unit'] as String?),
      isActive: data['isActive'] is bool ? data['isActive'] as bool : true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'addOnID': addOnID,
      'addOnName': addOnName,
      'price': price,
      'timesUsed': timesUsed,
      'description': description,
      'unit': unit,
      'isActive': isActive,
    };
  }
}

class SelectedAddOn {
  final String addOnID;
  final String addOnName;
  final double price;
  final int quantity;

  /// Snapshot of how it was charged when booked (D6), so later changes to
  /// the add-on never change an existing booking's price.
  final String unit;

  /// Nights charged for a per-day add-on; 1 for per stay.
  final int days;

  SelectedAddOn({
    required this.addOnID,
    required this.addOnName,
    required this.price,
    this.quantity = 1,
    this.unit = AddOnUnits.perStay,
    this.days = 1,
  });

  bool get isPerDay => unit == AddOnUnits.perDay;
  double get subtotal => price * quantity * (isPerDay ? days : 1);
  AddOnLine get line => AddOnLine(price, quantity, isPerDay ? days : 1);

  /// "Grooming × 1" or "Daycare × 1 · 3 days".
  String get lineLabel => isPerDay ? '$addOnName × $quantity · $days day${days == 1 ? '' : 's'}' : '$addOnName × $quantity';

  factory SelectedAddOn.fromMap(Map<String, dynamic> map) {
    return SelectedAddOn(
      addOnID: map['addOnID'] ?? '',
      addOnName: map['addOnName'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      // Bookings made before D6 have neither field: per stay, 1 day (unchanged totals).
      unit: AddOnUnits.normalize(map['unit'] as String?),
      days: (map['days'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'addOnID': addOnID,
      'addOnName': addOnName,
      'price': price,
      'quantity': quantity,
      'unit': unit,
      'days': days,
    };
  }
}
