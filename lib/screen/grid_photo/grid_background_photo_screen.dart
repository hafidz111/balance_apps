import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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

class _GridBackgroundPhotoScreenState extends State<GridBackgroundPhotoScreen> {
  Offset imageOffset = Offset.zero;
  double imageScale = 1.0;
  double baseScale = 1.0;

  double canvasRatio = 1.0;

  File? backgroundImage;
  final ScreenshotController screenshotController = ScreenshotController();
  final ImagePicker _picker = ImagePicker();

  static const platform = MethodChannel('gallery_saver');

  double fontSize = 28;
  bool isBold = false;

  Offset initialFocalPoint = Offset.zero;
  Offset initialTextOffset = Offset.zero;

  List<TextItem> texts = [];
  int? selectedTextIndex;

  bool showTextEditor = false;
  final TextEditingController textController = TextEditingController();
  final TextEditingController colorController = TextEditingController(
    text: "#038343",
  );

  Color hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) {
      hex = "FF$hex";
    }
    return Color(int.parse(hex, radix: 16));
  }

  Future<void> _pickBackground() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      final file = File(picked.path);
      final ratio = await _getImageRatio(file);

      setState(() {
        backgroundImage = file;
        canvasRatio = ratio;
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

  Future<void> _saveToGallery() async {
    try {
      final hasPermission = await _requestGalleryPermission();
      if (!hasPermission) {
        if(!mounted) return;
        CustomSnackBar.show(
          context,
          message: "Izin storage diperlukan untuk menyimpan",
          type: SnackType.error,
        );
        return;
      }

      final Uint8List? image = await screenshotController.capture(
        pixelRatio: 3.0,
      );

      if (image == null) return;

      Directory directory = Directory("/storage/emulated/0/Pictures/Balance");

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final filePath =
          "${directory.path}/balance_${DateTime.now().millisecondsSinceEpoch}.png";

      File file = File(filePath);
      await file.writeAsBytes(image);
      await _scanFile(file.path);

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

  Future<void> _scanFile(String path) async {
    if (Platform.isAndroid) {
      try {
        await platform.invokeMethod('scanFile', {"path": path});
      } catch (e) {
        debugPrint("Scan error: $e");
      }
    }
  }

  Widget _colorCircle(Color color) {
    return GestureDetector(
      onTap: () {
        if (selectedTextIndex != null) {
          setState(() {
            texts[selectedTextIndex!].color = color;
            colorController.text =
                "#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}";
          });
        }
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  void _openTextEditor() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: textController,
                      decoration: const InputDecoration(
                        hintText: "Edit teks...",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        if (selectedTextIndex != null) {
                          setState(() {
                            texts[selectedTextIndex!].text = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Ukuran Font"),
                    ),

                    Slider(
                      min: 12,
                      max: 80,
                      value: selectedTextIndex != null
                          ? texts[selectedTextIndex!].fontSize
                          : 28,
                      onChanged: (value) {
                        if (selectedTextIndex != null) {
                          setState(() {
                            texts[selectedTextIndex!].fontSize = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Pilih Warna"),
                    ),

                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _colorCircle(const Color(0xFF038343)),
                        _colorCircle(Colors.black),
                        _colorCircle(Colors.white),
                        _colorCircle(Colors.red),
                        _colorCircle(Colors.blue),
                        _colorCircle(Colors.orange),
                        _colorCircle(Colors.purple),
                        _colorCircle(Colors.teal),
                      ],
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: colorController,
                      decoration: const InputDecoration(
                        hintText: "#038343",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        if (selectedTextIndex != null) {
                          try {
                            final color = hexToColor(value);
                            setState(() {
                              texts[selectedTextIndex!].color = color;
                            });
                          } catch (_) {}
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        const Text("Bold"),
                        Switch(
                          inactiveTrackColor: Colors.white,
                          inactiveThumbColor: Colors.black,
                          activeThumbColor: const Color(0xFF038343),
                          value: selectedTextIndex != null
                              ? texts[selectedTextIndex!].isBold
                              : false,
                          onChanged: (value) {
                            if (selectedTextIndex != null) {
                              // update canvas
                              setState(() {
                                texts[selectedTextIndex!].isBold = value;
                              });

                              // update bottomsheet
                              setModalState(() {});
                            }
                          },
                        ),
                        const Spacer(),
                        if (selectedTextIndex != null)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                texts.removeAt(selectedTextIndex!);
                              });
                              Navigator.pop(context);
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
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

                            ...texts.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;

                              return Positioned(
                                left: item.offset.dx,
                                top: item.offset.dy,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        selectedTextIndex = index;
                                        textController.text = item.text;
                                        _openTextEditor();
                                      },
                                      onPanUpdate: (details) {
                                        setState(() {
                                          item.offset += details.delta;
                                        });
                                      },
                                      child: Text(
                                        item.text,
                                        style: TextStyle(
                                          fontSize: item.fontSize,
                                          fontWeight: item.isBold
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: item.color,
                                          shadows: const [
                                            Shadow(
                                              blurRadius: 6,
                                              color: Colors.black54,
                                              offset: Offset(2, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
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

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        final newText = TextItem(
                          text: "Teks Baru",
                          offset: const Offset(100, 100),
                          fontSize: 28,
                          isBold: false,
                          color: const Color(0xFF038343),
                        );

                        setState(() {
                          texts.add(newText);
                          selectedTextIndex = texts.length - 1;
                          textController.text = newText.text;
                          showTextEditor = true;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Tambah Teks",
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
