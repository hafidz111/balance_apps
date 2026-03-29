import 'dart:async' show TimeoutException;

/// Mengubah [error] (Exception, Firebase, jaringan) menjadi teks singkat **Bahasa Indonesia**
/// untuk snackbar/dialog — tanpa prefix `Exception:` atau stack teknis.
String userFriendlyError(
  Object? error, {
  String fallback = 'Terjadi kesalahan. Coba lagi nanti.',
}) {
  if (error == null) return fallback;

  if (error is TimeoutException) {
    return 'Permintaan terlalu lama. Periksa koneksi lalu coba lagi.';
  }

  var raw = error.toString();
  while (raw.startsWith('Exception: ')) {
    raw = raw.substring(11);
  }
  while (raw.startsWith('Exception:')) {
    raw = raw.substring(10).trim();
  }

  if (raw.startsWith('Instance of ') || raw.contains('\n')) {
    return fallback;
  }

  final lower = raw.toLowerCase();

  if (_isNetworkLike(lower)) {
    return 'Koneksi bermasalah. Periksa internet lalu coba lagi.';
  }
  if (lower.contains('timed out') || lower.contains('timeout')) {
    return 'Permintaan terlalu lama. Coba lagi.';
  }
  if (lower.contains('permission-denied') ||
      lower.contains('permission denied')) {
    return 'Akses ditolak. Periksa login atau aturan keamanan data.';
  }
  if (lower.contains('unavailable')) {
    return 'Layanan sementara tidak tersedia. Coba lagi nanti.';
  }
  if (lower.contains('quota') || lower.contains('resource exhausted')) {
    return 'Batas penggunaan tercapai. Coba lagi nanti.';
  }

  if (_looksIndonesian(raw) && raw.length < 200) {
    return raw;
  }

  // Pesan Firebase/Dart pendek masih bahasa Inggris → ringkas
  if (raw.length <= 90 && !raw.contains(' at ')) {
    if (lower.contains('firebase') && lower.contains('error')) {
      return 'Gagal berkomunikasi dengan server. Coba lagi.';
    }
    // Tetap tampilkan jika terbaca manusiawi (kalimat)
    if (raw.contains(' ') && !lower.contains('exception')) {
      return raw;
    }
  }

  return fallback;
}

bool _isNetworkLike(String lower) {
  return lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('clientexception') ||
      lower.contains('handshake exception') ||
      (lower.contains('connection') &&
          (lower.contains('refused') ||
              lower.contains('reset') ||
              lower.contains('closed') ||
              lower.contains('aborted'))) ||
      (lower.contains('network') && lower.contains('error'));
}

bool _looksIndonesian(String s) {
  const words = [
    'tidak',
    'gagal',
    'periksa',
    'koneksi',
    'login',
    'data',
    'server',
    'internet',
    'masalah',
    'coba',
    'lagi',
    'akses',
    'cadang',
    'sinkron',
  ];
  final l = s.toLowerCase();
  return words.any((w) => l.contains(w));
}
