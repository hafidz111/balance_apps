import 'package:flutter/material.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback onWhatsApp;

  const ActionButtons({super.key, required this.onWhatsApp});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 45,
          child: ElevatedButton.icon(
            onPressed: onWhatsApp,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text(
              "Kirim ke WhatsApp",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
