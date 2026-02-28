import 'package:flutter/material.dart';

import '../../utils/number_format.dart';

class SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isCurrency;

  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.isCurrency = true,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = isCurrency ? formatRupiah(value) : value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          Text(
            displayValue,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
