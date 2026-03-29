import 'package:flutter/material.dart';

import '../../../data/model/say_bread_history.dart';
import '../../../service/shared_preferences_service.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/number_format.dart';
import '../../widgets/custom_snack_bar.dart';
import '../../widgets/dialog_input_field.dart';

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
      CustomSnackBar.show(
        context,
        message: "Tanggal belum dipilih",
        type: SnackType.error,
      );
      return;
    }

    if (salesCtrl.text.trim().isEmpty) {
      CustomSnackBar.show(
        context,
        message: "Total Sales wajib diisi",
        type: SnackType.error,
      );
      return;
    }

    final sales = int.tryParse(salesCtrl.text.replaceAll('.', ''));
    if (sales == null) {
      CustomSnackBar.show(
        context,
        message: "Sales harus berupa angka",
        type: SnackType.error,
      );
      return;
    }

    if (qtyCtrl.text.trim().isEmpty) {
      CustomSnackBar.show(
        context,
        message: "Qty wajib diisi",
        type: SnackType.error,
      );
      return;
    }

    final qty = int.tryParse(qtyCtrl.text.replaceAll('.', ''));
    if (qty == null) {
      CustomSnackBar.show(
        context,
        message: "Qty harus berupa angka",
        type: SnackType.error,
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
    CustomSnackBar.show(
      context,
      message: "Data berhasil disimpan",
      type: SnackType.success,
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

      salesCtrl.text = formatRupiah(d.sales.toString());
      qtyCtrl.text = formatRupiah(d.qty.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = widget.editData == null
        ? "Tambah Data Bread"
        : "Edit Data Bread";

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      backgroundColor: scheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.18),
                    AppColors.primary.withValues(alpha: 0.06),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 8, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.bakery_dining_rounded,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 22,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DialogInputField(
                    label: "Tanggal",
                    controller: tglCtrl,
                    readOnly: true,
                    onTap: _pickDate,
                    prefixIcon: Icons.calendar_today_rounded,
                    hintText: "Ketuk untuk pilih tanggal",
                  ),
                  DialogInputField(
                    label: "Total Sales",
                    controller: salesCtrl,
                    inputFormatters: [RupiahInputFormatter()],
                    prefixIcon: Icons.payments_rounded,
                    hintText: "Masukkan total sales",
                  ),
                  DialogInputField(
                    label: "Qty",
                    controller: qtyCtrl,
                    inputFormatters: [RupiahInputFormatter()],
                    prefixIcon: Icons.numbers_rounded,
                    hintText: "Masukkan kuantitas roti",
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded, size: 22),
                    label: const Text(
                      'Simpan',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
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
