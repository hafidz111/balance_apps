import 'package:flutter/material.dart';

class ScheduleProvider extends ChangeNotifier {
  Map<String, String> _schedules = {};
  int _shiftCount = 2;
  bool _isLoading = false;
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _storeCode = "FBVO";

  Map<String, String> get schedules => _schedules;

  int get shiftCount => _shiftCount;

  bool get isLoading => _isLoading;

  DateTime get currentMonth => _currentMonth;

  String get storeCode => _storeCode;

  void setSchedules(Map<String, String> value) {
    _schedules = value;
    notifyListeners();
  }

  void setShiftCount(int value) {
    _shiftCount = value;
    notifyListeners();
  }

  void setStoreCode(String value) {
    _storeCode = value;
    notifyListeners();
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setCurrentMonth(DateTime value) {
    _currentMonth = value;
    notifyListeners();
  }
}
