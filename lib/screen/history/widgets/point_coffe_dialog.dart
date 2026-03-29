import 'package:flutter/material.dart';

import '../../../data/model/point_coffe_history.dart';
import '../../../service/shared_preferences_service.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/number_format.dart';
import '../../widgets/custom_snack_bar.dart';
import '../../widgets/dialog_input_field.dart';

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
      CustomSnackBar.show(
        context,
        message: "Tanggal belum dipilih",
        type: SnackType.error,
      );
      return;
    }

    if (spdCtrl.text.trim().isEmpty || cupCtrl.text.trim().isEmpty) {
      CustomSnackBar.show(
        context,
        message: "SPD dan CUP wajib diisi",
        type: SnackType.error,
      );
      return;
    }

    final spd = int.tryParse(spdCtrl.text.replaceAll('.', ''));
    final cup = int.tryParse(cupCtrl.text.replaceAll('.', ''));

    if (spd == null || cup == null) {
      CustomSnackBar.show(
        context,
        message: "SPD dan CUP harus angka",
        type: SnackType.error,
      );
      return;
    }

    final tgl = _toYmd(selectedDate!);

    final data = PointCoffeeHistory(
      tgl: tgl,
      spd: spd,
      cup: cup,
      akmCup: 0,
      cpd: 0,
      apc: 0,
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

      spdCtrl.text = formatRupiah(d.spd.toString());
      cupCtrl.text = formatRupiah(d.cup.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = widget.editData == null
        ? "Tambah Data Coffee"
        : "Edit Data Coffee";

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
                        Icons.coffee_rounded,
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
                    label: "SPD",
                    controller: spdCtrl,
                    inputFormatters: [RupiahInputFormatter()],
                    prefixIcon: Icons.trending_up_rounded,
                    hintText: "Masukkan SPD",
                  ),
                  DialogInputField(
                    label: "CUP",
                    controller: cupCtrl,
                    inputFormatters: [RupiahInputFormatter()],
                    prefixIcon: Icons.local_cafe_rounded,
                    hintText: "Masukkan jumlah cup",
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
