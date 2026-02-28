import 'package:flutter/services.dart';

class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Hapus semua selain angka
    String clean = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (clean.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final int number = int.parse(clean);

    final formatted = _formatNumber(number);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatNumber(int number) {
    final str = number.toString();
    final buffer = StringBuffer();

    int count = 0;

    for (int i = str.length - 1; i >= 0; i--) {
      count++;
      buffer.write(str[i]);
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }

    return buffer.toString().split('').reversed.join();
  }
}

extension ShortMillion on int {
  String toMillion() {
    return (this / 1000000).toStringAsFixed(1).replaceAll('.', ',');
  }
}

String formatRupiah(String val) {
  final clean = val.replaceAll('.', '');
  final number = int.tryParse(clean);

  if (number == null) return val;

  return number.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]}.',
  );
}
