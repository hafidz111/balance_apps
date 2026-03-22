import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../data/model/barcode_data.dart';
import '../data/model/point_coffe_history.dart';
import '../data/model/say_bread_history.dart';
import 'shared_preferences_service.dart';

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

  Future<void> syncBarcodes(String uid) async {
    final snapshot = await _db
        .child("users/$uid/barcode_backup/latest/barcodes")
        .get();

    if (!snapshot.exists) {
      throw Exception("Belum ada backup di server");
    }

    final data = snapshot.value as List?;

    if (data == null || data.isEmpty) {
      throw Exception("Data kosong di server");
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

    final now = DateTime.now();
    await SharedPreferencesService().saveLastSyncTime(now);

    FirebaseAnalytics.instance.logEvent(name: "sync_success");
  }

  Future<DateTime?> getLastSyncTime(String uid) async {
    final snapshot = await _db
        .child("users/$uid/barcode_backup/latest/lastSyncAt")
        .get();

    if (!snapshot.exists) return null;

    final timestamp = snapshot.value as int;

    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  Future<void> syncPointCoffee(String uid) async {
    final monthKey = getCurrentMonthKey();

    final snapshot = await _db
        .child("users/$uid/point_coffee/$monthKey/data")
        .get();

    if (!snapshot.exists) {
      throw Exception("Belum ada data Coffee di server");
    }

    final data = snapshot.value as List?;

    if (data == null || data.isEmpty) {
      throw Exception("Data Coffee kosong di server");
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
  }

  Future<void> syncSayBread(String uid) async {
    final monthKey = getCurrentMonthKey();

    final snapshot = await _db
        .child("users/$uid/say_bread/$monthKey/data")
        .get();

    if (!snapshot.exists) {
      throw Exception("Belum ada data Bread di server");
    }

    final data = snapshot.value as List?;

    if (data == null || data.isEmpty) {
      throw Exception("Data Bread kosong di server");
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
  }

  Future<void> syncAll(String uid) async {
    await syncBarcodes(uid);
    await syncPointCoffee(uid);
    await syncSayBread(uid);

    FirebaseAnalytics.instance.logEvent(name: "sync_all_success");
  }
}
