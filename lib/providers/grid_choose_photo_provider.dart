import 'dart:io';

import 'package:flutter/material.dart';

class GridChoosePhotoProvider extends ChangeNotifier {
  List<File?> _images = [];
  bool _isSaved = false;
  int? _activeDeleteIndex;

  List<File?> get images => _images;

  bool get isSaved => _isSaved;

  int? get activeDeleteIndex => _activeDeleteIndex;

  void initGrid(int count) {
    _images = List.generate(count, (_) => null);
    notifyListeners();
  }

  void setImageAt(int index, File? file) {
    _images[index] = file;
    notifyListeners();
  }

  void setImages(List<File?> files) {
    _images = files;
    notifyListeners();
  }

  void swap(int from, int to) {
    final temp = _images[from];
    _images[from] = _images[to];
    _images[to] = temp;
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final item = _images.removeAt(oldIndex);
    _images.insert(newIndex, item);
    notifyListeners();
  }

  void toggleDeleteIndex(int index) {
    _activeDeleteIndex = _activeDeleteIndex == index ? null : index;
    notifyListeners();
  }

  void setSaved(bool value) {
    _isSaved = value;
    notifyListeners();
  }
}
