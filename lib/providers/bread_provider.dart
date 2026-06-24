import 'package:flutter/material.dart';

class BreadProvider extends ChangeNotifier {
  static const int maxShift = 4;

  int _shiftCount = 2;
  int _formVersion = 0;

  int get shiftCount => _shiftCount;

  int get formVersion => _formVersion;

  void setShiftCount(int value) {
    final next = value.clamp(1, maxShift);
    if (_shiftCount == next) return;
    _shiftCount = next;
    notifyListeners();
  }

  void markFormChanged() {
    _formVersion++;
    notifyListeners();
  }
}
