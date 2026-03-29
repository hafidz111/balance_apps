import 'package:flutter/material.dart';

import '../service/shared_preferences_service.dart';

/// Format disimpan ke prefs: `HH:mm – HH:mm` (en dash).
/// Di UI: empat field angka `HH : MM - HH : MM`.
class ShiftTimeUtils {
  ShiftTimeUtils._();

  static const String enDash = '\u2013';

  /// 8 digit dari label prefs (tanpa mask).
  static String eightDigitsFromLabel(String raw) {
    if (raw.trim().isEmpty) return '';
    final t = SharedPreferencesService.jamKerjaSubtitle(raw);
    final p = tryParseRange(t);
    if (p == null) return '';
    return '${p.start.hour.toString().padLeft(2, '0')}'
        '${p.start.minute.toString().padLeft(2, '0')}'
        '${p.end.hour.toString().padLeft(2, '0')}'
        '${p.end.minute.toString().padLeft(2, '0')}';
  }

  /// Isi 4 controller [jamMulai, menitMulai, jamSelesai, menitSelesai] dari prefs.
  static void setRowFromStoredLabel(
    List<TextEditingController> row,
    String raw,
  ) {
    if (row.length != 4) return;
    final ds = eightDigitsFromLabel(raw);
    if (ds.length != 8) {
      for (final c in row) {
        c.clear();
      }
      return;
    }
    row[0].text = ds.substring(0, 2);
    row[1].text = ds.substring(2, 4);
    row[2].text = ds.substring(4, 6);
    row[3].text = ds.substring(6, 8);
  }

  /// Gabung 4 field → 8 digit; null jika kosong / bukan angka / di luar jam-menit.
  static String? rowToEightDigits(List<TextEditingController> row) {
    if (row.length != 4) return null;
    final parts = row.map((e) => e.text.trim()).toList();
    if (parts.any((p) => p.isEmpty)) return null;
    final h1 = int.tryParse(parts[0]);
    final m1 = int.tryParse(parts[1]);
    final h2 = int.tryParse(parts[2]);
    final m2 = int.tryParse(parts[3]);
    if (h1 == null || m1 == null || h2 == null || m2 == null) return null;
    if (h1 > 23 || h2 > 23 || m1 > 59 || m2 > 59) return null;
    return '${h1.toString().padLeft(2, '0')}'
        '${m1.toString().padLeft(2, '0')}'
        '${h2.toString().padLeft(2, '0')}'
        '${m2.toString().padLeft(2, '0')}';
  }

  /// 8 angka persis: jam₁ menit₁ jam₂ menit₂ → validasi 00–23 / 00–59.
  static ({TimeOfDay start, TimeOfDay end})? tryParseEightDigits(String digits) {
    final d = digits.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length != 8) return null;
    final h1 = int.parse(d.substring(0, 2));
    final m1 = int.parse(d.substring(2, 4));
    final h2 = int.parse(d.substring(4, 6));
    final m2 = int.parse(d.substring(6, 8));
    if (h1 > 23 || h2 > 23 || m1 > 59 || m2 > 59) return null;
    return (
      start: TimeOfDay(hour: h1, minute: m1),
      end: TimeOfDay(hour: h2, minute: m2),
    );
  }

  static String formatRange(TimeOfDay start, TimeOfDay end) {
    return '${_fmt(start)} $enDash ${_fmt(end)}';
  }

  static String _fmt(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Parse dari teks prefs; [fallback] dipakai jika tidak cocok regex.
  static ({TimeOfDay start, TimeOfDay end}) parseOrFallback(
    String raw,
    TimeOfDay fallbackStart,
    TimeOfDay fallbackEnd,
  ) {
    final t = SharedPreferencesService.jamKerjaSubtitle(raw);
    final parsed = tryParseRange(t);
    if (parsed != null) return parsed;
    return (start: fallbackStart, end: fallbackEnd);
  }

  /// Default dari [SharedPreferencesService.defaultShiftTimeLabels] per indeks.
  static ({TimeOfDay start, TimeOfDay end}) defaultRangeForIndex(int index) {
    final i = index.clamp(0, 3);
    final raw =
        SharedPreferencesService.jamKerjaSubtitle(
          SharedPreferencesService.defaultShiftTimeLabels[i],
        );
    final p = tryParseRange(raw);
    if (p != null) return p;
    return (
      start: const TimeOfDay(hour: 8, minute: 0),
      end: const TimeOfDay(hour: 16, minute: 0),
    );
  }

  /// Parse rentang `HH:mm – HH:mm` (tire atau en dash).
  static ({TimeOfDay start, TimeOfDay end})? tryParseRange(String raw) {
    final re = RegExp(
      r'^(\d{1,2})\s*:\s*(\d{2})\s*[–-]\s*(\d{1,2})\s*:\s*(\d{2})\s*$',
    );
    final m = re.firstMatch(raw.trim());
    if (m == null) return null;
    final sh = int.parse(m.group(1)!);
    final sm = int.parse(m.group(2)!);
    final eh = int.parse(m.group(3)!);
    final em = int.parse(m.group(4)!);
    if (sh > 23 || eh > 23 || sm > 59 || em > 59) {
      return null;
    }
    return (
      start: TimeOfDay(hour: sh, minute: sm),
      end: TimeOfDay(hour: eh, minute: em),
    );
  }
}
