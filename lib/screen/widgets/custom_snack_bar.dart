import 'dart:async';

import 'package:flutter/material.dart';

enum SnackType { success, error, warning, info }

class CustomSnackBar {
  static OverlayEntry? _overlayEntry;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required String message,
    SnackType type = SnackType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    _overlayEntry?.remove();
    _timer?.cancel();

    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (_) => _SnackBarWidget(message: message, type: type),
    );

    overlay.insert(_overlayEntry!);

    _timer = Timer(duration, () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }
}

class _SnackBarWidget extends StatelessWidget {
  final String message;
  final SnackType type;

  const _SnackBarWidget({required this.message, required this.type});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;
    Color bgColor;
    Color textColor;

    switch (type) {
      case SnackType.success:
        icon = Icons.check;
        iconColor = Colors.white;
        bgColor = Colors.green;
        textColor = Colors.white;
        break;
      case SnackType.error:
        icon = Icons.close;
        iconColor = Colors.white;
        bgColor = Colors.red;
        textColor = Colors.white;
        break;
      case SnackType.warning:
        icon = Icons.warning;
        iconColor = Colors.white;
        bgColor = Colors.orange;
        textColor = Colors.white;
        break;
      default:
        icon = Icons.info_outline;
        iconColor = Colors.black;
        bgColor = Colors.white;
        textColor = Colors.black;
    }

    return Positioned(
      bottom: 40,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white24,
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
