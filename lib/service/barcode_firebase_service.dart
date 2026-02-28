import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/model/barcode_data.dart';
import 'shared_preferences_service.dart';

class BarcodeFirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> backupBarcodes(String uid) async {
    final barcodes = await SharedPreferencesService().getBarcodes();

    await _firestore
        .collection("users")
        .doc(uid)
        .collection("barcode_backup")
        .doc("latest")
        .set({
          "barcodes": barcodes.map((e) => e.toJson()).toList(),
          "updatedAt": FieldValue.serverTimestamp(),
        });

    final now = DateTime.now();
    await SharedPreferencesService().saveLastBackupTime(now);
  }

  Future<DateTime?> getLastBackupTime(String uid) async {
    final doc = await _firestore
        .collection("users")
        .doc(uid)
        .collection("barcode_backup")
        .doc("latest")
        .get();

    if (!doc.exists) return null;

    final timestamp = doc.data()?["updatedAt"];

    if (timestamp == null) return null;

    return (timestamp as Timestamp).toDate();
  }

  Future<void> syncBarcodes(String uid) async {
    final doc = await _firestore
        .collection("users")
        .doc(uid)
        .collection("barcode_backup")
        .doc("latest")
        .get();

    if (!doc.exists) {
      throw Exception("Belum ada backup di server");
    }

    final data = doc.data()?["barcodes"] as List?;

    if (data == null || data.isEmpty) {
      throw Exception("Data kosong di server");
    }

    final firebaseBarcodes = data.map((e) => BarcodeData.fromJson(e)).toList();

    final localBarcodes = await SharedPreferencesService().getBarcodes();

    final merged = [...localBarcodes];

    for (final fb in firebaseBarcodes) {
      final exists = merged.any((e) => e.code == fb.code && e.type == fb.type);

      if (!exists) {
        merged.add(fb);
      }
    }

    await SharedPreferencesService().saveBarcodes(merged);

    await _firestore
        .collection("users")
        .doc(uid)
        .collection("barcode_backup")
        .doc("latest")
        .update({"lastSyncAt": FieldValue.serverTimestamp()});

    final now = DateTime.now();
    await SharedPreferencesService().saveLastSyncTime(now);
  }

  Future<DateTime?> getLastSyncTime(String uid) async {
    final doc = await _firestore
        .collection("users")
        .doc(uid)
        .collection("barcode_backup")
        .doc("latest")
        .get();

    if (!doc.exists) return null;

    final timestamp = doc.data()?["lastSyncAt"];

    if (timestamp == null) return null;

    return (timestamp as Timestamp).toDate();
  }
}
