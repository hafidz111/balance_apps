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

  bool get isEdit => barcode != null;

  BarcodeFormProvider({required this.type, this.barcode, this.initialCode}) {
    if (isEdit) {
      codeC.text = barcode!.code;
      descC.text = barcode!.description;
    } else if (initialCode != null) {
      codeC.text = initialCode!;
    }
  }

  Future<BarcodeData?> save(void Function(String) showError) async {
    final newData = BarcodeData(
      id: isEdit ? barcode!.id : UniqueKey().toString(),
      type: type,
      code: codeC.text,
      description: descC.text,
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
    super.dispose();
  }
}
