import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/ph_locations.dart';
import '../core/utils/ph_phone.dart';
import '../core/utils/validators.dart';
import '../models/customer_model.dart';

/// Customer records — registered and walk-in (WALK-001, WALK-002).
class CustomerService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('customers');

  Stream<CustomerModel?> streamCustomer(String cusID) =>
      _col.doc(cusID).snapshots().map((d) => d.exists ? CustomerModel.fromFirestore(d) : null);

  /// Admin only (enforced by security rules).
  Stream<List<CustomerModel>> streamAll() => _col.snapshots().map((s) {
        final list = s.docs.map(CustomerModel.fromFirestore).toList();
        list.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
        return list;
      });

  /// Updates only the editable profile fields (never email, userID or flags),
  /// so unrelated fields are not overwritten.
  /// Spec §10: phone stored as +63…, structured address stored in `phAddress`
  /// and the single-line `address` kept filled with the formatted address.
  Future<void> updateProfile(String cusID, {required String firstName, String middleName = '', required String lastName, required String phone, required PhAddress address}) {
    final e164 = PhPhone.normalize(phone);
    if (e164 == null) throw Exception(PhPhone.errorText);
    if (!address.isComplete) throw Exception('Please complete the address.');
    return _col.doc(cusID).update({
      'cusFName': firstName.trim(),
      'cusMName': middleName.trim(),
      'cusLName': lastName.trim(),
      'phoneNum': e164,
      'address': address.formatted,
      'phAddress': address.toMap(),
    });
  }

  // ---- Personal Information editors (one field group at a time) ----

  Future<void> updateName(String cusID, {required String firstName, String middleName = '', required String lastName}) {
    if (firstName.trim().isEmpty || lastName.trim().isEmpty) throw Exception('First and last name are required.');
    return _col.doc(cusID).update({'cusFName': firstName.trim(), 'cusMName': middleName.trim(), 'cusLName': lastName.trim()});
  }

  /// Stored as +639XXXXXXXXX (spec §10.1).
  Future<void> updatePhone(String cusID, String phone) {
    final e164 = PhPhone.normalize(phone);
    if (e164 == null) throw Exception(PhPhone.errorText);
    return _col.doc(cusID).update({'phoneNum': e164});
  }

  /// Structured address plus the single-line copy used by existing screens.
  Future<void> updateAddress(String cusID, PhAddress address) {
    if (!address.isComplete) throw Exception('Please complete the address.');
    return _col.doc(cusID).update({'address': address.formatted, 'phAddress': address.toMap()});
  }

  /// WALK-001: create a customer record WITHOUT a Firebase Auth account.
  /// Rejects duplicates by email or phone (Q-05) and returns the existing
  /// record in [DuplicateCustomerException] so the admin can reuse it.
  Future<CustomerModel> createWalkIn({
    required String firstName,
    String middleName = '',
    required String lastName,
    required String email,
    required String phone,
    required PhAddress address,
  }) async {
    final e = Validators.normalizeEmail(email);
    final p = PhPhone.normalize(phone);
    if (p == null) throw Exception(PhPhone.errorText);
    if (!address.isComplete) throw Exception('Please complete the address.');
    final byEmail = await _col.where('email', isEqualTo: e).limit(1).get();
    if (byEmail.docs.isNotEmpty) throw DuplicateCustomerException(CustomerModel.fromFirestore(byEmail.docs.first), 'email');
    // Older records may store the number as 09…, so check every stored form.
    final byPhone = await _col.where('phoneNum', whereIn: PhPhone.storedVariants(p)).limit(1).get();
    if (byPhone.docs.isNotEmpty) throw DuplicateCustomerException(CustomerModel.fromFirestore(byPhone.docs.first), 'phone number');

    final ref = _col.doc();
    final c = CustomerModel(
      cusID: ref.id,
      userID: null,
      cusFName: firstName.trim(),
      cusMName: middleName.trim(),
      cusLName: lastName.trim(),
      phoneNum: p,
      email: e,
      address: address.formatted,
      phAddress: address,
      isWalkIn: true,
    );
    await ref.set(c.toMap());
    return c;
  }
}

class DuplicateCustomerException implements Exception {
  final CustomerModel existing;
  final String field;
  DuplicateCustomerException(this.existing, this.field);
  @override
  String toString() => 'A customer with this $field already exists: ${existing.fullName}.';
}
