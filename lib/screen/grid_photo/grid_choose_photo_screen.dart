import 'dart:io';

import 'package:balance/screen/grid_photo/grid_background_photo_screen.dart';
import 'package:balance/screen/grid_photo/widgets/grid_item.dart';
import 'package:balance/screen/widgets/custom_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
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
  int? activeDeleteIndex;

  @override
  void initState() {
    super.initState();
    images = List.generate(widget.rows * widget.cols, (_) => null);
  }

  Future<void> _pickImage(int index) async {
    final hasPermission = await _requestGalleryPermission();
    if (!hasPermission) {
      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message: "Izin galeri diperlukan",
        type: SnackType.error,
      );
      return;
    }

    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      images[index] = File(picked.path);
      setState(() {});
    }
  }

  Future<void> _pickMultipleImages() async {
    final hasPermission = await _requestGalleryPermission();
    if (!hasPermission) {
      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message: "Izin galeri diperlukan",
        type: SnackType.error,
      );
      return;
    }

    final pickedFiles = await _picker.pickMultiImage();

    if (pickedFiles.isEmpty) return;

    final files = pickedFiles.map((e) => File(e.path)).toList();

    setState(() {
      List<int> emptyIndexes = [];

      for (int i = 0; i < images.length; i++) {
        if (images[i] == null) {
          emptyIndexes.add(i);
        }
      }

      if (emptyIndexes.isNotEmpty) {
        int fileIndex = 0;

        for (int index in emptyIndexes) {
          if (fileIndex >= files.length) break;

          images[index] = files[fileIndex];
          fileIndex++;
        }

        if (files.length > emptyIndexes.length) {
          CustomSnackBar.show(
            context,
            message: "Slot kosong terisi. Sisa gambar diabaikan.",
            type: SnackType.warning,
          );
        }
      } else {
        for (int i = 0; i < images.length && i < files.length; i++) {
          images[i] = files[i];
        }

        CustomSnackBar.show(
          context,
          message: "Grid penuh, gambar diganti semua",
          type: SnackType.warning,
        );
      }
    });
  }

  void _deleteImage(int index) {
    images[index] = null;
    setState(() {});
  }

  Future<bool> _requestGalleryPermission() async {
    if (Platform.isAndroid) {
      final storage = await Permission.storage.request();
      final photos = await Permission.photos.request();

      if (storage.isGranted || photos.isGranted) {
        return true;
      }

      if (storage.isPermanentlyDenied || photos.isPermanentlyDenied) {
        await openAppSettings();
      }

      return false;
    } else {
      final photos = await Permission.photos.request();
      if (photos.isGranted || photos.isLimited) {
        return true;
      }

      if (photos.isPermanentlyDenied) {
        await openAppSettings();
      }

      return false;
    }
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
            isLocked: isSaved,
            showDelete: activeDeleteIndex == index,
            onPick: isSaved ? null : () => _pickImage(index),
            onDelete: isSaved ? null : () => _deleteImage(index),
            onDeleteToggle: isSaved
                ? null
                : () {
                    setState(() {
                      activeDeleteIndex = activeDeleteIndex == index
                          ? null
                          : index;
                    });
                  },
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

    setState(() {
      isSaved = true;
    });
    await Future.delayed(const Duration(milliseconds: 50));

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
                  if (backgroundImage != null)
                    Positioned.fill(
                      child: Image.file(backgroundImage!, fit: BoxFit.cover),
                    ),

                  Center(
                    child: Screenshot(
                      controller: screenshotController,
                      child: _buildGrid(),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _pickMultipleImages,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Pilih Banyak Gambar",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF009688),
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
