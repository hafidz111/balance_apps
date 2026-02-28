import 'package:balance/screen/widgets/banner_ads.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../../data/model/barcode_data.dart';
import '../../service/shared_preferences_service.dart';
import '../widgets/barcode_form.dart';

class BarcodeDetailScreen extends StatefulWidget {
  final BarcodeData barcode;

  const BarcodeDetailScreen({super.key, required this.barcode});

  @override
  State<BarcodeDetailScreen> createState() => _BarcodeDetailScreenState();
}

class _BarcodeDetailScreenState extends State<BarcodeDetailScreen> {
  late BarcodeData _current;
  final Color primaryTeal = const Color(0xFF009688);

  @override
  void initState() {
    super.initState();
    _current = widget.barcode;
  }

  void _delete() async {
    final confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Hapus Barcode"),
        content: const Text("Yakin mau hapus barcode ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SharedPreferencesService().deleteBarcode(widget.barcode);
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  void _edit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeForm(type: _current.type, barcode: _current),
      ),
    );
    if (result == true) await _reload();
  }

  Future<void> _reload() async {
    final list = await SharedPreferencesService().getBarcodes();
    final updated = list.firstWhere(
      (e) => e.code == widget.barcode.code,
      orElse: () => widget.barcode,
    );
    if (!mounted) return;
    setState(() => _current = updated);
  }

  @override
  Widget build(BuildContext context) {
    final b = _current;
    final String displayType = b.type == 'qrcode' ? 'QR Code' : 'Code 128';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: primaryTeal,
        title: const Text(
          "Detail Barcode",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(onPressed: _edit, icon: const Icon(Icons.edit_outlined)),
          IconButton(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryTeal.withValues(alpha: 0.05),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          b.type == 'qrcode' ? Icons.qr_code_2 : Icons.onetwothree,
                          color: primaryTeal,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          displayType,
                          style: TextStyle(
                            color: primaryTeal,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: BarcodeWidget(
                              barcode: b.type == 'code128'
                                  ? Barcode.code128()
                                  : Barcode.qrCode(),
                              data: b.code,
                              width: double.infinity,
                              height: 100,
                              drawText: false,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        _buildInfoSection(
                          "Kode",
                          b.code,
                          icon: b.type == 'qrcode' ? Icons.qr_code : Icons.onetwothree,
                        ),
                        const SizedBox(height: 24),

                        _buildInfoSection(
                          "Deskripsi",
                          b.description.isEmpty ? "-" : b.description,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16,),
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: BannerAds(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String label, String value, {IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: Colors.black87),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
