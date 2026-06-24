import 'dart:convert';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/model/barcode_data.dart';
import '../data/model/coffee_history.dart';
import '../data/model/bread_history.dart';
import '../data/model/store_data.dart';
import '../data/model/warehouse_transaction.dart';
import '../data/shift_time_phase.dart';

class SharedPreferencesService {
  static SharedPreferences? _prefs;

  static Future init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs => _prefs!;
  static const coffeeKey = 'coffee_history';
  static const coffeeDraftKey = 'coffee_draft';
  static const breadKey = 'bread_history';
  static const breadDraftKey = 'bread_draft';
  static const coffeeStoreKey = 'coffee_store_data';
  static const breadStoreKey = 'bread_store_data';
  static const barcodeKey = 'barcode_list';
  static const keyLogin = "login";
  static const phoneKey = "phone_number";
  static const shiftKey = "shift_count";
  static const shiftTimeLabelsKey = 'shift_time_labels';
  static const warehouseKey = 'warehouse_transactions';

  static const List<String> defaultShiftTimeLabels = [
    '07:30 – 14:30',
    '14:30 – 22:30',
    '22:30 – 00:00',
    '00:00 – 07:30',
  ];

  static String jamKerjaSubtitle(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final t = raw.trim();
    final i = t.indexOf('•');
    if (i != -1 && i + 1 < t.length) {
      return t.substring(i + 1).trim();
    }
    return t;
  }

  static ShiftTimePhase shiftTimePhaseAt(String? raw, [DateTime? now]) {
    final t = jamKerjaSubtitle(raw);
    if (t.isEmpty) return ShiftTimePhase.belumAktif;

    final re = RegExp(
      r'(\d{1,2})\s*:\s*(\d{2})\s*[–-]\s*(\d{1,2})\s*:\s*(\d{2})',
    );
    final m = re.firstMatch(t);
    if (m == null) return ShiftTimePhase.belumAktif;

    final current = now ?? DateTime.now();
    final minutes = current.hour * 60 + current.minute;

    final start = int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
    final end = int.parse(m.group(3)!) * 60 + int.parse(m.group(4)!);

    if (start == end) return ShiftTimePhase.belumAktif;

    if (start < end) {
      if (minutes < start) return ShiftTimePhase.belumAktif;
      if (minutes >= end) return ShiftTimePhase.selesai;
      return ShiftTimePhase.aktif;
    }

    if (minutes >= start || minutes < end) return ShiftTimePhase.aktif;
    final mid = (end + start) ~/ 2;
    if (minutes < mid) return ShiftTimePhase.selesai;
    return ShiftTimePhase.belumAktif;
  }

  static bool isShiftActiveAt(String? raw, [DateTime? now]) {
    return shiftTimePhaseAt(raw, now) == ShiftTimePhase.aktif;
  }

  static const scheduleKey = "schedule_data";
  static const coffeeCpdManualKey = 'coffee_cpd_manual';
  static const coffeeCpdMonthKey = 'coffee_cpd_month';
  static const customBackgroundKey = "custom_background";

  bool get isLogin => prefs.getBool(keyLogin) ?? false;

  Future<void> login() async {
    try {
      await _prefs?.setBool(keyLogin, true);
    } catch (e) {
      throw Exception("Shared preferences cannot save the value.");
    }
  }

  Future<void> logout() async {
    try {
      await _prefs?.setBool(keyLogin, false);
    } catch (e) {
      throw Exception("Shared preferences cannot save the value.");
    }
  }

  static const dbVersionKey = 'db_version';
  static const currentDbVersion = 3;

  Future<void> initDb() async {
    final prefs = await SharedPreferences.getInstance();

    final version = prefs.getInt(dbVersionKey) ?? 1;

    if (version < currentDbVersion) {
      await _migrate(prefs, version);
      await prefs.setInt(dbVersionKey, currentDbVersion);
    }
  }

  Future<void> _migrate(SharedPreferences prefs, int oldVersion) async {
    if (oldVersion < 2) {
      final list = await getBarcodes();

      final fixed = list.map((e) {
        return BarcodeData(
          id: UniqueKey().toString(),
          type: e.type,
          code: e.code,
          description: e.description,
        );
      }).toList();

      await saveBarcodes(fixed);
    }

    if (oldVersion < 3) {
      await _migratePrefsKey(prefs, 'point_coffee_history', coffeeKey);
      await _migratePrefsKey(prefs, 'say_bread_history', breadKey);
      await _migratePrefsKey(prefs, 'pc_store_data', coffeeStoreKey);
      await _migratePrefsKey(prefs, 'sb_store_data', breadStoreKey);
      await _migratePrefsKey(prefs, 'pc_cpd_manual', coffeeCpdManualKey);
      await _migratePrefsKey(prefs, 'pc_cpd_month', coffeeCpdMonthKey);

      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith('pc_draft')) {
          final value = prefs.getString(key);
          if (value != null) {
            await prefs.setString(
              key.replaceFirst('pc_draft', coffeeDraftKey),
              value,
            );
          }
          await prefs.remove(key);
        } else if (key.startsWith('sb_draft')) {
          final value = prefs.getString(key);
          if (value != null) {
            await prefs.setString(
              key.replaceFirst('sb_draft', breadDraftKey),
              value,
            );
          }
          await prefs.remove(key);
        }
      }
    }
  }

  Future<void> _migratePrefsKey(
    SharedPreferences prefs,
    String oldKey,
    String newKey,
  ) async {
    if (prefs.containsKey(newKey)) return;

    if (prefs.containsKey(oldKey)) {
      final value = prefs.get(oldKey);
      if (value is String) {
        await prefs.setString(newKey, value);
      } else if (value is List<String>) {
        await prefs.setStringList(newKey, value);
      }
      await prefs.remove(oldKey);
    }
  }

  Future<void> saveCoffeeStore(StoreData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(coffeeStoreKey, jsonEncode(data.toJson()));
  }

  Future<StoreData?> getCoffeeStore() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(coffeeStoreKey);
    if (jsonString == null) return null;
    return StoreData.fromJson(jsonDecode(jsonString));
  }

  Future<void> saveBreadStore(StoreData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(breadStoreKey, jsonEncode(data.toJson()));
  }

  Future<StoreData?> getBreadStore() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(breadStoreKey);
    if (jsonString == null) return null;
    return StoreData.fromJson(jsonDecode(jsonString));
  }

  Future<void> saveCoffee(CoffeeHistory data) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(coffeeKey) ?? [];

    final histories = list
        .map((e) => CoffeeHistory.fromJson(jsonDecode(e)))
        .toList();

    histories.removeWhere((e) => e.tgl == data.tgl);
    histories.add(data);

    histories.sort((a, b) => a.tgl.compareTo(b.tgl));

    int runningAkm = 0;
    final fixed = <CoffeeHistory>[];

    for (final item in histories) {
      runningAkm += item.cup;
      final day = item.tgl % 100;

      fixed.add(
        CoffeeHistory(
          tgl: item.tgl,
          spd: item.spd,
          cup: item.cup,
          akmCup: runningAkm,
          cpd: runningAkm / day,
          apc: item.apc,
        ),
      );
    }

    await prefs.setStringList(
      coffeeKey,
      fixed.map((e) => jsonEncode(e.toJson())).toList(),
    );

    FirebaseAnalytics.instance.logEvent(name: "coffee_entry_added");
  }

  Future<List<CoffeeHistory>> getCoffee() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(coffeeKey) ?? [];

    final histories = list
        .map((e) => CoffeeHistory.fromJson(jsonDecode(e)))
        .toList();

    histories.sort((a, b) => a.tgl.compareTo(b.tgl));

    return histories;
  }

  Future<List<CoffeeHistory>> getCoffeeByMonth(
    int year,
    int month,
  ) async {
    final all = await getCoffee();

    return all.where((e) {
      final y = e.tgl ~/ 10000;
      final m = (e.tgl % 10000) ~/ 100;
      return y == year && m == month;
    }).toList();
  }

  Future<void> deleteCoffee(int tgl) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(coffeeKey) ?? [];

    final histories =
        list
            .map((e) => CoffeeHistory.fromJson(jsonDecode(e)))
            .where((e) => e.tgl != tgl)
            .toList()
          ..sort((a, b) => a.tgl.compareTo(b.tgl));

    int runningAkm = 0;
    final fixed = <CoffeeHistory>[];

    for (final item in histories) {
      runningAkm += item.cup;
      final day = item.tgl % 100;

      fixed.add(
        CoffeeHistory(
          tgl: item.tgl,
          spd: item.spd,
          cup: item.cup,
          akmCup: runningAkm,
          cpd: runningAkm / day,
          apc: item.apc,
        ),
      );
    }

    await prefs.setStringList(
      coffeeKey,
      fixed.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> saveCoffeeDraft(int tgl, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("$coffeeDraftKey$tgl", jsonEncode(data));
  }

  Future<Map<String, dynamic>?> getCoffeeDraft(int tgl) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString("$coffeeDraftKey$tgl");
    if (jsonString == null) return null;
    return jsonDecode(jsonString);
  }

  Future<void> clearCoffeeDraft(int tgl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("$coffeeDraftKey$tgl");
  }

  Future<void> clearCoffee() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(coffeeKey);
  }

  Future<void> saveBread(BreadHistory data) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(breadKey) ?? [];

    final histories = list
        .map((e) => BreadHistory.fromJson(jsonDecode(e)))
        .toList();

    histories.removeWhere((e) => e.tgl == data.tgl);
    histories.add(data);

    histories.sort((a, b) => a.tgl.compareTo(b.tgl));

    int runningQty = 0;
    int runningSales = 0;
    final fixed = <BreadHistory>[];

    for (final item in histories) {
      runningQty += item.qty;
      runningSales += item.sales;
      final day = item.tgl % 100;

      fixed.add(
        BreadHistory(
          tgl: item.tgl,
          sales: item.sales,
          qty: item.qty,
          akmQty: runningQty,
          akmSales: runningSales,
          average: runningQty / day,
        ),
      );
    }

    await prefs.setStringList(
      breadKey,
      fixed.map((e) => jsonEncode(e.toJson())).toList(),
    );

    FirebaseAnalytics.instance.logEvent(name: "bread_entry_added");
  }

  Future<void> deleteBread(int tgl) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(breadKey) ?? [];

    final histories =
        list
            .map((e) => BreadHistory.fromJson(jsonDecode(e)))
            .where((e) => e.tgl != tgl)
            .toList()
          ..sort((a, b) => a.tgl.compareTo(b.tgl));

    int runningQty = 0;
    int runningSales = 0;
    final fixed = <BreadHistory>[];

    for (final item in histories) {
      runningQty += item.qty;
      runningSales += item.sales;
      final day = item.tgl % 100;

      fixed.add(
        BreadHistory(
          tgl: item.tgl,
          sales: item.sales,
          qty: item.qty,
          akmQty: runningQty,
          akmSales: runningSales,
          average: runningQty / day,
        ),
      );
    }

    await prefs.setStringList(
      breadKey,
      fixed.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<List<BreadHistory>> getBread() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(breadKey) ?? [];

    final histories = list
        .map((e) => BreadHistory.fromJson(jsonDecode(e)))
        .toList();

    histories.sort((a, b) => a.tgl.compareTo(b.tgl));

    return histories;
  }

  Future<List<BreadHistory>> getBreadByMonth(int year, int month) async {
    final all = await getBread();

    return all.where((e) {
      final y = e.tgl ~/ 10000;
      final m = (e.tgl % 10000) ~/ 100;
      return y == year && m == month;
    }).toList();
  }

  Future<void> saveBreadDraft(int tgl, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("$breadDraftKey$tgl", jsonEncode(data));
  }

  Future<Map<String, dynamic>?> getBreadDraft(int tgl) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString("$breadDraftKey$tgl");
    if (jsonString == null) return null;
    return jsonDecode(jsonString);
  }

  Future<void> clearBreadDraft(int tgl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("$breadDraftKey$tgl");
  }

  Future<void> clearBread() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(breadKey);
  }

  Future<void> saveBarcode(BarcodeData data) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(barcodeKey) ?? [];

    final barcodes = list
        .map((e) => BarcodeData.fromJson(jsonDecode(e)))
        .toList();

    barcodes.removeWhere((e) => e.id == data.id);

    barcodes.add(data);

    await prefs.setStringList(
      barcodeKey,
      barcodes.map((e) => jsonEncode(e.toJson())).toList(),
    );

    FirebaseAnalytics.instance.logEvent(name: "barcode_created");
  }

  Future<List<BarcodeData>> getBarcodes() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(barcodeKey) ?? [];

    return list.map((e) => BarcodeData.fromJson(jsonDecode(e))).toList();
  }

  Future<void> saveBarcodes(List<BarcodeData> list) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      barcodeKey,
      list.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> updateBarcode(BarcodeData oldData, BarcodeData newData) async {
    final list = await getBarcodes();

    final index = list.indexWhere((e) => e.id == oldData.id);

    if (index != -1) {
      list[index] = newData;
      await saveBarcodes(list);
    }
  }

  Future<void> deleteBarcode(BarcodeData data) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(barcodeKey) ?? [];

    final barcodes = list
        .map((e) => BarcodeData.fromJson(jsonDecode(e)))
        .toList();

    barcodes.removeWhere((e) => e.id == data.id);

    await prefs.setStringList(
      barcodeKey,
      barcodes.map((e) => jsonEncode(e.toJson())).toList(),
    );

    FirebaseAnalytics.instance.logEvent(name: "barcode_deleted");
  }

  Future<String> exportBarcodesToJson() async {
    final list = await getBarcodes();
    final jsonList = list.map((e) => e.toJson()).toList();
    FirebaseAnalytics.instance.logEvent(name: "barcode_exported");
    return jsonEncode(jsonList);
  }

  Future<void> importBarcodesFromJson(String jsonString) async {
    final decoded = jsonDecode(jsonString) as List;
    final imported = decoded.map((e) => BarcodeData.fromJson(e)).toList();

    await saveBarcodes(imported);

    FirebaseAnalytics.instance.logEvent(name: "barcode_imported");
  }

  Future<void> savePhoneNumber(String phone) async {
    await prefs.setString(phoneKey, phone);
  }

  String? getPhoneNumber() {
    return prefs.getString(phoneKey);
  }

  Future<void> saveShiftCount(int shift) async {
    await prefs.setInt(shiftKey, shift);
  }

  int? getShiftCount() {
    return prefs.getInt(shiftKey);
  }

  Future<void> saveShiftTimeLabels(List<String> labels) async {
    final padded = List<String>.from(labels);
    while (padded.length < 4) {
      padded.add('');
    }
    await prefs.setString(
      shiftTimeLabelsKey,
      jsonEncode(padded.take(4).toList()),
    );
  }

  List<String> getShiftTimeLabels() {
    final raw = prefs.getString(shiftTimeLabelsKey);
    if (raw == null) {
      return List<String>.from(defaultShiftTimeLabels);
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final out = list.map((e) => e.toString()).toList();
      while (out.length < 4) {
        out.add('');
      }
      return out.take(4).toList();
    } catch (_) {
      return List<String>.from(defaultShiftTimeLabels);
    }
  }

  Future<void> saveLastBackupTime(DateTime date) async {
    await prefs.setString("last_backup_time", date.toIso8601String());
  }

  Future<DateTime?> getLastBackupTimeCache() async {
    final value = prefs.getString("last_backup_time");
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  Future<void> saveLastSyncTime(DateTime date) async {
    await prefs.setString("last_sync_time", date.toIso8601String());
  }

  Future<DateTime?> getLastSyncTimeCache() async {
    final value = prefs.getString("last_sync_time");
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  Future<void> saveSchedules(Map<String, String> data) async {
    await prefs.setString(scheduleKey, jsonEncode(data));
  }

  Future<Map<String, String>> getSchedules() async {
    final jsonString = prefs.getString(scheduleKey);
    if (jsonString == null) return {};
    return Map<String, String>.from(jsonDecode(jsonString));
  }

  Future<void> setSchedule(String name, String date, String shift) async {
    final schedules = await getSchedules();
    schedules["${name}_$date"] = shift;
    await saveSchedules(schedules);
  }

  Future<void> deleteSchedule(String name, String date) async {
    final schedules = await getSchedules();
    schedules.remove("${name}_$date");
    await saveSchedules(schedules);
  }

  Future<void> clearSchedulesByMonth(int year, int month) async {
    final schedules = await getSchedules();

    final monthPrefix = "$year-${month.toString().padLeft(2, '0')}";

    schedules.removeWhere((key, value) {
      return key.contains(monthPrefix);
    });

    await saveSchedules(schedules);
  }

  Future<void> saveCoffeeCpdManual(String cpd) async {
    final now = DateTime.now();
    final monthKey = "${now.year}-${now.month}";

    await prefs.setString(coffeeCpdManualKey, cpd);
    await prefs.setString(coffeeCpdMonthKey, monthKey);

    FirebaseAnalytics.instance.logEvent(name: "coffee_cpd_manual_saved");
  }

  Future<String?> getCoffeeCpdManual() async {
    final now = DateTime.now();
    final currentMonthKey = "${now.year}-${now.month}";

    final savedMonth = prefs.getString(coffeeCpdMonthKey);
    final savedCpd = prefs.getString(coffeeCpdManualKey);

    if (savedMonth == null || savedCpd == null) {
      return null;
    }

    if (savedMonth != currentMonthKey) {
      await clearCoffeeCpdManual();
      return null;
    }

    return savedCpd;
  }

  Future<void> clearCoffeeCpdManual() async {
    await prefs.remove(coffeeCpdManualKey);
    await prefs.remove(coffeeCpdMonthKey);
  }

  Future<void> saveCustomBackground(String path) async {
    await prefs.setString(customBackgroundKey, path);
  }

  String? getCustomBackground() {
    return prefs.getString(customBackgroundKey);
  }

  Future<void> clearCustomBackground() async {
    await prefs.remove(customBackgroundKey);
  }

  Future<bool> isNewMonth() async {
    final now = DateTime.now();
    final currentMonthKey = "${now.year}-${now.month}";

    final savedMonth = prefs.getString("last_saved_month");

    if (savedMonth == null) {
      await prefs.setString("last_saved_month", currentMonthKey);
      return false;
    }

    return savedMonth != currentMonthKey;
  }

  Future<void> updateCurrentMonth() async {
    final now = DateTime.now();
    final currentMonthKey = "${now.year}-${now.month}";
    await prefs.setString("last_saved_month", currentMonthKey);
  }

  Future<List<WarehouseTransaction>> getWarehouseTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(warehouseKey) ?? [];
    return list
        .map((e) => WarehouseTransaction.fromJson(jsonDecode(e)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> saveWarehouseTransaction(WarehouseTransaction t) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(warehouseKey) ?? [];
    list.add(jsonEncode(t.toJson()));
    await prefs.setStringList(warehouseKey, list);
    FirebaseAnalytics.instance.logEvent(
      name: 'warehouse_transaction',
      parameters: {'type': t.type},
    );
  }

  Future<void> deleteWarehouseTransaction(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(warehouseKey) ?? [];
    final updated = list.where((e) => jsonDecode(e)['id'] != id).toList();
    await prefs.setStringList(warehouseKey, updated);
  }

  Future<void> clearWarehouseTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(warehouseKey);
  }
}
