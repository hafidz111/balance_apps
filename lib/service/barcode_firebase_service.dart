import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../data/model/barcode_data.dart';
import '../data/model/bread_history.dart';
import '../data/model/coffee_history.dart';
import 'shared_preferences_service.dart';

class SyncNoServerDataException implements Exception {
  const SyncNoServerDataException();

  @override
  String toString() => 'Tidak ada data di server.';
}

class SyncResult {
  const SyncResult({
    required this.barcode,
    required this.coffee,
    required this.bread,
    this.coffeeAdded = 0,
    this.breadAdded = 0,
  });

  final bool barcode;
  final bool coffee;
  final bool bread;
  final int coffeeAdded;
  final int breadAdded;

  bool get any => barcode || coffee || bread;

  String get message {
    final parts = <String>[];
    if (barcode) parts.add('Barcode');
    if (coffee) parts.add('Coffee (+$coffeeAdded)');
    if (bread) parts.add('Bread (+$breadAdded)');
    if (parts.isEmpty) return 'Tidak ada data di server.';
    return 'Sinkron: ${parts.join(', ')}';
  }
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

  static String monthKeyFromTgl(int tgl) {
    final y = tgl ~/ 10000;
    final m = (tgl % 10000) ~/ 100;
    return "$y-${m.toString().padLeft(2, '0')}";
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

    final coffee = await SharedPreferencesService().getCoffee();
    final bread = await SharedPreferencesService().getBread();
    final barcodes = await SharedPreferencesService().getBarcodes();

    await _db.child("users/$uid/barcode_backup/latest").set({
      "barcodes": barcodes.map((e) => e.toJson()).toList(),
      "updatedAt": ServerValue.timestamp,
    });

    await _writeHistoryByMonth(uid, _coffeePath, coffee.map((e) => e.toJson()));
    await _writeHistoryByMonth(uid, _breadPath, bread.map((e) => e.toJson()));

    final now = DateTime.now();
    await SharedPreferencesService().saveLastBackupTime(now);

    FirebaseAnalytics.instance.logEvent(name: "backup_all_success");
  }

  Future<void> _writeHistoryByMonth(
    String uid,
    String path,
    Iterable<Map<String, dynamic>> rows,
  ) async {
    final byMonth = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final tgl = row['tgl'];
      if (tgl is! int) continue;
      byMonth.putIfAbsent(monthKeyFromTgl(tgl), () => []).add(row);
    }

    if (byMonth.isEmpty) return;

    final existing = await _db.child("users/$uid/$path").get();
    if (existing.exists && existing.value is Map) {
      final keys = Map<String, dynamic>.from(existing.value as Map).keys;
      for (final key in keys) {
        if (!byMonth.containsKey(key)) {
          await _db.child("users/$uid/$path/$key").remove();
        }
      }
    }

    for (final entry in byMonth.entries) {
      await _db.child("users/$uid/$path/${entry.key}").set({
        "data": entry.value,
        "updatedAt": ServerValue.timestamp,
      });
    }
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
    // Legacy saja dibersihkan ke bulan berjalan; path baru dikelola backupAll.
    for (final path in [_legacyCoffeePath, _legacyBreadPath]) {
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
        .map((e) => BarcodeData.fromJson(Map<String, dynamic>.from(e as Map)))
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

  Future<List<Map<String, dynamic>>> _fetchAllMonthRows(
    String uid,
    List<String> paths,
  ) async {
    final byTgl = <int, Map<String, dynamic>>{};

    for (final path in paths) {
      final root = await _db.child("users/$uid/$path").get();
      if (!root.exists || root.value is! Map) continue;

      final months = Map<String, dynamic>.from(root.value as Map);
      for (final monthVal in months.values) {
        if (monthVal is! Map) continue;
        final monthMap = Map<String, dynamic>.from(monthVal);
        final data = monthMap['data'];
        if (data is! List) continue;
        for (final raw in data) {
          if (raw is! Map) continue;
          final row = Map<String, dynamic>.from(raw);
          final tgl = row['tgl'];
          if (tgl is int) {
            // Path baru menang vs legacy jika tgl sama.
            byTgl.putIfAbsent(tgl, () => row);
          }
        }
      }
    }

    return byTgl.values.toList();
  }

  Future<int> syncCoffee(String uid) async {
    final serverRows = await _fetchAllMonthRows(uid, [
      _coffeePath,
      _legacyCoffeePath,
    ]);

    if (serverRows.isEmpty) {
      FirebaseAnalytics.instance.logEvent(
        name: "sync_coffee_skipped_no_server",
      );
      return -1;
    }

    final firebaseData =
        serverRows.map(CoffeeHistory.fromJson).toList();
    final localData = await SharedPreferencesService().getCoffee();
    final localTgl = localData.map((e) => e.tgl).toSet();

    final merged = [...localData];
    var added = 0;
    for (final fb in firebaseData) {
      if (localTgl.contains(fb.tgl)) continue;
      merged.add(fb);
      added++;
    }

    await SharedPreferencesService().replaceCoffeeAll(merged);

    FirebaseAnalytics.instance.logEvent(
      name: "sync_coffee_success",
      parameters: {"added": added, "server_rows": firebaseData.length},
    );
    return added;
  }

  Future<int> syncBread(String uid) async {
    final serverRows = await _fetchAllMonthRows(uid, [
      _breadPath,
      _legacyBreadPath,
    ]);

    if (serverRows.isEmpty) {
      FirebaseAnalytics.instance.logEvent(
        name: "sync_bread_skipped_no_server",
      );
      return -1;
    }

    final firebaseData = serverRows.map(BreadHistory.fromJson).toList();
    final localData = await SharedPreferencesService().getBread();
    final localTgl = localData.map((e) => e.tgl).toSet();

    final merged = [...localData];
    var added = 0;
    for (final fb in firebaseData) {
      if (localTgl.contains(fb.tgl)) continue;
      merged.add(fb);
      added++;
    }

    await SharedPreferencesService().replaceBreadAll(merged);

    FirebaseAnalytics.instance.logEvent(
      name: "sync_bread_success",
      parameters: {"added": added, "server_rows": firebaseData.length},
    );
    return added;
  }

  Future<SyncResult> syncAll(String uid) async {
    final hasBarcode = await syncBarcodes(uid);
    final coffeeAdded = await syncCoffee(uid);
    final breadAdded = await syncBread(uid);

    final result = SyncResult(
      barcode: hasBarcode,
      coffee: coffeeAdded >= 0,
      bread: breadAdded >= 0,
      coffeeAdded: coffeeAdded < 0 ? 0 : coffeeAdded,
      breadAdded: breadAdded < 0 ? 0 : breadAdded,
    );

    if (!result.any) {
      FirebaseAnalytics.instance.logEvent(name: "sync_all_no_server_data");
      throw const SyncNoServerDataException();
    }

    final now = DateTime.now();
    await SharedPreferencesService().saveLastSyncTime(now);

    FirebaseAnalytics.instance.logEvent(name: "sync_all_success");
    return result;
  }
}
