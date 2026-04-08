import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/model/barcode_data.dart';
import '../../../providers/barcode_form_provider.dart';
import '../../widgets/custom_snack_bar.dart';

class BarcodeForm extends StatelessWidget {
  final String type;
  final BarcodeData? barcode;
  final String? initialCode;

  const BarcodeForm({
    super.key,
    required this.type,
    this.barcode,
    this.initialCode,
  });

  Future<void> _handleSave(
    BuildContext context,
    BarcodeFormProvider provider,
  ) async {
    final newData = await provider.save((message) {
      if (!context.mounted) return;
      CustomSnackBar.show(context, message: message, type: SnackType.error);
    });

    if (newData != null && context.mounted) {
      FirebaseAnalytics.instance.logEvent(
        name: "barcode_created",
        parameters: {"type": type},
      );
      Navigator.pop(context, newData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BarcodeFormProvider(
        type: type,
        barcode: barcode,
        initialCode: initialCode,
      ),
      child: Builder(
        builder: (context) {
          final provider = Provider.of<BarcodeFormProvider>(context);
          final String displayType = type == 'qrcode' ? 'QR Code' : 'Code 128';
          final Color primaryTeal = const Color(0xFF009688);

          return Scaffold(
            backgroundColor: Colors.grey[100],
            appBar: AppBar(
              backgroundColor: primaryTeal,
              title: Text(
                "${provider.isEdit ? 'Edit' : 'Buat'} $type",
                style: const TextStyle(color: Colors.white),
              ),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            type == 'qrcode'
                                ? Icons.qr_code_2
                                : Icons.onetwothree,
                            color: primaryTeal,
                          ),
                          const SizedBox(width: 8),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.black,
                              ),
                              children: [
                                const TextSpan(text: "Format: "),
                                TextSpan(
                                  text: displayType,
                                  style: TextStyle(
                                    color: primaryTeal,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        "Kode *",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: provider.codeC,
                        decoration: InputDecoration(
                          hintText: "Masukkan kode barcode",
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Deskripsi",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: provider.descC,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: "Deskripsi barcode (opsional)",
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => _handleSave(context, provider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryTeal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            provider.isEdit
                                ? "Update Barcode"
                                : "Simpan Barcode",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
