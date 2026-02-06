import 'package:flutter/material.dart';

import '../../data/model/point_coffe_history.dart';
import '../../service/shared_preferences_service.dart';
import 'dialog_input_field.dart';

class PointCoffeeDialog extends StatefulWidget {
  final PointCoffeeHistory? editData;

  const PointCoffeeDialog({super.key, this.editData});

  @override
  State<PointCoffeeDialog> createState() => _PointCoffeeDialogState();
}

class _PointCoffeeDialogState extends State<PointCoffeeDialog> {
  final tglCtrl = TextEditingController();
  final spdCtrl = TextEditingController();
  final cupCtrl = TextEditingController();

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Tanggal belum dipilih")));
      return;
    }

    if (spdCtrl.text.trim().isEmpty || cupCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("SPD dan CUP wajib diisi")));
      return;
    }

    final spd = int.tryParse(spdCtrl.text);
    final cup = int.tryParse(cupCtrl.text);

    if (spd == null || cup == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("SPD dan CUP harus angka")));
      return;
    }

    final tgl = _toYmd(selectedDate!);

    final data = PointCoffeeHistory(
      tgl: tgl,
      spd: spd,
      cup: cup,
      akmCup: 0,
      cpd: 0,
    );

    await SharedPreferencesService().savePointCoffee(data);
    if (!mounted) return;
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

      spdCtrl.text = d.spd.toString();
      cupCtrl.text = d.cup.toString();
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
                  ? "Tambah Data Point Coffee"
                  : "Edit Data Point Coffee",
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
              DialogInputField(label: "SPD", controller: spdCtrl),
              DialogInputField(label: "CUP", controller: cupCtrl),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009688),
                    foregroundColor: Colors.white,
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
