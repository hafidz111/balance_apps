import 'dart:io';

import 'package:flutter/material.dart';

class GridItem extends StatefulWidget {
  final File? image;
  final VoidCallback? onPick;
  final VoidCallback? onDelete;

  const GridItem({
    super.key,
    required this.image,
    required this.onPick,
    required this.onDelete,
  });

  @override
  State<GridItem> createState() => GridItemState();
}

class GridItemState extends State<GridItem> {
  bool showDelete = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.image == null && widget.onPick != null) {
          widget.onPick!();
        } else if (widget.image != null && widget.onDelete != null) {
          setState(() {
            showDelete = !showDelete;
          });
        }
      },
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: widget.image == null
                  ? Border.all(color: Colors.grey.shade300, width: 1.5)
                  : null,
            ),
            child: ClipRRect(
              child: widget.image != null
                  ? SizedBox.expand(
                      child: Image.file(widget.image!, fit: BoxFit.cover),
                    )
                  : SizedBox.expand(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.image_outlined,
                              size: 32,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Tambah Foto",
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),

          if (widget.image != null && showDelete)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
