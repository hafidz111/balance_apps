import 'package:flutter/material.dart';

import '../service/shared_preferences_service.dart';

class SharedPreferenceProvider extends ChangeNotifier {
  final SharedPreferencesService _service;

  SharedPreferenceProvider(this._service);

  bool _isLogin = false;
  bool get isLogin => _isLogin;

  Future init() async {
    _isLogin = _service.isLogin;
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
}