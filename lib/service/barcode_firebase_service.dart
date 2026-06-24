import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../data/model/barcode_data.dart';
import '../data/model/bread_history.dart';
import '../data/model/coffee_history.dart';
import 'shared_preferences_service.dart';

/// Dilempar dari [BarcodeFirebaseService.syncAll] bila barcode, coffee,
/// dan bread **semuanya** tidak punya data di server.
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

  static const _legacyCoffeePath = 'point_coffee';
  static const _legacyBreadPath = 'say_bread';
  static const _coffeePath = 'coffee';
  static const _breadPath = 'bread';

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

    final coffee = await SharedPreferencesService().getCoffee();
    final bread = await SharedPreferencesService().getBread();
    final barcodes = await SharedPreferencesService().getBarcodes();

    await _db.child("users/$uid/barcode_backup/latest").set({
      "barcodes": barcodes.map((e) => e.toJson()).toList(),
      "updatedAt": ServerValue.timestamp,
    });

    await _db.child("users/$uid/$_coffeePath/$monthKey").set({
      "data": coffee.map((e) => e.toJson()).toList(),
      "updatedAt": ServerValue.timestamp,
    });

    await _db.child("users/$uid/$_breadPath/$monthKey").set({
      "data": bread.map((e) => e.toJson()).toList(),
      "updatedAt": ServerValue.timestamp,
    });

    final now = DateTime.now();
    await SharedPreferencesService().saveLastBackupTime(now);

    FirebaseAnalytics.instance.logEvent(name: "backup_all_success");
  }

  Future<void> _deleteOldMonthsForPath(String uid, String path) async {
    final snapshot = await _db.child("users/$uid/$path").get();
    if (!snapshot.exists) return;

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final currentMonth = getCurrentMonthKey();

    for (final key in data.keys) {
      if (key != currentMonth) {
        await _db.child("users/$uid/$path/$key").remove();
      }
    }
  }

  Future<void> deleteOldMonths(String uid) async {
    for (final path in [_coffeePath, _legacyCoffeePath, _breadPath, _legacyBreadPath]) {
      await _deleteOldMonthsForPath(uid, path);
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

  Future<DataSnapshot?> _readMonthData(
    String uid,
    String monthKey,
    String path,
  ) async {
    final snapshot = await _db.child("users/$uid/$path/$monthKey/data").get();
    return snapshot.exists ? snapshot : null;
  }

  Future<List<Map<String, dynamic>>?> _fetchCoffeeServerData(
    String uid,
    String monthKey,
  ) async {
    final current = await _readMonthData(uid, monthKey, _coffeePath);
    final legacy = await _readMonthData(uid, monthKey, _legacyCoffeePath);
    final snapshot = current ?? legacy;
    if (snapshot == null) return null;

    final data = snapshot.value as List?;
    if (data == null || data.isEmpty) return null;

    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>?> _fetchBreadServerData(
    String uid,
    String monthKey,
  ) async {
    final current = await _readMonthData(uid, monthKey, _breadPath);
    final legacy = await _readMonthData(uid, monthKey, _legacyBreadPath);
    final snapshot = current ?? legacy;
    if (snapshot == null) return null;

    final data = snapshot.value as List?;
    if (data == null || data.isEmpty) return null;

    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// `true` jika server punya data coffee bulan ini (bukan kosong).
  Future<bool> syncCoffee(String uid) async {
    final monthKey = getCurrentMonthKey();
    final serverRows = await _fetchCoffeeServerData(uid, monthKey);

    if (serverRows == null) {
      FirebaseAnalytics.instance.logEvent(
        name: "sync_coffee_skipped_no_server",
      );
      return false;
    }

    final firebaseData = serverRows
        .map((e) => CoffeeHistory.fromJson(e))
        .toList();

    final localData = await SharedPreferencesService().getCoffee();

    final merged = [...localData];

    for (final fb in firebaseData) {
      final exists = merged.any((e) => e.tgl == fb.tgl);

      if (!exists) {
        merged.add(fb);
      }
    }

    await SharedPreferencesService().clearCoffee();

    for (final item in merged) {
      await SharedPreferencesService().saveCoffee(item);
    }

    FirebaseAnalytics.instance.logEvent(name: "sync_coffee_success");
    return true;
  }

  /// `true` jika server punya data bread bulan ini (bukan kosong).
  Future<bool> syncBread(String uid) async {
    final monthKey = getCurrentMonthKey();
    final serverRows = await _fetchBreadServerData(uid, monthKey);

    if (serverRows == null) {
      FirebaseAnalytics.instance.logEvent(
        name: "sync_bread_skipped_no_server",
      );
      return false;
    }

    final firebaseData = serverRows
        .map((e) => BreadHistory.fromJson(e))
        .toList();

    final localData = await SharedPreferencesService().getBread();

    final merged = [...localData];

    for (final fb in firebaseData) {
      final exists = merged.any((e) => e.tgl == fb.tgl);

      if (!exists) {
        merged.add(fb);
      }
    }

    await SharedPreferencesService().clearBread();

    for (final item in merged) {
      await SharedPreferencesService().saveBread(item);
    }

    FirebaseAnalytics.instance.logEvent(name: "sync_bread_success");
    return true;
  }

  /// Barcode + coffee + bread. Yang tidak ada di server **diskip**;
  /// yang ada tetap di-sync. Hanya error jika **ketiganya** kosong.
  Future<void> syncAll(String uid) async {
    final hasBarcode = await syncBarcodes(uid);
    final hasCoffee = await syncCoffee(uid);
    final hasBread = await syncBread(uid);

    if (!hasBarcode && !hasCoffee && !hasBread) {
      FirebaseAnalytics.instance.logEvent(name: "sync_all_no_server_data");
      throw const SyncNoServerDataException();
    }

    final now = DateTime.now();
    await SharedPreferencesService().saveLastSyncTime(now);

    FirebaseAnalytics.instance.logEvent(name: "sync_all_success");
  }
}
