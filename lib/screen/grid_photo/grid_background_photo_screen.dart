import 'dart:io';
import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:starvy/providers/grid_background_photo_provider.dart';

import '../../service/shared_preferences_service.dart';
import '../../theme/app_colors.dart';
import '../main/main_screen.dart';
import '../widgets/custom_snack_bar.dart';

class GridBackgroundPhotoScreen extends StatefulWidget {
  final Uint8List capturedImage;
  final String title;

  const GridBackgroundPhotoScreen({
    super.key,
    required this.capturedImage,
    required this.title,
  });

  @override
  State<GridBackgroundPhotoScreen> createState() =>
      _GridBackgroundPhotoScreenState();
}

class _GridBackgroundPhotoScreenState extends State<GridBackgroundPhotoScreen> {
  final ScreenshotController screenshotController = ScreenshotController();
  final ImagePicker _picker = ImagePicker();

  static const platform = MethodChannel('gallery_saver');

  final String defaultBg = "assets/images/bg-grid-default.jpeg";

  double _capturedImageRatio = 1.0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _calculateCapturedImageRatio();
      await _loadSavedBackground();
    });
  }

  Future<void> _calculateCapturedImageRatio() async {
    try {
      final codec = await instantiateImageCodec(widget.capturedImage);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      if (mounted) {
        setState(() {
          _capturedImageRatio = image.width / image.height;
        });
      }
    } catch (e) {
      debugPrint("Error calculating image ratio: $e");
    }
  }

  Future<void> _loadSavedBackground() async {
    final provider = context.read<GridBackgroundPhotoProvider>();
    final path = SharedPreferencesService().getCustomBackground();

    if (path != null) {
      final file = File(path);

      if (file.existsSync()) {
        final ratio = await _getImageRatio(file);
        provider.setCustomBackground(file, ratio);
      } else {
        final ratio = await _getAssetImageRatio(defaultBg);
        provider.setDefaultBackground(ratio);
      }
    }

    final ratio = await _getAssetImageRatio(defaultBg);

    if (!mounted) return;
    provider.setDefaultBackground(ratio);
  }

  final TextEditingController textController = TextEditingController();
  final TextEditingController colorController = TextEditingController(
    text: AppColors.gridGreenHex,
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

      await SharedPreferencesService().saveCustomBackground(file.path);

      if (!mounted) return;
      context.read<GridBackgroundPhotoProvider>().setCustomBackground(
        file,
        ratio,
      );
      FirebaseAnalytics.instance.logEvent(name: "grid_background_added");
    }
  }

  Future<double> _getImageRatio(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    return image.width / image.height;
  }

  Future<double> _getAssetImageRatio(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();

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
        if (!mounted) return;
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
      if (!mounted) return;

      Directory directory = Directory("/storage/emulated/0/Pictures/Balance");

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final filePath =
          "${directory.path}/balance_${DateTime.now().millisecondsSinceEpoch}.png";

      File file = File(filePath);
      await file.writeAsBytes(image);
      if (!mounted) return;

      await _scanFile(file.path);

      if (!mounted) return;
      FirebaseAnalytics.instance.logEvent(name: "grid_saved_to_gallery");
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
        final provider = context.read<GridBackgroundPhotoProvider>();
        if (provider.selectedTextIndex == null) return;
        provider.updateSelectedColor(color);
        colorController.text =
            "#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}";
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
    final provider = context.read<GridBackgroundPhotoProvider>();
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
                        provider.updateSelectedText(value);
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
                      value: provider.selectedTextIndex != null
                          ? provider.texts[provider.selectedTextIndex!].fontSize
                          : 28,
                      onChanged: (value) {
                        provider.updateSelectedFontSize(value);
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
                        _colorCircle(AppColors.gridGreen),
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
                      decoration: InputDecoration(
                        hintText: AppColors.gridGreenHex,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        try {
                          final color = hexToColor(value);
                          provider.updateSelectedColor(color);
                        } catch (_) {}
                      },
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        const Text("Bold"),
                        Switch(
                          inactiveTrackColor: Colors.white,
                          inactiveThumbColor: Colors.black,
                          activeThumbColor: AppColors.gridGreen,
                          value: provider.selectedTextIndex != null
                              ? provider
                                    .texts[provider.selectedTextIndex!]
                                    .isBold
                              : false,
                          onChanged: (value) {
                            provider.updateSelectedBold(value);
                            setModalState(() {});
                          },
                        ),
                        const Spacer(),
                        if (provider.selectedTextIndex != null)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              provider.removeSelectedText();
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

  Widget _buildBackground() {
    final provider = context.watch<GridBackgroundPhotoProvider>();
    switch (provider.bgMode) {
      case BackgroundMode.none:
        return Container(color: Colors.black, child: const SizedBox());

      case BackgroundMode.custom:
        if (provider.backgroundImage != null) {
          return Image.file(provider.backgroundImage!, fit: BoxFit.cover);
        }
        return const SizedBox();

      case BackgroundMode.defaultBg:
        return Image.asset(defaultBg, fit: BoxFit.cover);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GridBackgroundPhotoProvider>();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: provider.canvasRatio,
                    child: Container(
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
                              Positioned.fill(child: _buildBackground()),

                              GestureDetector(
                                onScaleStart: (details) {
                                  provider.onImageScaleStart();
                                },
                                onScaleUpdate: (details) {
                                  provider.onImageScaleUpdate(details);
                                },
                                child: Transform.translate(
                                  offset: provider.imageOffset,
                                  child: Transform.scale(
                                    scale: provider.imageScale,
                                    child: Center(
                                      child: Image.memory(widget.capturedImage),
                                    ),
                                  ),
                                ),
                              ),

                              ...provider.texts.asMap().entries.map((entry) {
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
                                          provider.selectText(index);
                                          textController.text = item.text;
                                          _openTextEditor();
                                        },
                                        onPanUpdate: (details) {
                                          provider.moveText(
                                            index,
                                            details.delta,
                                          );
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
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildIconAction(
                        icon: Icons.add_photo_alternate,
                        label: "Tambah",
                        color: Colors.blue,
                        onTap: _pickBackground,
                      ),

                      _buildIconAction(
                        icon: Icons.image,
                        label: "Custom",
                        color: Colors.teal,
                        onTap: _pickBackground,
                      ),

                      _buildIconAction(
                        icon: Icons.refresh,
                        label: "Default",
                        color: Colors.orange,
                        onTap: () async {
                          await SharedPreferencesService()
                              .clearCustomBackground();

                          final ratio = await _getAssetImageRatio(defaultBg);
                          if (!context.mounted) return;
                          context
                              .read<GridBackgroundPhotoProvider>()
                              .setDefaultBackground(ratio);
                        },
                      ),

                      _buildIconAction(
                        icon: Icons.block,
                        label: "None",
                        color: Colors.grey,
                        onTap: () {
                          final isSpecial =
                              widget.title == 'Kalibrasi' ||
                              widget.title == 'Initial';
                          context
                              .read<GridBackgroundPhotoProvider>()
                              .setNoneBackground(
                                _capturedImageRatio,
                                initialScale: isSpecial ? 0.90 : 1.0,
                              );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        final newText = context
                            .read<GridBackgroundPhotoProvider>()
                            .addDefaultText();
                        textController.text = newText.text;

                        FirebaseAnalytics.instance.logEvent(
                          name: "grid_text_added",
                        );
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

  Widget _buildIconAction({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;

    return Flexible(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTap: onTap,
          child: Opacity(
            opacity: isDisabled ? 0.4 : 1,
            child: Column(
              children: [
                Container(
                  height: 56,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
