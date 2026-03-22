import 'package:flutter/material.dart';

class StoreProvider extends ChangeNotifier {
  int _activeTab = 0;
  int _dataVersion = 0;

  int get activeTab => _activeTab;

  int get dataVersion => _dataVersion;

  void setActiveTab(int index) {
    if (_activeTab == index) return;
    _activeTab = index;
    notifyListeners();
  }

  void markDataLoaded() {
    _dataVersion++;
    notifyListeners();
  }
}
