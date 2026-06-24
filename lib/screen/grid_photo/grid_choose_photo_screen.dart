import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:screenshot/screenshot.dart';
import 'package:starvy/screen/grid_photo/grid_background_photo_screen.dart';
import 'package:starvy/screen/grid_photo/widgets/grid_item.dart';
import 'package:starvy/screen/widgets/custom_snack_bar.dart';

import '../../providers/grid_choose_photo_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/gallery_access_helper.dart';

class GridChoosePhotoScreen extends StatefulWidget {
  final int rows;
  final int cols;
  final String title;

  const GridChoosePhotoScreen({
    super.key,
    required this.rows,
    required this.cols,
    required this.title,
  });

  @override
  State<GridChoosePhotoScreen> createState() => _GridChoosePhotoScreenState();
}

class _GridChoosePhotoScreenState extends State<GridChoosePhotoScreen> {
  final ScreenshotController screenshotController = ScreenshotController();

  File? backgroundImage;

  int get _slotCount {
    if (widget.title == 'Kalibrasi') {
      return 5;
    }
    if (widget.title == 'Initial') {
      return 6;
    }
    return widget.rows * widget.cols;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => context.read<GridChoosePhotoProvider>().initGrid(_slotCount),
    );
  }

  Future<void> _pickImage(int index) async {
    final picked = await GalleryAccessHelper.pickImage();
    if (picked != null) {
      context.read<GridChoosePhotoProvider>().setImageAt(
        index,
        File(picked.path),
      );
    }

    FirebaseAnalytics.instance.logEvent(
      name: "grid_image_added",
      parameters: {"index": index},
    );
  }

  Future<void> _pickMultipleImages() async {
    final pickedFiles = await GalleryAccessHelper.pickMultiImage();

    if (pickedFiles.isEmpty) return;

    final files = pickedFiles.map((e) => File(e.path)).toList();

    final provider = context.read<GridChoosePhotoProvider>();
    final images = List<File?>.from(provider.images);
    {
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
      provider.setImages(images);
    }

    FirebaseAnalytics.instance.logEvent(name: "grid_multi_image_added");
  }

  void _deleteImage(int index) {
    context.read<GridChoosePhotoProvider>().setImageAt(index, null);
  }

  Widget _gridBox(int index) {
    final images = context.watch<GridChoosePhotoProvider>().images;
    if (images[index] == null) {
      return _buildItem(index);
    }

    return LongPressDraggable<int>(
      data: index,

      onDragStarted: () {
        HapticFeedback.mediumImpact();
      },

      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: MediaQuery.of(context).size.width / widget.cols,
          height: MediaQuery.of(context).size.width / widget.cols,
          child: _buildItem(index),
        ),
      ),

      childWhenDragging: Opacity(opacity: 0.3, child: _buildItem(index)),

      child: DragTarget<int>(
        onAccept: (fromIndex) {
          context.read<GridChoosePhotoProvider>().swap(fromIndex, index);
        },

        builder: (context, candidateData, rejectedData) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              border: candidateData.isNotEmpty
                  ? Border.all(color: Colors.teal, width: 2)
                  : null,
            ),
            child: _buildItem(index),
          );
        },
      ),
    );
  }

  Widget _buildItem(int index) {
    final provider = context.watch<GridChoosePhotoProvider>();
    final images = provider.images;
    final isSaved = provider.isSaved;
    final activeDeleteIndex = provider.activeDeleteIndex;
    return GridItem(
      image: images.length > index ? images[index] : null,
      isLocked: isSaved,
      showDelete: activeDeleteIndex == index,
      onPick: isSaved ? null : () => _pickImage(index),
      onDelete: isSaved ? null : () => _deleteImage(index),
      onDeleteToggle: isSaved
          ? null
          : () {
              context.read<GridChoosePhotoProvider>().toggleDeleteIndex(index);
            },
    );
  }

  Widget _buildInitial() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        final double fullHeight = width / 2;
        final double height3 = width / 3;
        final double height2 = width / 2;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: width, height: fullHeight, child: _gridBox(0)),

            Row(
              children: List.generate(3, (i) {
                return SizedBox(
                  width: width / 3,
                  height: height3,
                  child: _gridBox(i + 1),
                );
              }),
            ),

            Row(
              children: List.generate(2, (i) {
                return SizedBox(
                  width: width / 2,
                  height: height2,
                  child: _gridBox(i + 4),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKalibrasi() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        final double fullHeight = width / 2;
        final double height2 = width / 2;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: width, height: fullHeight, child: _gridBox(0)),

            Row(
              children: List.generate(2, (i) {
                return SizedBox(
                  width: width / 2,
                  height: height2,
                  child: _gridBox(i + 1),
                );
              }),
            ),

            Row(
              children: List.generate(2, (i) {
                return SizedBox(
                  width: width / 2,
                  height: height2,
                  child: _gridBox(i + 3),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDefaultGrid() {
    final provider = context.watch<GridChoosePhotoProvider>();
    final images = provider.images;
    final isSaved = provider.isSaved;
    final activeDeleteIndex = provider.activeDeleteIndex;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ReorderableGridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: images.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.cols,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        onReorder: (oldIndex, newIndex) {
          context.read<GridChoosePhotoProvider>().reorder(oldIndex, newIndex);
        },
        itemBuilder: (context, index) {
          return Container(
            key: ValueKey("item_$index"),
            child: GridItem(
              image: images[index],
              isLocked: isSaved,
              showDelete: activeDeleteIndex == index,
              onPick: isSaved ? null : () => _pickImage(index),
              onDelete: isSaved ? null : () => _deleteImage(index),
              onDeleteToggle: isSaved
                  ? null
                  : () {
                      context.read<GridChoosePhotoProvider>().toggleDeleteIndex(
                        index,
                      );
                    },
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrid() {
    if (widget.title == "Kalibrasi") {
      return _buildKalibrasi();
    } else if (widget.title == "Initial") {
      return _buildInitial();
    } else {
      return _buildDefaultGrid();
    }
  }

  void _handleSave() async {
    final provider = context.read<GridChoosePhotoProvider>();
    final images = provider.images;
    if (images.contains(null)) {
      CustomSnackBar.show(
        context,
        message: "Semua grid harus diisi terlebih dahulu",
        type: SnackType.error,
      );
      return;
    }

    provider.setSaved(true);
    await Future.delayed(const Duration(milliseconds: 50));

    if (!mounted) {
      provider.setSaved(false);
      return;
    }

    final Uint8List? image = await screenshotController.capture(
      pixelRatio: 3.0,
    );

    if (image == null) {
      if (mounted) provider.setSaved(false);
      return;
    }
    if (!mounted) {
      provider.setSaved(false);
      return;
    }

    FirebaseAnalytics.instance.logEvent(
      name: "grid_layout_completed",
      parameters: {"total_slots": images.length},
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GridBackgroundPhotoScreen(
          capturedImage: image,
          title: widget.title,
        ),
      ),
    ).then((_) {
      if (!context.mounted) return;
      context.read<GridChoosePhotoProvider>().setSaved(false);
    });
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
                        backgroundColor: AppColors.primary,
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
