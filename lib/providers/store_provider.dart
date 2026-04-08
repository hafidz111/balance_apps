import 'package:flutter/material.dart';

import '../data/model/store_data.dart';
import '../service/shared_preferences_service.dart';

class StoreProvider extends ChangeNotifier {
  int _activeTab = 0;
  int _dataVersion = 0;

  final pcTitle = TextEditingController();
  final pcNama = TextEditingController();
  final pcKode = TextEditingController();
  final pcTgl = TextEditingController();
  final pcArea = TextEditingController();

  final sbTitle = TextEditingController();
  final sbNama = TextEditingController();
  final sbKode = TextEditingController();
  final sbTgl = TextEditingController();
  final sbArea = TextEditingController();

  bool _isPcChanged = false;
  bool _isSbChanged = false;

  int get activeTab => _activeTab;

  int get dataVersion => _dataVersion;

  bool get isPcChanged => _isPcChanged;

  bool get isSbChanged => _isSbChanged;

  final SharedPreferencesService _service;

  StoreProvider(this._service) {
    _initListeners();
    loadStoreData();
  }

  void _initListeners() {
    final pcControllers = [pcTitle, pcNama, pcKode, pcTgl, pcArea];
    for (var controller in pcControllers) {
      controller.addListener(() {
        _isPcChanged = true;
        notifyListeners();
      });
    }

    final sbControllers = [sbTitle, sbNama, sbKode, sbTgl, sbArea];
    for (var controller in sbControllers) {
      controller.addListener(() {
        _isSbChanged = true;
        notifyListeners();
      });
    }
  }

  void setActiveTab(int index) {
    if (_activeTab == index) return;
    _activeTab = index;
    notifyListeners();
  }

  Future<void> loadStoreData() async {
    final pc = await _service.getPointCoffeeStore();
    if (pc != null) {
      pcTitle.text = pc.title;
      pcNama.text = pc.nama;
      pcKode.text = pc.kode;
      pcTgl.text = pc.tgl;
      pcArea.text = pc.area;
    } else {
      pcTitle.clear();
      pcNama.clear();
      pcKode.clear();
      pcTgl.clear();
      pcArea.clear();
    }

    final sb = await _service.getSayBreadStore();
    if (sb != null) {
      sbTitle.text = sb.title;
      sbNama.text = sb.nama;
      sbKode.text = sb.kode;
      sbTgl.text = sb.tgl;
      sbArea.text = sb.area;
    } else {
      sbTitle.clear();
      sbNama.clear();
      sbKode.clear();
      sbTgl.clear();
      sbArea.clear();
    }

    _isPcChanged = false;
    _isSbChanged = false;

    _dataVersion++;
    notifyListeners();
  }

  Future<void> saveStoreData(String category) async {
    if (category == "Coffee") {
      await _service.savePointCoffeeStore(
        StoreData(
          title: pcTitle.text,
          nama: pcNama.text,
          kode: pcKode.text,
          tgl: pcTgl.text,
          area: pcArea.text,
        ),
      );
      _isPcChanged = false;
    } else {
      await _service.saveSayBreadStore(
        StoreData(
          title: sbTitle.text,
          nama: sbNama.text,
          kode: sbKode.text,
          tgl: sbTgl.text,
          area: sbArea.text,
        ),
      );
      _isSbChanged = false;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    pcTitle.dispose();
    pcNama.dispose();
    pcKode.dispose();
    pcTgl.dispose();
    pcArea.dispose();

    sbTitle.dispose();
    sbNama.dispose();
    sbKode.dispose();
    sbTgl.dispose();
    sbArea.dispose();
    super.dispose();
  }
}
