import 'package:flutter/material.dart';

import '../service/shared_preferences_service.dart';

class SharedPreferenceProvider extends ChangeNotifier {
  final SharedPreferencesService _service;

  SharedPreferenceProvider(this._service) {
    _load();
  }

  bool _isLogin = false;

  bool get isLogin => _isLogin;
  String? _phoneNumber;
  int? _shiftCount;

  String? get phoneNumber => _phoneNumber;

  int? get shiftCount => _shiftCount;

  Future<void> _load() async {
    _isLogin = _service.isLogin;
    _phoneNumber = _service.getPhoneNumber();
    _shiftCount = _service.getShiftCount();
    notifyListeners();
  }

  Future login() async {
    await _service.login();
    _isLogin = true;
    notifyListeners();
  }

  Future logout() async {
    await _service.logout();
    _isLogin = false;
    notifyListeners();
  }

  Future<void> savePhoneNumber(String phone) async {
    await _service.savePhoneNumber(phone);
    _phoneNumber = phone;
    notifyListeners();
  }

  Future<void> saveShiftCount(int shift) async {
    await _service.saveShiftCount(shift);
    _shiftCount = shift;
    notifyListeners();
  }
}
