import 'package:flutter/material.dart';

import '../data/model/point_coffe_history.dart';
import '../data/model/say_bread_history.dart';
import '../service/shared_preferences_service.dart';

class HistoryProvider extends ChangeNotifier {
  HistoryProvider(this._prefsService);

  final SharedPreferencesService _prefsService;

  int _activeTab = 0;
  DateTime _selectedMonthYear = DateTime.now();
  List<PointCoffeeHistory> _pcHistory = [];
  List<SayBreadHistory> _sbHistory = [];

  int get activeTab => _activeTab;

  DateTime get selectedMonthYear => _selectedMonthYear;

  List<PointCoffeeHistory> get pcHistory => _pcHistory;

  List<SayBreadHistory> get sbHistory => _sbHistory;

  void setActiveTab(int value) {
    if (_activeTab == value) return;
    _activeTab = value;
    notifyListeners();
  }

  Future<void> setSelectedMonthYear(DateTime value) async {
    _selectedMonthYear = value;
    await loadHistory();
  }

  Future<void> loadHistory() async {
    final pc = await _prefsService.getPointCoffee();
    final sb = await _prefsService.getSayBread();

    final thisMonth = _selectedMonthYear.month;
    final thisYear = _selectedMonthYear.year;

    _pcHistory = pc.where((e) {
      final year = e.tgl ~/ 10000;
      final month = (e.tgl % 10000) ~/ 100;
      final monthMatch = (thisMonth == 0) ? true : (month == thisMonth);
      return year == thisYear && monthMatch;
    }).toList()..sort((a, b) => a.tgl.compareTo(b.tgl));

    _sbHistory = sb.where((e) {
      final year = e.tgl ~/ 10000;
      final month = (e.tgl % 10000) ~/ 100;
      final monthMatch = (thisMonth == 0) ? true : (month == thisMonth);
      return year == thisYear && monthMatch;
    }).toList()..sort((a, b) => a.tgl.compareTo(b.tgl));

    notifyListeners();
  }
}
