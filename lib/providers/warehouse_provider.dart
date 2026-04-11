import 'package:flutter/material.dart';

import '../data/model/barcode_data.dart';
import '../data/model/warehouse_transaction.dart';
import '../service/shared_preferences_service.dart';

class WarehouseProvider extends ChangeNotifier {
  List<WarehouseTransaction> _transactions = [];
  List<BarcodeData> _barcodes = [];
  bool _isLoading = false;

  List<WarehouseTransaction> get transactions => _transactions;
  List<BarcodeData> get barcodes => _barcodes;
  bool get isLoading => _isLoading;

  int get totalMasuk => _transactions
      .where((t) => t.type == 'masuk')
      .fold(0, (sum, t) => sum + t.quantity);

  int get totalKeluar => _transactions
      .where((t) => t.type == 'keluar')
      .fold(0, (sum, t) => sum + t.quantity);

  int get netStok => totalMasuk - totalKeluar;

  int get currentStockCount {
    final map = <String, int>{};
    for (final t in _transactions) {
      if (t.type == 'masuk') {
        map[t.barcodeCode] = (map[t.barcodeCode] ?? 0) + t.quantity;
      } else {
        map[t.barcodeCode] = (map[t.barcodeCode] ?? 0) - t.quantity;
      }
    }
    return map.values.where((v) => v > 0).length;
  }

  int netStokFor(String barcode) {
    int total = 0;
    for (final t in _transactions.where((t) => t.barcodeCode == barcode)) {
      if (t.type == 'masuk') {
        total += t.quantity;
      } else {
        total -= t.quantity;
      }
    }
    return total;
  }

  Map<String, int> get masukPerBarcode {
    final map = <String, int>{};
    for (final t in _transactions.where((t) => t.type == 'masuk')) {
      map[t.barcodeCode] = (map[t.barcodeCode] ?? 0) + t.quantity;
    }
    return map;
  }

  Map<String, int> get keluarPerBarcode {
    final map = <String, int>{};
    for (final t in _transactions.where((t) => t.type == 'keluar')) {
      map[t.barcodeCode] = (map[t.barcodeCode] ?? 0) + t.quantity;
    }
    return map;
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    final service = SharedPreferencesService();
    _transactions = await service.getWarehouseTransactions();
    _barcodes = await service.getBarcodes();

    _isLoading = false;
    notifyListeners();
  }

  Future<WarehouseTransaction?> addTransactionFromScan({
    required String code,
    required String transactionType,
    int quantity = 1,
    String? reason,
  }) async {
    final service = SharedPreferencesService();

    _barcodes = await service.getBarcodes();
    final found = _barcodes.where((b) => b.code == code).firstOrNull;

    final transaction = WarehouseTransaction(
      id: UniqueKey().toString(),
      barcodeCode: code,
      barcodeDescription: found?.description ?? '',
      barcodeType: found?.type,
      type: transactionType,
      quantity: quantity,
      timestamp: DateTime.now(),
      reason: reason,
    );

    await service.saveWarehouseTransaction(transaction);
    _transactions.insert(0, transaction);
    notifyListeners();

    return transaction;
  }

  Future<void> deleteTransaction(String id) async {
    await SharedPreferencesService().deleteWarehouseTransaction(id);
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  Future<void> clearAll() async {
    await SharedPreferencesService().clearWarehouseTransactions();
    _transactions.clear();
    notifyListeners();
  }
}
