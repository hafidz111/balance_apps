import 'dart:io';

import 'package:flutter/material.dart';

enum BackgroundMode { defaultBg, custom, none }

class TextItem {
  String text;
  Offset offset;
  double fontSize;
  bool isBold;
  Color color;

  TextItem({
    required this.text,
    required this.offset,
    required this.fontSize,
    required this.isBold,
    required this.color,
  });
}

class GridBackgroundPhotoProvider extends ChangeNotifier {
  Offset _imageOffset = Offset.zero;
  double _imageScale = 1.0;
  double _baseScale = 1.0;
  double _canvasRatio = 1.0;
  File? _backgroundImage;
  BackgroundMode _bgMode = BackgroundMode.defaultBg;
  final List<TextItem> _texts = [];
  int? _selectedTextIndex;

  Offset get imageOffset => _imageOffset;

  double get imageScale => _imageScale;

  double get canvasRatio => _canvasRatio;

  File? get backgroundImage => _backgroundImage;

  BackgroundMode get bgMode => _bgMode;

  List<TextItem> get texts => _texts;

  int? get selectedTextIndex => _selectedTextIndex;

  void onImageScaleStart() {
    _baseScale = _imageScale;
  }

  void onImageScaleUpdate(ScaleUpdateDetails details) {
    _imageScale = (_baseScale * details.scale).clamp(0.5, 3.0);
    _imageOffset += details.focalPointDelta;
    notifyListeners();
  }

  void setCustomBackground(File image, double ratio) {
    _backgroundImage = image;
    _canvasRatio = ratio;
    _bgMode = BackgroundMode.custom;
    notifyListeners();
  }

  void setDefaultBackground(double ratio) {
    _backgroundImage = null;
    _bgMode = BackgroundMode.defaultBg;
    _canvasRatio = ratio;
    notifyListeners();
  }

  void setNoneBackground() {
    _backgroundImage = null;
    _bgMode = BackgroundMode.none;
    _canvasRatio = 1.0;
    notifyListeners();
  }

  void selectText(int index) {
    _selectedTextIndex = index;
    notifyListeners();
  }

  void moveText(int index, Offset delta) {
    _texts[index].offset += delta;
    notifyListeners();
  }

  void updateSelectedText(String value) {
    if (_selectedTextIndex == null) return;
    _texts[_selectedTextIndex!].text = value;
    notifyListeners();
  }

  void updateSelectedFontSize(double value) {
    if (_selectedTextIndex == null) return;
    _texts[_selectedTextIndex!].fontSize = value;
    notifyListeners();
  }

  void updateSelectedColor(Color value) {
    if (_selectedTextIndex == null) return;
    _texts[_selectedTextIndex!].color = value;
    notifyListeners();
  }

  void updateSelectedBold(bool value) {
    if (_selectedTextIndex == null) return;
    _texts[_selectedTextIndex!].isBold = value;
    notifyListeners();
  }

  void removeSelectedText() {
    if (_selectedTextIndex == null) return;
    _texts.removeAt(_selectedTextIndex!);
    _selectedTextIndex = null;
    notifyListeners();
  }

  TextItem addDefaultText() {
    final newText = TextItem(
      text: "Teks Baru",
      offset: const Offset(100, 100),
      fontSize: 28,
      isBold: false,
      color: const Color(0xFF038343),
    );
    _texts.add(newText);
    _selectedTextIndex = _texts.length - 1;
    notifyListeners();
    return newText;
  }
}
