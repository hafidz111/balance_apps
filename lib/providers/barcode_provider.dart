import 'package:flutter/material.dart';

import '../data/model/barcode_data.dart';
import '../service/shared_preferences_service.dart';

class BarcodeProvider extends ChangeNotifier {
  bool _isOpened = false;
  bool _isSelectionMode = false;
  Set<int> _selectedIndexes = {};
  List<BarcodeData> _barcodes = [];
  List<BarcodeData> _filteredBarcodes = [];
  String _searchQuery = '';

  bool get isOpened => _isOpened;
  bool get isSelectionMode => _isSelectionMode;
  Set<int> get selectedIndexes => _selectedIndexes;
  List<BarcodeData> get barcodes => _barcodes;
  List<BarcodeData> get filteredBarcodes => _filteredBarcodes;
  String get searchQuery => _searchQuery;

  Future<void> load() async {
    _barcodes = await SharedPreferencesService().getBarcodes();
    _applyFilter(_searchQuery);
    notifyListeners();
  }

  void toggleMenu() {
    _isOpened = !_isOpened;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilter(query);
    notifyListeners();
  }

  void onLongPressItem(int index) {
    _isSelectionMode = true;
    _selectedIndexes.add(index);
    notifyListeners();
  }

  void onTapItemSelection(int index) {
    if (!_isSelectionMode) return;
    if (_selectedIndexes.contains(index)) {
      _selectedIndexes.remove(index);
      if (_selectedIndexes.isEmpty) _isSelectionMode = false;
    } else {
      _selectedIndexes.add(index);
    }
    notifyListeners();
  }

  void exitSelectionMode() {
    _isSelectionMode = false;
    _selectedIndexes.clear();
    notifyListeners();
  }

  void selectAll() {
    _selectedIndexes = List.generate(_filteredBarcodes.length, (i) => i).toSet();
    _isSelectionMode = _selectedIndexes.isNotEmpty;
    notifyListeners();
  }

  Future<int> deleteSelected() async {
    final selectedItems = _selectedIndexes.map((i) => _filteredBarcodes[i]).toList();
    _barcodes.removeWhere((b) => selectedItems.contains(b));
    await SharedPreferencesService().saveBarcodes(_barcodes);
    _isSelectionMode = false;
    _selectedIndexes.clear();
    _applyFilter(_searchQuery);
    notifyListeners();
    return selectedItems.length;
  }

  void _applyFilter(String query) {
    final lowerQuery = query.toLowerCase();
    _filteredBarcodes = _barcodes.where((b) {
      final codeMatch = b.code.toLowerCase().contains(lowerQuery);
      final descMatch = b.description.toLowerCase().contains(lowerQuery);
      return codeMatch || descMatch;
    }).toList();
  }
}
