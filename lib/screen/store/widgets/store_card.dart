import 'package:flutter/material.dart';
import 'package:starvy/screen/widgets/custom_snack_bar.dart';
import 'package:starvy/theme/app_colors.dart';
import 'package:starvy/utils/date_format.dart';

import '../../widgets/custom_text_field.dart';

class StoreCard extends StatefulWidget {
  final TextEditingController titleController;
  final TextEditingController namaController;
  final TextEditingController kodeController;
  final TextEditingController tglController;
  final TextEditingController areaController;
  final VoidCallback onSave;

  const StoreCard({
    super.key,
    required this.titleController,
    required this.namaController,
    required this.kodeController,
    required this.tglController,
    required this.areaController,
    required this.onSave,
  });

  @override
  State<StoreCard> createState() => _StoreCardState();
}

class _StoreCardState extends State<StoreCard> {
  late Map<TextEditingController, String> _initialValues;
  final ValueNotifier<bool> _isChanged = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();

    _initialValues = {
      widget.titleController: widget.titleController.text,
      widget.namaController: widget.namaController.text,
      widget.kodeController: widget.kodeController.text,
      widget.tglController: widget.tglController.text,
      widget.areaController: widget.areaController.text,
    };

    for (final controller in _initialValues.keys) {
      controller.addListener(_checkChanges);
    }
  }

  void _checkChanges() {
    final changed = _initialValues.entries.any((e) => e.key.text != e.value);
    if (changed != _isChanged.value) {
      _isChanged.value = changed;
    }
  }

  @override
  void dispose() {
    for (final controller in _initialValues.keys) {
      controller.removeListener(_checkChanges);
    }
    _isChanged.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StoreCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final wasEmpty = _initialValues.values.every((v) => v.isEmpty);
    final nowHasData = [
      widget.titleController,
      widget.namaController,
      widget.kodeController,
      widget.tglController,
      widget.areaController,
    ].any((c) => c.text.isNotEmpty);

    if (wasEmpty && nowHasData) {
      _initialValues = {
        widget.titleController: widget.titleController.text,
        widget.namaController: widget.namaController.text,
        widget.kodeController: widget.kodeController.text,
        widget.tglController: widget.tglController.text,
        widget.areaController: widget.areaController.text,
      };

      _isChanged.value = false;
    }
  }

  void _onSavePressed() {
    final fields = [
      widget.titleController,
      widget.namaController,
      widget.kodeController,
      widget.tglController,
      widget.areaController,
    ];

    if (fields.any((c) => c.text.trim().isEmpty)) {
      CustomSnackBar.show(
        context,
        message: "Semua field harus diisi sebelum menyimpan!",
        type: SnackType.error,
      );
      return;
    }

    widget.onSave();

    for (final e in _initialValues.entries) {
      _initialValues[e.key] = e.key.text;
    }

    _isChanged.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: scheme.surface,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.22),
                    AppColors.primary.withValues(alpha: 0.06),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.14),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Data toko',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.35,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Lengkapi informasi outlet untuk laporan',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _isChanged,
                    builder: (context, isChanged, _) {
                      if (!isChanged) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(
                              alpha: 0.85,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_note_rounded,
                                  size: 22,
                                  color: AppColors.primaryDark,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Ada perubahan yang belum disimpan',
                                    style: textTheme.labelLarge?.copyWith(
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  _buildFieldWrapper(
                    context,
                    'Title Report',
                    widget.titleController,
                    prefixIcon: Icons.article_rounded,
                    hintText: 'Masukkan judul laporan',
                  ),
                  _buildFieldWrapper(
                    context,
                    'Store Name',
                    widget.namaController,
                    prefixIcon: Icons.badge_rounded,
                    hintText: 'Masukkan nama outlet atau toko',
                  ),
                  _buildFieldWrapper(
                    context,
                    'Store Code',
                    widget.kodeController,
                    prefixIcon: Icons.tag_rounded,
                    hintText: 'Masukkan kode outlet atau toko',
                  ),
                  _buildFieldWrapper(
                    context,
                    'GO Date',
                    widget.tglController,
                    prefixIcon: Icons.calendar_month_rounded,
                    hintText: 'Ketuk untuk pilih tanggal GO',
                  ),
                  _buildFieldWrapper(
                    context,
                    'Store Area',
                    widget.areaController,
                    prefixIcon: Icons.map_outlined,
                    hintText: 'Wilayah atau area cakupan store',
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<bool>(
                    valueListenable: _isChanged,
                    builder: (context, isChanged, _) {
                      return FilledButton.icon(
                        onPressed: isChanged ? _onSavePressed : null,
                        icon: const Icon(Icons.check_rounded, size: 22),
                        label: const Text(
                          'Simpan data',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          disabledBackgroundColor:
                              scheme.surfaceContainerHighest,
                          disabledForegroundColor: scheme.onSurface.withValues(
                            alpha: 0.38,
                          ),
                          minimumSize: const Size(double.infinity, 52),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldWrapper(
    BuildContext context,
    String label,
    TextEditingController controller, {
    IconData? prefixIcon,
    IconData? suffixIcon,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: label == 'GO Date'
                  ? () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );

                      if (picked != null) {
                        controller.text = formatDateCaps(picked);
                      }
                    }
                  : null,
              child: AbsorbPointer(
                absorbing: label == 'GO Date',
                child: CustomInputField(
                  label: label,
                  controller: controller,
                  prefixIcon: prefixIcon,
                  suffixIcon: suffixIcon,
                  hintText: hintText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
