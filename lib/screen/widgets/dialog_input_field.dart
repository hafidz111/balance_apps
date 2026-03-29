import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starvy/theme/app_colors.dart';

class DialogInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final String? hintText;

  const DialogInputField({
    super.key,
    required this.label,
    required this.controller,
    this.readOnly = false,
    this.onTap,
    this.inputFormatters,
    this.prefixIcon,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            readOnly: readOnly,
            onTap: onTap,
            keyboardType: TextInputType.number,
            inputFormatters: inputFormatters,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              isDense: true,
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, size: 22, color: AppColors.primary)
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.9),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              contentPadding: EdgeInsets.fromLTRB(
                prefixIcon != null ? 4 : 16,
                14,
                16,
                14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
