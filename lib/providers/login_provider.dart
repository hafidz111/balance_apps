import 'package:flutter/material.dart';

class LoginProvider extends ChangeNotifier {
  bool _loading = false;
  bool _hidePass = true;

  bool get loading => _loading;

  bool get hidePass => _hidePass;

  void setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void toggleHidePass() {
    _hidePass = !_hidePass;
    notifyListeners();
  }
}
