import 'package:flutter/material.dart';

import '../widgets/barcode_form.dart';

class ChooseBarcodeScreen extends StatelessWidget {
  const ChooseBarcodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Choose Barcode")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildBarcodeCard(
              context: context,
              title: "Code128",
              subtitle: "Hingga 80 karakter ASCII (contoh: Abc 123)",
              type: "code128",
              icon: Icons.onetwothree,
              iconColor: Colors.blue[700]!,
              bgColor: Colors.blue[50]!,
            ),
            const SizedBox(height: 16),
            _buildBarcodeCard(
              context: context,
              title: "QR Code",
              subtitle: "Hingga 1K karakter UTF-8 (contoh: Abc 123)",
              type: "qrcode",
              icon: Icons.qr_code_2,
              iconColor: Colors.teal[700]!,
              bgColor: Colors.teal[50]!,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarcodeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String type,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BarcodeForm(type: type)),
        );

        if (result == true) {
          if (!context.mounted) return;
          Navigator.pop(context, true);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: iconColor),
            ),
            const SizedBox(width: 20),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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
