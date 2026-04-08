import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShiftTimeFourFieldsRow extends StatefulWidget {
  const ShiftTimeFourFieldsRow({
    super.key,
    required this.label,
    required this.controllers,
    required this.enabled,
  });

  final String label;
  final List<TextEditingController> controllers;
  final bool enabled;

  @override
  State<ShiftTimeFourFieldsRow> createState() => _ShiftTimeFourFieldsRowState();
}

class _ShiftTimeFourFieldsRowState extends State<ShiftTimeFourFieldsRow> {
  late List<FocusNode> _focusNodes;

  static final List<TextInputFormatter> _twoDigits = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(2),
  ];

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(4, (_) => FocusNode());

    for (int i = 0; i < 4; i++) {
      widget.controllers[i].addListener(() {
        if (widget.controllers[i].text.length == 2 && i < 3) {
          if (_focusNodes[i].hasFocus) {
            FocusScope.of(context).requestFocus(_focusNodes[i + 1]);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sepStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      color: scheme.primary.withValues(alpha: 0.6),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.access_time_filled_rounded,
                size: 18,
                color: widget.enabled
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: widget.enabled
                      ? scheme.onSurface
                      : scheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildTimeGroup(0, 1, sepStyle, scheme),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('—', style: sepStyle),
              ),
              _buildTimeGroup(2, 3, sepStyle, scheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeGroup(
    int hIndex,
    int mIndex,
    TextStyle? sepStyle,
    ColorScheme scheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _field(hIndex, scheme),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(':', style: sepStyle),
          ),
          _field(mIndex, scheme),
        ],
      ),
    );
  }

  Widget _field(int index, ColorScheme scheme) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.transparent),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: scheme.primary, width: 2),
    );

    return SizedBox(
      width: 48,
      height: 52,
      child: TextField(
        controller: widget.controllers[index],
        focusNode: _focusNodes[index],
        enabled: widget.enabled,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: _twoDigits,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: widget.enabled
              ? scheme.onSurface
              : scheme.onSurface.withValues(alpha: 0.5),
        ),
        decoration: InputDecoration(
          counterText: '',
          isDense: true,
          filled: true,
          fillColor: widget.enabled
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.6)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.2),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: border,
          enabledBorder: border,
          disabledBorder: border,
          focusedBorder: focusedBorder,
        ),
      ),
    );
  }
}
