import 'package:balance/utils/date_format.dart';
import 'package:flutter/material.dart';

import 'custom_text_field.dart';

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
  bool _isChanged = false;

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

    if (changed != _isChanged) {
      setState(() => _isChanged = changed);
    }
  }

  @override
  void dispose() {
    for (final controller in _initialValues.keys) {
      controller.removeListener(_checkChanges);
    }
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

      _isChanged = false;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Semua field harus diisi sebelum menyimpan!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    widget.onSave();

    for (final e in _initialValues.entries) {
      _initialValues[e.key] = e.key.text;
    }

    setState(() => _isChanged = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldWrapper(context, "Title Report", widget.titleController),
            _buildFieldWrapper(context, "Store Name", widget.namaController),
            _buildFieldWrapper(context, "Store Code", widget.kodeController),
            _buildFieldWrapper(context, "GO Date", widget.tglController),
            _buildFieldWrapper(context, "Store Area", widget.areaController),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: _isChanged ? _onSavePressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009688),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Simpan Data",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
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
    TextEditingController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: label == "GO Date"
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
                absorbing: label == "GO Date",
                child: CustomInputField(label: label, controller: controller),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
