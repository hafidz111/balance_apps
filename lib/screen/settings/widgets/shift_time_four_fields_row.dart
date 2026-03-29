import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShiftTimeFourFieldsRow extends StatelessWidget {
  ShiftTimeFourFieldsRow({
    super.key,
    required this.label,
    required this.controllers,
    required this.enabled,
  }) : assert(controllers.length == 4);

  final String label;
  final List<TextEditingController> controllers;
  final bool enabled;

  static final List<TextInputFormatter> _twoDigits = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(2),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sepStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: scheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: enabled
                ? scheme.onSurface.withValues(alpha: 0.9)
                : scheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _field(context, controllers[0], scheme),
            Text(' : ', style: sepStyle),
            _field(context, controllers[1], scheme),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(' - ', style: sepStyle),
            ),
            _field(context, controllers[2], scheme),
            Text(' : ', style: sepStyle),
            _field(context, controllers[3], scheme),
          ],
        ),
      ],
    );
  }

  Widget _field(
    BuildContext context,
    TextEditingController c,
    ColorScheme scheme,
  ) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
    );
    return SizedBox(
      width: 52,
      child: TextField(
        controller: c,
        enabled: enabled,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: _twoDigits,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          counterText: '',
          isDense: true,
          filled: true,
          fillColor: enabled
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.2),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 12,
          ),
          border: border,
          enabledBorder: border,
          disabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: scheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}
