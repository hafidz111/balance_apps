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
    {"title": "2x2 Grid", "subtitle": "2×2 (4 foto)", "rows": 2, "cols": 2},
    {"title": "3x3 Grid", "subtitle": "3×3 (9 foto)", "rows": 3, "cols": 3},
    {"title": "4x4 Grid", "subtitle": "4×4 (16 foto)", "rows": 4, "cols": 4},
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

  Widget _buildGridCard({
    required String title,
    required String subtitle,
    required int rows,
    required int cols,
  }) {
    return GestureDetector(
      onTap: () {
        CustomSnackBar.show(
          context,
          message: "$title dipilih",
          type: SnackType.info,
        );

        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GridChoosePhotoScreen(rows: rows, cols: cols),
            ),
          );
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
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
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: _gridOptions.map((grid) {
                  return _buildGridCard(
                    title: grid['title'],
                    subtitle: grid['subtitle'],
                    rows: grid['rows'],
                    cols: grid['cols'],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
