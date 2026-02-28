import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/model/barcode_data.dart';
import '../data/model/point_coffe_history.dart';
import '../data/model/say_bread_history.dart';
import '../data/model/store_data.dart';

class SharedPreferencesService {
  static SharedPreferences? _prefs;

  static Future init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs => _prefs!;
  static const pcKey = 'point_coffee_history';
  static const sbKey = 'say_bread_history';
  static const pcStoreKey = 'pc_store_data';
  static const sbStoreKey = 'sb_store_data';
  static const barcodeKey = 'barcode_list';
  static const keyLogin = "login";
  static const phoneKey = "phone_number";
  static const shiftKey = "shift_count";

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
  static const currentDbVersion = 1;

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
          type: e.type,
          code: e.code,
          description: e.description,
        );
      }).toList();

      await saveBarcodes(fixed);
    }
  }

  Future<Map<String, dynamic>> getAllLocalData() async {
    final barcodes = await getBarcodes();
    final pointCoffee = await getPointCoffee();
    final sayBread = await getSayBread();
    final pcStore = await getPointCoffeeStore();
    final sbStore = await getSayBreadStore();

    return {
      "barcodes": barcodes.map((e) => e.toJson()).toList(),
      "pointCoffee": pointCoffee.map((e) => e.toJson()).toList(),
      "sayBread": sayBread.map((e) => e.toJson()).toList(),
      "store": {
        "point_coffee": pcStore?.toJson(),
        "say_bread": sbStore?.toJson(),
      },
    };
  }

  Future<void> saveFromServer(Map<String, dynamic> data) async {
    final barcodeList = (data['barcodes'] as List? ?? [])
        .map((e) => BarcodeData.fromJson(e))
        .toList();
    await saveBarcodes(barcodeList);

    final pcList = (data['pointCoffee'] as List? ?? [])
        .map((e) => PointCoffeeHistory.fromJson(e))
        .toList();

    for (final item in pcList) {
      await savePointCoffee(item);
    }

    final sbList = (data['sayBread'] as List? ?? [])
        .map((e) => SayBreadHistory.fromJson(e))
        .toList();

    for (final item in sbList) {
      await saveSayBread(item);
    }

    if (data['store'] != null) {
      if (data['store']['point_coffee'] != null) {
        await savePointCoffeeStore(
          StoreData.fromJson(data['store']['point_coffee']),
        );
      }

      if (data['store']['say_bread'] != null) {
        await saveSayBreadStore(StoreData.fromJson(data['store']['say_bread']));
      }
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
        ),
      );
    }

    await prefs.setStringList(
      pcKey,
      fixed.map((e) => jsonEncode(e.toJson())).toList(),
    );
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
        ),
      );
    }

    await prefs.setStringList(
      pcKey,
      fixed.map((e) => jsonEncode(e.toJson())).toList(),
    );
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

  Future<void> saveBarcode(BarcodeData data) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(barcodeKey) ?? [];

    final barcodes = list
        .map((e) => BarcodeData.fromJson(jsonDecode(e)))
        .toList();

    barcodes.removeWhere((e) => e.code == data.code);

    barcodes.add(data);

    await prefs.setStringList(
      barcodeKey,
      barcodes.map((e) => jsonEncode(e.toJson())).toList(),
    );
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

    final index = list.indexWhere(
      (e) => e.code == oldData.code && e.type == oldData.type,
    );

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

    barcodes.removeWhere((e) => e.code == data.code && e.type == data.type);

    await prefs.setStringList(
      barcodeKey,
      barcodes.map((e) => jsonEncode(e.toJson())).toList(),
    );
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
}
