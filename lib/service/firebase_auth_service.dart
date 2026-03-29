import 'package:firebase_auth/firebase_auth.dart';

import '../utils/auth_error_localization.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth;

  FirebaseAuthService(FirebaseAuth? auth)
    : _auth = auth ??= FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

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
          "Email sudah terdaftar. Gunakan email lain.",
        "invalid-email" => "Format email tidak valid.",
        "operation-not-allowed" =>
          "Pendaftaran tidak diizinkan. Hubungi admin.",
        "weak-password" => "Password terlalu lemah.",
        _ => e.message?.trim().isNotEmpty == true
            ? e.message!.trim()
            : "Gagal mendaftar. Silakan coba lagi.",
      };
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception(userFacingAuthError(e));
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
        "invalid-email" => "Format email tidak valid.",
        "user-disabled" => "Akun ini dinonaktifkan.",
        "user-not-found" => "Email tidak terdaftar.",
        "wrong-password" => "Email atau password salah.",
        // Firebase SDK baru sering memakai invalid-credential menggabungkan salah password / tidak ditemukan
        "invalid-credential" => "Email atau password salah.",
        "too-many-requests" =>
          "Terlalu banyak percobaan gagal. Coba lagi nanti.",
        "network-request-failed" =>
          "Koneksi bermasalah. Periksa internet Anda.",
        "operation-not-allowed" =>
          "Login email/password tidak diizinkan. Hubungi admin.",
        _ => e.message?.trim().isNotEmpty == true
            ? e.message!.trim()
            : "Login gagal. Silakan coba lagi.",
      };
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception(userFacingAuthError(e));
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception(
        e is FirebaseAuthException
            ? userFacingAuthError(e)
            : 'Gagal logout. Silakan coba lagi.',
      );
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
