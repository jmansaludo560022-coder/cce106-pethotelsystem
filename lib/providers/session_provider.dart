import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/customer_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum SessionState { loading, signedOut, profileMissing, ready }

enum ProfileStep { ready, listenCustomer, missing }

/// Holds the signed-in user and (for customers) their customer record.
/// All screens read the current cusID from here (Q-01) instead of hardcoding it.
class SessionProvider extends ChangeNotifier {
  final AuthService _auth = AuthService();
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  SessionState state = SessionState.loading;
  UserModel? user;
  CustomerModel? customer;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot>? _userSub;
  StreamSubscription<DocumentSnapshot>? _customerSub;

  SessionProvider() {
    _authSub = _auth.authStateChanges.listen(_onAuth);
  }

  /// Fixed session for widget tests: no Firebase listeners are started.
  @visibleForTesting
  SessionProvider.seeded({required this.state, this.user, this.customer});

  bool get isAdmin => user?.role == UserRole.admin;
  String? get cusID => user?.cusID;

  /// What to do with a loaded user profile (pure, so it can be unit-tested).
  /// Admins are ready immediately; customers need a linked customer record.
  static ProfileStep nextStepFor(UserModel u) {
    if (u.role == UserRole.admin) return ProfileStep.ready;
    return (u.cusID ?? '').trim().isNotEmpty ? ProfileStep.listenCustomer : ProfileStep.missing;
  }

  void _onAuth(User? fbUser) {
    _userSub?.cancel();
    _customerSub?.cancel();
    user = null;
    customer = null;
    if (fbUser == null) {
      state = SessionState.signedOut;
      notifyListeners();
      return;
    }
    state = SessionState.loading;
    notifyListeners();
    // A stream (not a one-time read) so a profile written just after
    // registration is picked up automatically.
    _userSub = _db.collection('users').doc(fbUser.uid).snapshots().listen((doc) {
      if (!doc.exists) {
        user = null;
        state = SessionState.profileMissing;
        notifyListeners();
        return;
      }
      final u = UserModel.fromFirestore(doc);
      if (u.status.toLowerCase() != 'active') {
        _auth.signOut();
        return;
      }
      final cusChanged = user?.cusID != u.cusID;
      user = u;
      // A verified email change only updates the login; copy it to the profile.
      _auth.syncEmailIfChanged(u).catchError((_) {});
      switch (nextStepFor(u)) {
        case ProfileStep.listenCustomer:
          if (cusChanged || _customerSub == null) _listenCustomer(u.cusID!);
        case ProfileStep.ready:
          state = SessionState.ready;
        case ProfileStep.missing:
          // Phase 0.5 fix: a customer account without a linked customer record
          // used to be marked "ready", leaving every customer screen loading
          // forever. Show the "profile missing" screen (with Sign out) instead.
          _customerSub?.cancel();
          _customerSub = null;
          customer = null;
          state = SessionState.profileMissing;
      }
      notifyListeners();
    }, onError: (_) {
      state = SessionState.profileMissing;
      notifyListeners();
    });
  }

  void _listenCustomer(String cusID) {
    _customerSub?.cancel();
    _customerSub = _db.collection('customers').doc(cusID).snapshots().listen((doc) {
      customer = doc.exists ? CustomerModel.fromFirestore(doc) : null;
      state = customer == null ? SessionState.profileMissing : SessionState.ready;
      notifyListeners();
    }, onError: (_) {
      state = SessionState.profileMissing;
      notifyListeners();
    });
  }

  Future<void> signOut() => _auth.signOut();

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    _customerSub?.cancel();
    super.dispose();
  }
}
