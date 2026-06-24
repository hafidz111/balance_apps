import 'package:flutter/material.dart';

class GridTemplate {
  const GridTemplate({
    required this.title,
    required this.icon,
    required this.rows,
    required this.cols,
  });

  final String title;
  final IconData icon;
  final int rows;
  final int cols;
}

class GridPhotoProvider extends ChangeNotifier {
  static const List<GridTemplate> templates = [
    GridTemplate(title: 'Hit & Run', icon: Icons.run_circle, rows: 2, cols: 2),
    GridTemplate(
      title: 'Kalibrasi',
      icon: Icons.compass_calibration,
      rows: 3,
      cols: 3,
    ),
    GridTemplate(
      title: 'Initial',
      icon: Icons.dashboard_customize,
      rows: 4,
      cols: 4,
    ),
    GridTemplate(
      title: 'General Cleaning',
      icon: Icons.clean_hands,
      rows: 3,
      cols: 3,
    ),
  ];

  int? _lastSelectedIndex;

  int? get lastSelectedIndex => _lastSelectedIndex;

  GridTemplate? get lastSelectedTemplate {
    final i = _lastSelectedIndex;
    if (i == null || i < 0 || i >= templates.length) return null;
    return templates[i];
  }

  void markSelected(int index) {
    if (index < 0 || index >= templates.length) return;
    if (_lastSelectedIndex == index) return;
    _lastSelectedIndex = index;
    notifyListeners();
  }
}
