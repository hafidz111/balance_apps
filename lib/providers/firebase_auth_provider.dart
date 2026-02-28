import 'package:flutter/widgets.dart';

import '../data/model/profile.dart';
import '../service/firebase_auth_service.dart';
import '../static/firebase_auth_status.dart';

class FirebaseAuthProvider extends ChangeNotifier {
  final FirebaseAuthService _service;

  FirebaseAuthProvider(this._service);

  String? _message;
  Profile? _profile;
  FirebaseAuthStatus _authStatus = FirebaseAuthStatus.unauthenticated;

  Profile? get profile => _profile;

  String? get message => _message;

  FirebaseAuthStatus get authStatus => _authStatus;

  Future createAccount(String email, String password) async {
    try {
      _authStatus = FirebaseAuthStatus.creatingAccount;
      notifyListeners();

      await _service.createUser(email, password);

      _authStatus = FirebaseAuthStatus.accountCreated;
      _message = "Berhasil Buat Akun!";
    } catch (e) {
      _message = e.toString();
      _authStatus = FirebaseAuthStatus.error;
    }
    notifyListeners();
  }

  Future signInUser(String email, String password) async {
    try {
      _authStatus = FirebaseAuthStatus.authenticating;
      notifyListeners();

      final result = await _service.signInUser(email, password);

      _profile = Profile(
        uid: result.user?.uid,
        name: result.user?.displayName,
        email: result.user?.email,
        photoUrl: result.user?.photoURL,
      );

      _authStatus = FirebaseAuthStatus.authenticated;
      _message = "Login Berhasil!";
    } catch (e) {
      _message = e.toString();
      _authStatus = FirebaseAuthStatus.error;
    }
    notifyListeners();
  }

  Future signOutUser() async {
    try {
      _authStatus = FirebaseAuthStatus.signingOut;
      notifyListeners();

      await _service.signOut();

      _profile = null;

      _authStatus = FirebaseAuthStatus.unauthenticated;
      _message = "Logout Berhasil!";
    } catch (e) {
      _message = e.toString();
      _authStatus = FirebaseAuthStatus.error;
    }
    notifyListeners();
  }

  Future updateProfile() async {
    final user = await _service.userChanges();
    _profile = Profile(
      uid: user?.uid,
      name: user?.displayName,
      email: user?.email,
      photoUrl: user?.photoURL,
    );
    notifyListeners();
  }
}
