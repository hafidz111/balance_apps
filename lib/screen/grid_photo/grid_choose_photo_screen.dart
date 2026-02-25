import 'dart:io';

import 'package:balance/screen/grid_photo/grid_background_photo_screen.dart';
import 'package:balance/screen/grid_photo/widgets/grid_item.dart';
import 'package:balance/screen/widgets/custom_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screenshot/screenshot.dart';

class GridChoosePhotoScreen extends StatefulWidget {
  final int rows;
  final int cols;

  const GridChoosePhotoScreen({
    super.key,
    required this.rows,
    required this.cols,
  });

  @override
  State<GridChoosePhotoScreen> createState() => _GridChoosePhotoScreenState();
}

class _GridChoosePhotoScreenState extends State<GridChoosePhotoScreen> {
  final ImagePicker _picker = ImagePicker();
  final ScreenshotController screenshotController = ScreenshotController();

  late List<File?> images;
  bool isSaved = false;
  File? backgroundImage;

  Offset gridOffset = Offset.zero;
  double gridScale = 1.0;
  double baseScale = 1.0;

  @override
  void initState() {
    super.initState();
    images = List.generate(widget.rows * widget.cols, (_) => null);
  }

  Future<void> _pickImage(int index) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      images[index] = File(picked.path);
      setState(() {});
    }
  }

  void _deleteImage(int index) {
    images[index] = null;
    setState(() {});
  }

  Widget _buildGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: images.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.cols,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          return GridItem(
            image: images[index],
            onPick: isSaved ? null : () => _pickImage(index),
            onDelete: isSaved ? null : () => _deleteImage(index),
          );
        },
      ),
    );
  }

  void _handleSave() async {
    if (images.contains(null)) {
      CustomSnackBar.show(
        context,
        message: "Semua grid harus diisi terlebih dahulu",
        type: SnackType.error,
      );
      return;
    }

    final Uint8List? image = await screenshotController.capture(
      pixelRatio: 3.0,
    );

    if (image == null) return;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GridBackgroundPhotoScreen(capturedImage: image),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  /// Background (tidak ikut ke capture)
                  if (backgroundImage != null)
                    Positioned.fill(
                      child: Image.file(backgroundImage!, fit: BoxFit.cover),
                    ),

                  /// Screenshot hanya untuk GRID
                  Center(
                    child: Screenshot(
                      controller: screenshotController,
                      child: GestureDetector(
                        onScaleStart: (details) {
                          baseScale = gridScale;
                        },
                        onScaleUpdate: isSaved
                            ? (details) {
                                setState(() {
                                  gridScale = (baseScale * details.scale).clamp(
                                    0.5,
                                    3.0,
                                  );
                                  gridOffset += details.focalPointDelta;
                                });
                              }
                            : null,
                        child: Transform.translate(
                          offset: gridOffset,
                          child: Transform.scale(
                            scale: gridScale,
                            child: _buildGrid(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  /// SIMPAN
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF009688),
                        // pastikan sudah ada
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Lanjutkan",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
