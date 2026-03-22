import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool enabled;
  final String? hintText;
  final List<TextInputFormatter>? inputFormatters;

  const CustomInputField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.hintText,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: enabled
                ? colorScheme.onSurface.withOpacity(0.9)
                : colorScheme.onSurface.withOpacity(0.45),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: enabled,
          inputFormatters: inputFormatters,
          cursorColor: colorScheme.primary,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.45),
            ),
            isDense: false,
            filled: true,
            fillColor: enabled
                ? colorScheme.surfaceVariant.withOpacity(0.35)
                : colorScheme.surfaceVariant.withOpacity(0.2),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: baseBorder,
            enabledBorder: baseBorder,
            disabledBorder: baseBorder.copyWith(
              borderSide: BorderSide(
                color: colorScheme.outline.withOpacity(0.2),
              ),
            ),
            focusedBorder: baseBorder.copyWith(
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: enabled
                ? colorScheme.onSurface
                : colorScheme.onSurface.withOpacity(0.55),
          ),
        ),
      ],
    );
  }
}
