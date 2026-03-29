import 'package:flutter/material.dart';

/// Palet warna aplikasi Starvy — satu sumber kebenaran supaya UI konsisten.
///
/// Gunakan [AppColors] di seluruh widget; hindari `Color(0xFF...)` tersebar.
abstract final class AppColors {
  AppColors._();

  // —————————————————————————————————————————————————————————
  // Brand (teal)
  // —————————————————————————————————————————————————————————

  /// Warna utama brand / tombol utama / AppBar.
  static const Color primary = Color(0xFF009688);

  /// Varian gelap (gradient login, teks aksen pada surface terang).
  static const Color primaryDark = Color(0xFF00695C);

  /// Surface / highlight sangat terang (mis. baris tabel history).
  static const Color primaryLight = Color(0xFFE0F2F1);

  /// Konten di atas [primary].
  static const Color onPrimary = Color(0xFFFFFFFF);

  // —————————————————————————————————————————————————————————
  // Theme Material ([ThemeData] / [ColorScheme.fromSeed])
  // —————————————————————————————————————————————————————————

  /// Benih tema (setara `Colors.deepPurple` untuk Material 3).
  static const Color themeSeed = Color(0xFF673AB7);

  // —————————————————————————————————————————————————————————
  // Grid foto & editor
  // —————————————————————————————————————————————————————————

  /// Aksen hijau (lingkaran warna, switch) di editor grid background.
  static const Color gridGreen = Color(0xFF038343);

  /// String hex untuk field teks warna (sama dengan [gridGreen]).
  static const String gridGreenHex = '#038343';

  /// Kartu menu di layar Space (background + ikon per indeks).
  static const List<Map<String, Color>> gridMenuCardColors = [
    {'bg': Color(0xFFE3F2FD), 'icon': Color(0xFF1976D2)},
    {'bg': Color(0xFFFFF3E0), 'icon': Color(0xFFF57C00)},
    {'bg': Color(0xFFE8F5E9), 'icon': Color(0xFF388E3C)},
    {'bg': Color(0xFFF3E5F5), 'icon': Color(0xFF7B1FA2)},
    {'bg': Color(0xFFFFEBEE), 'icon': Color(0xFFD32F2F)},
    {'bg': Color(0xFFE0F7FA), 'icon': Color(0xFF00838F)},
  ];

  // —————————————————————————————————————————————————————————
  // Aksi & status
  // —————————————————————————————————————————————————————————

  /// Tombol aksi positif (mis. Spotify-style di [ActionButtons]).
  static const Color actionPositive = Color(0xFF1DB954);

  // —————————————————————————————————————————————————————————
  // Barcode
  // —————————————————————————————————————————————————————————

  /// Aksen biru untuk kartu / QR.
  static const Color barcodeQrBlue = Color(0xFF2196F3);

  /// Aksen abu gelap untuk Code128 / netral.
  static const Color barcodeNeutralDark = Color(0xFF37474F);

  // —————————————————————————————————————————————————————————
  // Form & dialog
  // —————————————————————————————————————————————————————————

  /// Latar field isian (filled).
  static const Color fieldFill = Color(0xFFF5F5F5);
}
