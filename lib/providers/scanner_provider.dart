import 'package:flutter/material.dart';

class ScannerProvider extends ChangeNotifier {
  bool _isScanned = false;
  bool _hasPermission = false;

  bool get isScanned => _isScanned;

  bool get hasPermission => _hasPermission;

  void setPermission(bool value) {
    if (_hasPermission == value) return;
    _hasPermission = value;
    notifyListeners();
  }

  void markScanned() {
    _isScanned = true;
    notifyListeners();
  }

  void resetScan() {
    if (!_isScanned) return;
    _isScanned = false;
    notifyListeners();
  }
}
