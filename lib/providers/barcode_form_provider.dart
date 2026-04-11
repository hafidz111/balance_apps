import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';

import '../data/model/barcode_data.dart';
import '../service/shared_preferences_service.dart';

class BarcodeFormProvider extends ChangeNotifier {
  final String type;
  final BarcodeData? barcode;
  final String? initialCode;

  final codeC = TextEditingController();
  final descC = TextEditingController();
  final jumlahC = TextEditingController();

  bool get isEdit => barcode != null;

  BarcodeFormProvider({required this.type, this.barcode, this.initialCode}) {
    if (isEdit) {
      codeC.text = barcode!.code;
      descC.text = barcode!.description;
      if (barcode!.jumlah != null) {
        jumlahC.text = barcode!.jumlah.toString();
      }
    } else if (initialCode != null) {
      codeC.text = initialCode!;
    }
  }

  Future<BarcodeData?> save(void Function(String) showError) async {
    if (codeC.text.trim().isEmpty) {
      showError("Kode tidak boleh kosong");
      return null;
    }

    int? jumlah;
    final jumlahText = jumlahC.text.trim();
    if (jumlahText.isNotEmpty) {
      jumlah = int.tryParse(jumlahText);
      if (jumlah == null) {
        showError("Jumlah harus berupa angka");
        return null;
      }
    }

    final newData = BarcodeData(
      id: isEdit ? barcode!.id : UniqueKey().toString(),
      type: type,
      code: codeC.text.trim(),
      description: descC.text.trim(),
      jumlah: jumlah,
    );

    if (codeC.text.trim().isEmpty) {
      showError("Kode tidak boleh kosong");
      return null;
    }

    if (isEdit) {
      await SharedPreferencesService().updateBarcode(barcode!, newData);
    } else {
      await SharedPreferencesService().saveBarcode(newData);
    }

    FirebaseAnalytics.instance.logEvent(
      name: "barcode_created",
      parameters: {"type": type},
    );

    return newData;
  }

  @override
  void dispose() {
    codeC.dispose();
    descC.dispose();
    jumlahC.dispose();
    super.dispose();
  }
}
