import 'package:balance/screen/widgets/summary_row.dart';
import 'package:flutter/material.dart';

class SummarySection extends StatelessWidget {
  final List<SummaryRow> rows;
  final String title;

  const SummarySection({super.key, required this.rows, this.title = "TOTAL"});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF009688),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white54),
          ...rows,
        ],
      ),
    );
  }
}
