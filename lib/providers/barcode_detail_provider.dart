import 'package:flutter/material.dart';

import '../data/model/barcode_data.dart';

class BarcodeDetailProvider extends ChangeNotifier {
  BarcodeData? _current;

  BarcodeData get current => _current!;

  void init(BarcodeData data) {
    _current = data;
  }

  void setCurrent(BarcodeData data) {
    _current = data;
    notifyListeners();
  }
}
