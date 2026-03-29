import 'dart:async' show TimeoutException;

import 'package:firebase_auth/firebase_auth.dart';

/// Pesan error autentikasi untuk pengguna (Bahasa Indonesia).
/// Menangani jaringan lambat, timeout, dan teks Firebase berbahasa Inggris.
String userFacingAuthError(Object e) {
  if (e is FirebaseAuthException) {
    return _firebaseAuthToId(e);
  }
  if (e is TimeoutException) {
    return 'Permintaan terlalu lama. Periksa koneksi lalu coba lagi.';
  }

  var raw = e.toString();
  if (raw.startsWith('Exception: ')) {
    raw = raw.substring('Exception: '.length);
  }
  if (raw.startsWith('Exception: ')) {
    raw = raw.substring('Exception: '.length);
  }

  final lower = raw.toLowerCase();

  if (_looksLikeNetworkOrTimeout(lower)) {
    return 'Koneksi bermasalah atau server lambat. Periksa internet lalu coba lagi.';
  }

  if (_looksIndonesian(raw) && raw.length < 220) {
    return raw;
  }

  return 'Terjadi kesalahan. Periksa koneksi lalu coba lagi.';
}

bool _looksIndonesian(String s) {
  const words = [
    'tidak',
    'gagal',
    'periksa',
    'koneksi',
    'password',
    'email',
    'akun',
    'valid',
    'terdaftar',
    'internet',
    'masalah',
    'salah',
    'nonaktif',
    'izinkan',
    'admin',
    'terlalu',
    'coba',
    'lagi',
    'format',
    'lemah',
    'permintaan',
    'server',
    'hubungi',
  ];
  final l = s.toLowerCase();
  return words.any((w) => l.contains(w));
}

bool _looksLikeNetworkOrTimeout(String lower) {
  return lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('connection timed out') ||
      lower.contains('failed to connect') ||
      lower.contains('networkerror') ||
      lower.contains('clientexception') ||
      lower.contains('handshake exception') ||
      lower.contains('connection closed') ||
      lower.contains('timed out') ||
      lower.contains('timeout') ||
      lower.contains('network request failed') ||
      (lower.contains('errno') && lower.contains('network')) ||
      (lower.contains('dns') && lower.contains('error'));
}

String _firebaseAuthToId(FirebaseAuthException e) {
  return switch (e.code) {
    'invalid-email' => 'Format email tidak valid.',
    'user-disabled' => 'Akun ini dinonaktifkan.',
    'user-not-found' => 'Email tidak terdaftar.',
    'wrong-password' => 'Email atau password salah.',
    'invalid-credential' => 'Email atau password salah.',
    'too-many-requests' =>
      'Terlalu banyak percobaan gagal. Coba lagi nanti.',
    'network-request-failed' =>
      'Koneksi bermasalah. Periksa internet Anda.',
    'operation-not-allowed' =>
      'Login email/password tidak diizinkan. Hubungi admin.',
    'email-already-in-use' =>
      'Email sudah terdaftar. Gunakan email lain.',
    'weak-password' => 'Password terlalu lemah.',
    'invalid-verification-code' => 'Kode verifikasi tidak valid.',
    'session-expired' => 'Sesi habis. Silakan login lagi.',
    _ => _firebaseMessageFallback(e),
  };
}

String _firebaseMessageFallback(FirebaseAuthException e) {
  final m = e.message?.trim();
  if (m != null && m.isNotEmpty) {
    final ml = m.toLowerCase();
    if (ml.contains('network') ||
        ml.contains('connection') ||
        ml.contains('timed out') ||
        ml.contains('internet')) {
      return 'Koneksi bermasalah. Periksa internet lalu coba lagi.';
    }
    if (ml.contains('internal error') || ml.contains('error has occurred')) {
      return 'Login gagal sementara. Coba lagi dalam beberapa saat.';
    }
    if (_looksIndonesian(m)) {
      return m;
    }
  }
  return 'Login gagal. Silakan coba lagi.';
}
