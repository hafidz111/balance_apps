import 'package:flutter/material.dart';

class MainScreenProvider extends ChangeNotifier {
  int _selectedIndex = 1;
  int _barcodeRefreshKey = 0;
  bool _isBarcodeSelectionMode = false;
  int _selectedBarcodeCount = 0;

  int get selectedIndex => _selectedIndex;

  int get barcodeRefreshKey => _barcodeRefreshKey;

  bool get isBarcodeSelectionMode => _isBarcodeSelectionMode;

  int get selectedBarcodeCount => _selectedBarcodeCount;

  void setInitialIndex(int index) {
    if (_selectedIndex == index) return;
    _selectedIndex = index;
    notifyListeners();
  }

  void setSelectedIndex(int index) {
    if (_selectedIndex == index) return;
    _selectedIndex = index;
    notifyListeners();
  }

  void setBarcodeSelection(bool isSelecting, int count) {
    _isBarcodeSelectionMode = isSelecting;
    _selectedBarcodeCount = count;
    notifyListeners();
  }

  void refreshBarcodeAndOpenTab() {
    _barcodeRefreshKey++;
    _selectedIndex = 4;
    notifyListeners();
  }
}
