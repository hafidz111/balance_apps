import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screenshot/screenshot.dart';

import '../main/main_screen.dart';
import '../widgets/custom_snack_bar.dart';

class GridBackgroundPhotoScreen extends StatefulWidget {
  final Uint8List capturedImage;

  const GridBackgroundPhotoScreen({super.key, required this.capturedImage});

  @override
  State<GridBackgroundPhotoScreen> createState() =>
      _GridBackgroundPhotoScreenState();
}

class _GridBackgroundPhotoScreenState extends State<GridBackgroundPhotoScreen> {
  Offset imageOffset = Offset.zero;
  double imageScale = 1.0;
  double baseScale = 1.0;

  double canvasRatio = 1.0; // default 1:1

  File? backgroundImage;
  final ScreenshotController screenshotController = ScreenshotController();
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickBackground() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      final file = File(picked.path);
      final ratio = await _getImageRatio(file);

      setState(() {
        backgroundImage = file;
        canvasRatio = ratio; // tambahkan state double canvasRatio
      });
    }
  }

  Future<double> _getImageRatio(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    return image.width / image.height;
  }

  Future<void> _saveToGallery() async {
    try {
      /// 1️⃣ Capture Screenshot
      final Uint8List? image = await screenshotController.capture(
        pixelRatio: 3.0,
      );

      if (image == null) return;

      /// 2️⃣ Request Permission (Android 13+ aman)
      await Permission.photos.request();
      await Permission.storage.request();

      /// 3️⃣ Get Directory
      Directory? directory;

      if (Platform.isAndroid) {
        directory = Directory("/storage/emulated/0/Pictures/Balance");
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      /// 4️⃣ Create Folder If Not Exist
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      /// 5️⃣ Save File
      final filePath =
          "${directory.path}/grid_${DateTime.now().millisecondsSinceEpoch}.png";

      File file = File(filePath);
      await file.writeAsBytes(image);
      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message: "Berhasil disimpan ke ${directory.path}",
        type: SnackType.success,
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint("Error saving: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            /// CANVAS AREA
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: canvasRatio,
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Screenshot(
                        controller: screenshotController,
                        child: Stack(
                          children: [
                            if (backgroundImage != null)
                              Positioned.fill(
                                child: Image.file(
                                  backgroundImage!,
                                  fit: BoxFit.cover,
                                ),
                              ),

                            GestureDetector(
                              onScaleStart: (details) {
                                baseScale = imageScale;
                              },
                              onScaleUpdate: (details) {
                                setState(() {
                                  imageScale = (baseScale * details.scale)
                                      .clamp(0.5, 3.0);
                                  imageOffset += details.focalPointDelta;
                                });
                              },
                              child: Transform.translate(
                                offset: imageOffset,
                                child: Transform.scale(
                                  scale: imageScale,
                                  child: Center(
                                    child: Image.memory(widget.capturedImage),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            /// BUTTON AREA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  /// TAMBAH BACKGROUND
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _pickBackground,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Tambah Background",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// HAPUS BACKGROUND
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: backgroundImage == null
                          ? null
                          : () {
                              setState(() {
                                backgroundImage = null;
                                canvasRatio = 1.0;
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Hapus Background",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// SAVE
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveToGallery,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Save ke Gallery",
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
