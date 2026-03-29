import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../data/model/barcode_data.dart';
import '../data/model/point_coffe_history.dart';
import '../data/model/say_bread_history.dart';
import 'shared_preferences_service.dart';

/// Dilempar dari [BarcodeFirebaseService.syncAll] bila barcode, point coffee,
/// dan say bread **semuanya** tidak punya data di server.
class SyncNoServerDataException implements Exception {
  const SyncNoServerDataException();

  @override
  String toString() => 'Tidak ada data di server.';
}

class BarcodeFirebaseService {
  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        "https://balance-apps-991c6-default-rtdb.asia-southeast1.firebasedatabase.app",
  );

  late final DatabaseReference _db = _database.ref();

  String getCurrentMonthKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}";
  }

  Future<void> saveUserInfo(String uid, String email) async {
    final ref = _db.child("users/$uid/email");

    final snapshot = await ref.get();

    if (!snapshot.exists) {
      await ref.set(email);
    }
  }

  Future<void> backupAll(String uid, String email) async {
    if (email.isNotEmpty && email != "unknown") {
      await saveUserInfo(uid, email);
    }

    final monthKey = getCurrentMonthKey();

    final pc = await SharedPreferencesService().getPointCoffee();
    final sb = await SharedPreferencesService().getSayBread();
    final barcodes = await SharedPreferencesService().getBarcodes();

    await _db.child("users/$uid/barcode_backup/latest").set({
      "barcodes": barcodes.map((e) => e.toJson()).toList(),
      "updatedAt": ServerValue.timestamp,
    });

    await _db.child("users/$uid/point_coffee/$monthKey").set({
      "data": pc.map((e) => e.toJson()).toList(),
      "updatedAt": ServerValue.timestamp,
    });

    await _db.child("users/$uid/say_bread/$monthKey").set({
      "data": sb.map((e) => e.toJson()).toList(),
      "updatedAt": ServerValue.timestamp,
    });

    final now = DateTime.now();
    await SharedPreferencesService().saveLastBackupTime(now);

    FirebaseAnalytics.instance.logEvent(name: "backup_all_success");
  }

  Future<void> deleteOldMonths(String uid) async {
    final snapshot = await _db.child("users/$uid/point_coffee").get();

    if (!snapshot.exists) return;

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final currentMonth = getCurrentMonthKey();

    for (final key in data.keys) {
      if (key != currentMonth) {
        await _db.child("users/$uid/point_coffee/$key").remove();
      }
    }

    final sbSnapshot = await _db.child("users/$uid/say_bread").get();

    if (!sbSnapshot.exists) return;

    final sbData = Map<String, dynamic>.from(sbSnapshot.value as Map);

    for (final key in sbData.keys) {
      if (key != currentMonth) {
        await _db.child("users/$uid/say_bread/$key").remove();
      }
    }
  }

  Future<DateTime?> getLastBackupTime(String uid) async {
    final snapshot = await _db
        .child("users/$uid/barcode_backup/latest/updatedAt")
        .get();

    if (!snapshot.exists) return null;

    final timestamp = snapshot.value as int;

    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// `true` jika server punya data barcode (bukan kosong) dan berhasil di-merge.
  Future<bool> syncBarcodes(String uid) async {
    final snapshot = await _db
        .child("users/$uid/barcode_backup/latest/barcodes")
        .get();

    if (!snapshot.exists) {
      FirebaseAnalytics.instance.logEvent(
        name: "sync_barcode_skipped_no_server",
      );
      return false;
    }

    final data = snapshot.value as List?;

    if (data == null || data.isEmpty) {
      FirebaseAnalytics.instance.logEvent(
        name: "sync_barcode_skipped_empty_server",
      );
      return false;
    }

    final firebaseBarcodes = data
        .map((e) => BarcodeData.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final localBarcodes = await SharedPreferencesService().getBarcodes();

    final merged = [...localBarcodes];

    for (final fb in firebaseBarcodes) {
      final exists = merged.any((e) => e.code == fb.code && e.type == fb.type);

      if (!exists) {
        merged.add(fb);
      }
    }

    await SharedPreferencesService().saveBarcodes(merged);

    await _db
        .child("users/$uid/barcode_backup/latest/lastSyncAt")
        .set(ServerValue.timestamp);

    FirebaseAnalytics.instance.logEvent(name: "sync_barcode_merged");
    return true;
  }

  Future<DateTime?> getLastSyncTime(String uid) async {
    final snapshot = await _db
        .child("users/$uid/barcode_backup/latest/lastSyncAt")
        .get();

    if (!snapshot.exists) return null;

    final timestamp = snapshot.value as int;

    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// `true` jika server punya data point coffee bulan ini (bukan kosong).
  Future<bool> syncPointCoffee(String uid) async {
    final monthKey = getCurrentMonthKey();

    final snapshot = await _db
        .child("users/$uid/point_coffee/$monthKey/data")
        .get();

    if (!snapshot.exists) {
      FirebaseAnalytics.instance.logEvent(
        name: "sync_point_coffee_skipped_no_server",
      );
      return false;
    }

    final data = snapshot.value as List?;

    if (data == null || data.isEmpty) {
      FirebaseAnalytics.instance.logEvent(
        name: "sync_point_coffee_skipped_empty_server",
      );
      return false;
    }

    final firebaseData = data
        .map((e) => PointCoffeeHistory.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final localData = await SharedPreferencesService().getPointCoffee();

    final merged = [...localData];

    for (final fb in firebaseData) {
      final exists = merged.any((e) => e.tgl == fb.tgl);

      if (!exists) {
        merged.add(fb);
      }
    }

    await SharedPreferencesService().clearPointCoffee();

    for (final item in merged) {
      await SharedPreferencesService().savePointCoffee(item);
    }

    FirebaseAnalytics.instance.logEvent(name: "sync_point_coffee_success");
    return true;
  }

  /// `true` jika server punya data say bread bulan ini (bukan kosong).
  Future<bool> syncSayBread(String uid) async {
    final monthKey = getCurrentMonthKey();

    final snapshot = await _db
        .child("users/$uid/say_bread/$monthKey/data")
        .get();

    if (!snapshot.exists) {
      FirebaseAnalytics.instance.logEvent(
        name: "sync_say_bread_skipped_no_server",
      );
      return false;
    }

    final data = snapshot.value as List?;

    if (data == null || data.isEmpty) {
      FirebaseAnalytics.instance.logEvent(
        name: "sync_say_bread_skipped_empty_server",
      );
      return false;
    }

    final firebaseData = data
        .map((e) => SayBreadHistory.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final localData = await SharedPreferencesService().getSayBread();

    final merged = [...localData];

    for (final fb in firebaseData) {
      final exists = merged.any((e) => e.tgl == fb.tgl);

      if (!exists) {
        merged.add(fb);
      }
    }

    await SharedPreferencesService().clearSayBread();

    for (final item in merged) {
      await SharedPreferencesService().saveSayBread(item);
    }

    FirebaseAnalytics.instance.logEvent(name: "sync_say_bread_success");
    return true;
  }

  /// Barcode + point coffee + say bread. Yang tidak ada di server **diskip**;
  /// yang ada tetap di-sync. Hanya error jika **ketiganya** kosong.
  Future<void> syncAll(String uid) async {
    final hasBarcode = await syncBarcodes(uid);
    final hasCoffee = await syncPointCoffee(uid);
    final hasBread = await syncSayBread(uid);

    if (!hasBarcode && !hasCoffee && !hasBread) {
      FirebaseAnalytics.instance.logEvent(name: "sync_all_no_server_data");
      throw const SyncNoServerDataException();
    }

    final now = DateTime.now();
    await SharedPreferencesService().saveLastSyncTime(now);

    FirebaseAnalytics.instance.logEvent(name: "sync_all_success");
  }
}
