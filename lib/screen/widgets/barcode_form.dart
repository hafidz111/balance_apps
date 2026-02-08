import 'package:flutter/material.dart';

import '../../data/model/barcode_data.dart';
import '../../service/shared_preferences_service.dart';

class BarcodeForm extends StatefulWidget {
  final String type;
  final BarcodeData? barcode;
  final String? initialCode;

  const BarcodeForm({
    super.key,
    required this.type,
    this.barcode,
    this.initialCode,
  });

  @override
  State<BarcodeForm> createState() => _BarcodeFormState();
}

class _BarcodeFormState extends State<BarcodeForm> {
  final codeC = TextEditingController();
  final descC = TextEditingController();

  bool get isEdit => widget.barcode != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      codeC.text = widget.barcode!.code;
      descC.text = widget.barcode!.description;
    } else if (widget.initialCode != null) {
      codeC.text = widget.initialCode!;
    }
  }

  void save() async {
    final newData = BarcodeData(
      type: widget.type,
      code: codeC.text,
      description: descC.text,
    );

    if (codeC.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Kode tidak boleh kosong")));
      return;
    }

    if (isEdit) {
      await SharedPreferencesService().updateBarcode(widget.barcode!, newData);
    } else {
      await SharedPreferencesService().saveBarcode(newData);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final String displayType = widget.type == 'qrcode' ? 'QR Code' : 'Code 128';
    final Color primaryTeal = const Color(0xFF009688);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: primaryTeal,
        title: Text(
          "${isEdit ? 'Edit' : 'Buat'} ${widget.type}",
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    widget.type == 'qrcode'
                        ? Icons.qr_code_2
                        : Icons.onetwothree,
                    color: primaryTeal,
                  ),
                  const SizedBox(width: 8),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 18, color: Colors.black),
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
              const SizedBox(height: 24),

              const Text(
                "Kode *",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: codeC,
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
                controller: descC,
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
                  onPressed: save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isEdit ? "Update Barcode" : "Simpan Barcode",
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
    );
  }
}
