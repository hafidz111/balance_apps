import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/model/point_coffe_history.dart';
import '../data/model/say_bread_history.dart';
import '../data/model/store_data.dart';

class SharedPreferencesService {
  static const pcKey = 'point_coffee_history';
  static const sbKey = 'say_bread_history';
  static const pcStoreKey = 'pc_store_data';
  static const sbStoreKey = 'sb_store_data';

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
}
