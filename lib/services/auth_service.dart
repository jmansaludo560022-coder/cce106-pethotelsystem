import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../core/utils/ph_locations.dart';
import '../core/utils/ph_phone.dart';
import '../core/utils/validators.dart';
import '../models/customer_model.dart';
import '../models/user_model.dart';

/// Authentication (master spec §9.1).
class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  User? get currentFirebaseUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// AUTH-002. The password is used exactly as typed (it is no longer trimmed),
  /// and accounts whose status is not "Active" cannot sign in (AUTH-006).
  Future<UserModel> signIn({required String email, required String password}) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: Validators.normalizeEmail(email), password: password);
      final doc = await _db.collection('users').doc(cred.user!.uid).get();
      if (!doc.exists) {
        await _auth.signOut();
        throw AuthFailure('Your account profile was not found. Please contact the hotel.');
      }
      final user = UserModel.fromFirestore(doc);
      if (user.status.toLowerCase() != 'active') {
        await _auth.signOut();
        throw AuthFailure('This account is not active. Please contact the hotel.');
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  /// AUTH-003. Creates the Auth account, then the customers + users documents
  /// in one batch. If a walk-in customer record already exists with the same
  /// email it is linked to the new account instead of creating a duplicate
  /// (Q-05). If the profile write fails, the new Auth account is deleted so no
  /// orphan login remains.
  Future<void> registerCustomer({
    required String email,
    required String password,
    required String username,
    required String firstName,
    String middleName = '',
    required String lastName,
    required String phone,
    required PhAddress address,
  }) async {
    // Spec §10.1: stored as +639XXXXXXXXX.
    final phoneE164 = PhPhone.normalize(phone);
    if (phoneE164 == null) throw AuthFailure(PhPhone.errorText);
    if (!address.isComplete) throw AuthFailure('Please complete your address.');
    final normalizedEmail = Validators.normalizeEmail(email);
    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(email: normalizedEmail, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
    try {
      await _createCustomerProfile(
        uid: cred.user!.uid,
        email: normalizedEmail,
        username: username,
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        phoneE164: phoneE164,
        address: address,
      );
    } catch (e) {
      // Roll back the Auth account so the email can be used again.
      try {
        await cred.user?.delete();
      } catch (_) {}
      await _auth.signOut();
      throw AuthFailure('We could not finish creating your account. Please try again. (${e.toString()})');
    }
  }

  /// First sign-in with Google (or any login without a profile yet): creates
  /// the customer + user documents for the signed-in account. The login
  /// itself already exists, so nothing is rolled back on failure; the user
  /// can simply try again.
  Future<void> completeProfileForCurrentUser({
    required String username,
    required String firstName,
    String middleName = '',
    required String lastName,
    required String phone,
    required PhAddress address,
  }) async {
    final user = _auth.currentUser;
    if (user == null || (user.email ?? '').isEmpty) throw AuthFailure('Please sign in again.');
    final phoneE164 = PhPhone.normalize(phone);
    if (phoneE164 == null) throw AuthFailure(PhPhone.errorText);
    if (!address.isComplete) throw AuthFailure('Please complete your address.');
    await _createCustomerProfile(
      uid: user.uid,
      email: Validators.normalizeEmail(user.email!),
      username: username,
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      phoneE164: phoneE164,
      address: address,
    );
  }

  /// Writes customers/{cusID} and users/{uid} in one batch. An unlinked
  /// walk-in record with the same email is linked instead of duplicated (Q-05).
  Future<void> _createCustomerProfile({
    required String uid,
    required String email,
    required String username,
    required String firstName,
    required String middleName,
    required String lastName,
    required String phoneE164,
    required PhAddress address,
  }) async {
    final normalizedEmail = email;
    {
      final batch = _db.batch();

      // Look for an unlinked walk-in record with this email.
      final existing = await _db.collection('customers').where('email', isEqualTo: normalizedEmail).where('isWalkIn', isEqualTo: true).limit(1).get();

      final DocumentReference<Map<String, dynamic>> customerRef = existing.docs.isNotEmpty ? existing.docs.first.reference : _db.collection('customers').doc();

      final customer = CustomerModel(
        cusID: customerRef.id,
        userID: uid,
        cusFName: firstName.trim(),
        cusMName: middleName.trim(),
        cusLName: lastName.trim(),
        phoneNum: phoneE164,
        email: normalizedEmail,
        address: address.formatted,
        phAddress: address,
        isWalkIn: false,
      );
      if (existing.docs.isNotEmpty) {
        batch.update(customerRef, {
          'userID': uid,
          'isWalkIn': false,
          'cusFName': customer.cusFName,
          'cusMName': customer.cusMName,
          'cusLName': customer.cusLName,
          'phoneNum': customer.phoneNum,
          'address': customer.address,
          'phAddress': customer.phAddress.toMap(),
        });
      } else {
        batch.set(customerRef, customer.toMap());
      }

      final user = UserModel(userID: uid, username: username.trim(), email: normalizedEmail, role: UserRole.customer, status: 'Active', cusID: customerRef.id);
      batch.set(_db.collection('users').doc(uid), user.toMap());
      await batch.commit();
    }
  }

  // ------------------------------------------------------------------
  // Google sign-in (owner decision 2026-10-03: Google + email/password)
  // ------------------------------------------------------------------

  /// Opens Google sign-in (a popup on the web, the system sign-in flow on
  /// Android/iOS) through Firebase Authentication. Returns false when the
  /// user closes the window. New Google users have no profile yet; the app
  /// then shows the "Complete your profile" screen.
  Future<bool> signInWithGoogle() async {
    final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
    try {
      if (kIsWeb) {
        await _auth.signInWithPopup(provider);
      } else {
        await _auth.signInWithProvider(provider);
      }
      return true;
    } on FirebaseAuthException catch (e) {
      if (const ['popup-closed-by-user', 'cancelled-popup-request', 'web-context-canceled', 'canceled', 'user-cancelled'].contains(e.code)) {
        return false;
      }
      throw AuthFailure(_messageFor(e));
    }
  }

  /// How the signed-in user signs in: 'password', 'google.com', …
  List<String> get signInMethods => _auth.currentUser?.providerData.map((p) => p.providerId).toList() ?? const [];
  bool get hasPassword => signInMethods.contains(EmailAuthProvider.PROVIDER_ID);

  // ------------------------------------------------------------------
  // Account security (Personal Information screen)
  // ------------------------------------------------------------------

  /// Change Password: Firebase requires a recent login, so the current
  /// password is checked first (re-authentication). Passwords are never
  /// stored in Firestore.
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw AuthFailure('Please sign in again.');
    if (!hasPassword) throw AuthFailure('You sign in with Google, so there is no app password to change. Manage your password in your Google account.');
    try {
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: currentPassword));
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  /// Change email (owner decision: verification link). Firebase sends a link
  /// to the NEW address; the sign-in email changes only after it is opened.
  /// The profile copy is updated by [syncEmailIfChanged] on the next sign-in.
  Future<void> requestEmailChange({required String newEmail, required String currentPassword}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw AuthFailure('Please sign in again.');
    if (!hasPassword) throw AuthFailure('Your email comes from your Google account and cannot be changed here.');
    final email = Validators.normalizeEmail(newEmail);
    if (email == Validators.normalizeEmail(user.email!)) throw AuthFailure('That is already your email address.');
    try {
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: currentPassword));
      await user.verifyBeforeUpdateEmail(email);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  /// After a verified email change, copy the new sign-in email to the
  /// user and customer records so every screen shows the same address.
  Future<void> syncEmailIfChanged(UserModel profile) async {
    final authEmail = Validators.normalizeEmail(_auth.currentUser?.email ?? '');
    if (authEmail.isEmpty || authEmail == Validators.normalizeEmail(profile.email)) return;
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(profile.userID), {'email': authEmail});
    if ((profile.cusID ?? '').isNotEmpty) batch.update(_db.collection('customers').doc(profile.cusID), {'email': authEmail});
    await batch.commit();
  }

  /// AUTH-005 (Q-18 approved): Firebase password-reset email.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: Validators.normalizeEmail(email));
    } on FirebaseAuthException catch (e) {
      // Do not reveal whether the email exists.
      if (e.code == 'user-not-found') return;
      throw AuthFailure(_messageFor(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for this email. Try signing in instead.';
      case 'weak-password':
        return 'Please choose a stronger password (at least 6 characters).';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'requires-recent-login':
        return 'For your security, please sign out and sign in again, then retry.';
      case 'account-exists-with-different-credential':
        return 'This email already has a Pet Hotel account. Sign in with your email and password instead.';
      case 'operation-not-allowed':
        return 'This sign-in method is not turned on for the app yet. Please use email and password.';
      case 'popup-blocked':
        return 'Your browser blocked the Google sign-in window. Allow pop-ups for this site and try again.';
      case 'unauthorized-domain':
        return 'Google sign-in is not set up for this web address yet. Please use email and password.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}

class AuthFailure implements Exception {
  final String message;
  AuthFailure(this.message);
  @override
  String toString() => message;
}
