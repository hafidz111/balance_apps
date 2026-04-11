import 'dart:convert';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/model/barcode_data.dart';
import '../data/model/point_coffe_history.dart';
import '../data/model/say_bread_history.dart';
import '../data/model/store_data.dart';
import '../data/model/warehouse_transaction.dart';
import '../data/shift_time_phase.dart';

class SharedPreferencesService {
  static SharedPreferences? _prefs;

  static Future init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs => _prefs!;
  static const pcKey = 'point_coffee_history';
  static const pcDraftKey = "pc_draft";
  static const sbKey = 'say_bread_history';
  static const sbDraftKey = "sb_draft";
  static const pcStoreKey = 'pc_store_data';
  static const sbStoreKey = 'sb_store_data';
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
  static const pcCpdManualKey = "pc_cpd_manual";
  static const pcCpdMonthKey = "pc_cpd_month";
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
  static const currentDbVersion = 2;

  Future<void> initDb() async {
    final prefs = await SharedPreferences.getInstance();

    final version = prefs.getInt(dbVersionKey) ?? 1;

    if (version < currentDbVersion) {
      await _migrate(prefs, version);
      await prefs.setInt(dbVersionKey, currentDbVersion);
    }
  }

  Future<void> _migrate(SharedPreferences prefs, int oldVersion) async {
    if (oldVersion == 1) {
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
  }

  Future<void> savePointCoffeeStore(StoreData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pcStoreKey, jsonEncode(data.toJson()));
  }

  Future<StoreData?> getPointCoffeeStore() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(pcStoreKey);
    if (jsonString == null) return null;
    return StoreData.fromJson(jsonDecode(jsonString));
  }

  Future<void> saveSayBreadStore(StoreData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(sbStoreKey, jsonEncode(data.toJson()));
  }

  Future<StoreData?> getSayBreadStore() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(sbStoreKey);
    if (jsonString == null) return null;
    return StoreData.fromJson(jsonDecode(jsonString));
  }

  Future<void> savePointCoffee(PointCoffeeHistory data) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(pcKey) ?? [];

    final histories = list
        .map((e) => PointCoffeeHistory.fromJson(jsonDecode(e)))
        .toList();

    histories.removeWhere((e) => e.tgl == data.tgl);
    histories.add(data);

    histories.sort((a, b) => a.tgl.compareTo(b.tgl));

    int runningAkm = 0;
    final fixed = <PointCoffeeHistory>[];

    for (final item in histories) {
      runningAkm += item.cup;
      final day = item.tgl % 100;

      fixed.add(
        PointCoffeeHistory(
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
      pcKey,
      fixed.map((e) => jsonEncode(e.toJson())).toList(),
    );

    FirebaseAnalytics.instance.logEvent(name: "point_coffee_entry_added");
  }

  Future<List<PointCoffeeHistory>> getPointCoffee() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(pcKey) ?? [];

    final histories = list
        .map((e) => PointCoffeeHistory.fromJson(jsonDecode(e)))
        .toList();

    histories.sort((a, b) => a.tgl.compareTo(b.tgl));

    return histories;
  }

  Future<List<PointCoffeeHistory>> getPointCoffeeByMonth(
    int year,
    int month,
  ) async {
    final all = await getPointCoffee();

    return all.where((e) {
      final y = e.tgl ~/ 10000;
      final m = (e.tgl % 10000) ~/ 100;
      return y == year && m == month;
    }).toList();
  }

  Future<void> deletePointCoffee(int tgl) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(pcKey) ?? [];

    final histories =
        list
            .map((e) => PointCoffeeHistory.fromJson(jsonDecode(e)))
            .where((e) => e.tgl != tgl)
            .toList()
          ..sort((a, b) => a.tgl.compareTo(b.tgl));

    int runningAkm = 0;
    final fixed = <PointCoffeeHistory>[];

    for (final item in histories) {
      runningAkm += item.cup;
      final day = item.tgl % 100;

      fixed.add(
        PointCoffeeHistory(
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
      pcKey,
      fixed.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> savePointCoffeeDraft(int tgl, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("$pcDraftKey$tgl", jsonEncode(data));
  }

  Future<Map<String, dynamic>?> getPointCoffeeDraft(int tgl) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString("$pcDraftKey$tgl");
    if (jsonString == null) return null;
    return jsonDecode(jsonString);
  }

  Future<void> clearPointCoffeeDraft(int tgl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("$pcDraftKey$tgl");
  }

  Future<void> clearPointCoffee() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pcKey);
  }

  Future<void> saveSayBread(SayBreadHistory data) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(sbKey) ?? [];

    final histories = list
        .map((e) => SayBreadHistory.fromJson(jsonDecode(e)))
        .toList();

    histories.removeWhere((e) => e.tgl == data.tgl);
    histories.add(data);

    histories.sort((a, b) => a.tgl.compareTo(b.tgl));

    int runningQty = 0;
    int runningSales = 0;
    final fixed = <SayBreadHistory>[];

    for (final item in histories) {
      runningQty += item.qty;
      runningSales += item.sales;
      final day = item.tgl % 100;

      fixed.add(
        SayBreadHistory(
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
      sbKey,
      fixed.map((e) => jsonEncode(e.toJson())).toList(),
    );

    FirebaseAnalytics.instance.logEvent(name: "say_bread_entry_added");
  }

  Future<void> deleteSayBread(int tgl) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(sbKey) ?? [];

    final histories =
        list
            .map((e) => SayBreadHistory.fromJson(jsonDecode(e)))
            .where((e) => e.tgl != tgl)
            .toList()
          ..sort((a, b) => a.tgl.compareTo(b.tgl));

    int runningQty = 0;
    int runningSales = 0;
    final fixed = <SayBreadHistory>[];

    for (final item in histories) {
      runningQty += item.qty;
      runningSales += item.sales;
      final day = item.tgl % 100;

      fixed.add(
        SayBreadHistory(
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
      sbKey,
      fixed.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<List<SayBreadHistory>> getSayBread() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(sbKey) ?? [];

    final histories = list
        .map((e) => SayBreadHistory.fromJson(jsonDecode(e)))
        .toList();

    histories.sort((a, b) => a.tgl.compareTo(b.tgl));

    return histories;
  }

  Future<List<SayBreadHistory>> getSayBreadByMonth(int year, int month) async {
    final all = await getSayBread();

    return all.where((e) {
      final y = e.tgl ~/ 10000;
      final m = (e.tgl % 10000) ~/ 100;
      return y == year && m == month;
    }).toList();
  }

  Future<void> saveSayBreadDraft(int tgl, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("$sbDraftKey$tgl", jsonEncode(data));
  }

  Future<Map<String, dynamic>?> getSayBreadDraft(int tgl) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString("$sbDraftKey$tgl");
    if (jsonString == null) return null;
    return jsonDecode(jsonString);
  }

  Future<void> clearSayBreadDraft(int tgl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("$sbDraftKey$tgl");
  }

  Future<void> clearSayBread() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(sbKey);
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

  Future<void> savePointCoffeeCpdManual(String cpd) async {
    final now = DateTime.now();
    final monthKey = "${now.year}-${now.month}";

    await prefs.setString(pcCpdManualKey, cpd);
    await prefs.setString(pcCpdMonthKey, monthKey);

    FirebaseAnalytics.instance.logEvent(name: "point_coffee_cpd_manual_saved");
  }

  Future<String?> getPointCoffeeCpdManual() async {
    final now = DateTime.now();
    final currentMonthKey = "${now.year}-${now.month}";

    final savedMonth = prefs.getString(pcCpdMonthKey);
    final savedCpd = prefs.getString(pcCpdManualKey);

    if (savedMonth == null || savedCpd == null) {
      return null;
    }

    if (savedMonth != currentMonthKey) {
      await clearPointCoffeeCpdManual();
      return null;
    }

    return savedCpd;
  }

  Future<void> clearPointCoffeeCpdManual() async {
    await prefs.remove(pcCpdManualKey);
    await prefs.remove(pcCpdMonthKey);
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
