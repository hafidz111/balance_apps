import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth;

  FirebaseAuthService(FirebaseAuth? auth)
    : _auth = auth ??= FirebaseAuth.instance;

  Future<UserCredential> createUser(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result;
    } on FirebaseAuthException catch (e) {
      final errorMessage = switch (e.code) {
        "email-already-in-use" =>
          "There already exists an account with the given email address.",
        "invalid-email" => "The email address is not valid.",
        "operation-not-allowed" => "Server error, please try again later.",
        "weak-password" => "The password is not strong enough.",
        _ => "Register failed. Please try again.",
      };
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<UserCredential> signInUser(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result;
    } on FirebaseAuthException catch (e) {
      final errorMessage = switch (e.code) {
        "invalid-email" => "The email address is not valid.",
        "user-disabled" => "User disabled.",
        "user-not-found" => "No user found with this email.",
        "wrong-password" => "Wrong email/password combination.",
        _ => "Login failed. Please try again.",
      };
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception(e);
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception("Logout failed. Please try again.");
    }
  }

  Future<void> updateDisplayName(String name) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception("User tidak ditemukan");
      }

      await user.updateDisplayName(name);
      await user.reload();
    } on FirebaseAuthException catch (e) {
      throw Exception("Gagal update nama: ${e.message}");
    } catch (e) {
      throw Exception("Terjadi kesalahan saat update nama");
    }
  }

  Future<User?> userChanges() => _auth.userChanges().first;
}
