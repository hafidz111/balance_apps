import 'package:flutter/material.dart';

import '../scanner/scanner_screen.dart';

class BarcodeScreen extends StatefulWidget {
  const BarcodeScreen({super.key});

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  bool isOpened = false;

  void _toggleMenu() {
    setState(() => isOpened = !isOpened);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner_rounded,
              size: 100,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              "Belum ada barcode tersimpan",
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildExpandableFabMenu(),
    );
  }

  Widget _buildExpandableFabMenu() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildAnimatedChild(
          visible: isOpened,
          child: _buildActionButton(
            icon: Icons.qr_code_scanner,
            label: "Scan Barcode",
            color: const Color(0xFF2196F3),
            onPressed: () async {
              _toggleMenu();
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ScannerScreen()),
              );

              if (result != null) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Barcode: $result")));
              }
            },
          ),
        ),
        const SizedBox(height: 12),

        _buildAnimatedChild(
          visible: isOpened,
          child: _buildActionButton(
            icon: Icons.add_circle_outline,
            label: "Tambah Barcode",
            color: const Color(0xFF009688),
            onPressed: () {},
          ),
        ),
        const SizedBox(height: 12),

        FloatingActionButton(
          onPressed: _toggleMenu,

          backgroundColor: isOpened
              ? Colors.redAccent
              : const Color(0xFF37474F),
          elevation: 4,
          child: AnimatedRotation(
            duration: const Duration(milliseconds: 300),
            turns: isOpened ? 0.125 : 0,
            child: const Icon(Icons.add, color: Colors.white, size: 30),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedChild({required bool visible, required Widget child}) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: visible ? 1.0 : 0.0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 250),
        scale: visible ? 1.0 : 0.0,
        curve: Curves.easeOutBack,
        child: visible ? child : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
    );
  }
}
