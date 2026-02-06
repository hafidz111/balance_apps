import 'package:flutter/material.dart';

import '../../data/model/say_bread_history.dart';
import '../../service/shared_preferences_service.dart';
import 'dialog_input_field.dart';

class SayBreadDialog extends StatefulWidget {
  final SayBreadHistory? editData;

  const SayBreadDialog({super.key, this.editData});

  @override
  State<SayBreadDialog> createState() => _SayBreadDialogState();
}

class _SayBreadDialogState extends State<SayBreadDialog> {
  final tglCtrl = TextEditingController();
  final salesCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();

  final _service = SharedPreferencesService();
  DateTime? selectedDate;

  int _toYmd(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );

    if (date != null) {
      selectedDate = date;
      tglCtrl.text =
          "${date.day.toString().padLeft(2, '0')}-"
          "${date.month.toString().padLeft(2, '0')}-"
          "${date.year}";
    }
  }

  Future<void> _save() async {
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tanggal belum dipilih"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (salesCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Total Sales wajib diisi"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final sales = int.tryParse(salesCtrl.text);
    if (sales == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sales harus berupa angka"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (qtyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Qty wajib diisi"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final qty = int.tryParse(qtyCtrl.text);
    if (qty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Qty harus berupa angka"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final tgl = _toYmd(selectedDate!);

    final data = SayBreadHistory(
      tgl: tgl,
      sales: sales,
      qty: qty,
      akmQty: 0,
      akmSales: 0,
      average: 0,
    );

    await _service.saveSayBread(data);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Data berhasil disimpan"),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context, true);
  }

  @override
  void initState() {
    super.initState();

    if (widget.editData != null) {
      final d = widget.editData!;
      selectedDate = DateTime(
        d.tgl ~/ 10000,
        (d.tgl % 10000) ~/ 100,
        d.tgl % 100,
      );

      tglCtrl.text =
          "${selectedDate!.day.toString().padLeft(2, '0')}-"
          "${selectedDate!.month.toString().padLeft(2, '0')}-"
          "${selectedDate!.year}";

      salesCtrl.text = d.sales.toString();
      qtyCtrl.text = d.qty.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.center,
            child: Text(
              widget.editData == null
                  ? "Tambah Data Say Bread"
                  : "Edit Data Say Bread",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DialogInputField(
                label: "Tanggal",
                controller: tglCtrl,
                readOnly: true,
                onTap: _pickDate,
              ),
              DialogInputField(label: "Total Sales", controller: salesCtrl),
              DialogInputField(label: "Qty", controller: qtyCtrl),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009688),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "Simpan",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
