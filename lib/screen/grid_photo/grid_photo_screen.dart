import 'dart:io';

import 'package:balance/screen/widgets/custom_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';

import 'grid_choose_photo_screen.dart';

class GridPhotoScreen extends StatefulWidget {
  const GridPhotoScreen({super.key});

  @override
  State<GridPhotoScreen> createState() => _GridPhotoScreenState();
}

class _GridPhotoScreenState extends State<GridPhotoScreen> {
  final ScreenshotController screenshotController = ScreenshotController();

  int gridCount = 4;
  bool gridSelected = false;
  bool isSaved = false;

  List<File?> images = [];
  File? backgroundImage;

  Offset gridOffset = Offset.zero;
  double gridScale = 1.0;
  double baseScale = 1.0;

  final List<Map<String, dynamic>> _gridOptions = [
    {"title": "Hit & Run", "icon": Icons.run_circle, "rows": 2, "cols": 2},
    {
      "title": "Kalibrasi",
      "icon": Icons.compass_calibration,
      "rows": 3,
      "cols": 3,
    },
    {
      "title": "Initial",
      "icon": Icons.dashboard_customize,
      "rows": 4,
      "cols": 4,
    },
  ];

  final List<Map<String, Color>> _menuColors = [
    {"bg": const Color(0xFFE3F2FD), "icon": const Color(0xFF1976D2)},
    {"bg": const Color(0xFFFFF3E0), "icon": const Color(0xFFF57C00)},
    {"bg": const Color(0xFFE8F5E9), "icon": const Color(0xFF388E3C)},
    {"bg": const Color(0xFFF3E5F5), "icon": const Color(0xFF7B1FA2)},
    {"bg": const Color(0xFFFFEBEE), "icon": const Color(0xFFD32F2F)},
    {"bg": const Color(0xFFE0F7FA), "icon": const Color(0xFF00838F)},
  ];

  @override
  void initState() {
    super.initState();
  }

  int get crossAxisCount {
    if (gridCount == 4) return 2;
    if (gridCount == 6) return 3;
    if (gridCount == 8) return 4;
    if (gridCount == 10) return 5;
    return 3;
  }

  Widget _buildMenuItem({
    required int index,
    required String title,
    required IconData icon,
    required int rows,
    required int cols,
  }) {
    final colorSet = _menuColors[index % _menuColors.length];

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        CustomSnackBar.show(
          context,
          message: "$title dipilih",
          type: SnackType.info,
        );

        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GridChoosePhotoScreen(rows: rows, cols: cols),
            ),
          );
        });
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorSet["bg"],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(child: Icon(icon, size: 40, color: colorSet["icon"])),
          ),

          const SizedBox(height: 12),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GridView.builder(
                    itemCount: _gridOptions.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridOptions.length >= 4
                          ? 4
                          : _gridOptions.length,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.65,
                    ),
                    itemBuilder: (context, index) {
                      final grid = _gridOptions[index];
                      return _buildMenuItem(
                        index: index,
                        title: grid['title'],
                        icon: grid['icon'],
                        rows: grid['rows'],
                        cols: grid['cols'],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
