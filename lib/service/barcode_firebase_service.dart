import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../data/model/barcode_data.dart';
import 'shared_preferences_service.dart';

class BarcodeFirebaseService {
  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        "https://balance-apps-991c6-default-rtdb.asia-southeast1.firebasedatabase.app",
  );

  late final DatabaseReference _db = _database.ref();

  Future<void> backupBarcodes(String uid) async {
    final barcodes = await SharedPreferencesService().getBarcodes();

    await _db.child("users/$uid/barcode_backup/latest").set({
      "barcodes": barcodes.map((e) => e.toJson()).toList(),
      "updatedAt": ServerValue.timestamp,
    });

    final now = DateTime.now();
    await SharedPreferencesService().saveLastBackupTime(now);

    FirebaseAnalytics.instance.logEvent(name: "backup_success");
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
}
