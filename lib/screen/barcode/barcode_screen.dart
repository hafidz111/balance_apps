import 'package:balance/screen/barcode/choose_barcode_screen.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';

import '../../data/model/barcode_data.dart';
import '../../service/shared_preferences_service.dart';
import '../scanner/scanner_screen.dart';
import '../widgets/custom_snack_bar.dart';
import 'barcode_detail_screen.dart';

class BarcodeScreen extends StatefulWidget {
  final Function(bool isSelecting, int count)? onSelectionChanged;
  final Function(
    VoidCallback delete,
    VoidCallback selectAll,
    VoidCallback exit,
  )?
  onRegisterActions;

  const BarcodeScreen({
    super.key,
    this.onSelectionChanged,
    this.onRegisterActions,
  });

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  bool isOpened = false;
  Set<int> selectedIndexes = {};
  bool isSelectionMode = false;

  void _updateSelectionState() {
    widget.onSelectionChanged?.call(isSelectionMode, selectedIndexes.length);
  }

  void _onLongPressItem(int index) {
    setState(() {
      isSelectionMode = true;
      selectedIndexes.add(index);
    });
    _updateSelectionState();
  }

  void _onTapItem(int index) {
    if (isSelectionMode) {
      setState(() {
        if (selectedIndexes.contains(index)) {
          selectedIndexes.remove(index);
          if (selectedIndexes.isEmpty) isSelectionMode = false;
        } else {
          selectedIndexes.add(index);
        }
      });
      _updateSelectionState();
    } else {
      _openDetail(filteredBarcodes[index]);
    }
  }

  void _openDetail(BarcodeData b) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BarcodeDetailScreen(barcode: b)),
    );
    if (result == true) load();
  }

  void _toggleMenu() {
    setState(() => isOpened = !isOpened);
  }

  List<BarcodeData> barcodes = [];
  final TextEditingController _searchController = TextEditingController();
  List<BarcodeData> filteredBarcodes = [];

  @override
  void initState() {
    super.initState();
    load();

    widget.onRegisterActions?.call(
      _deleteSelected,
      _selectAll,
      _exitSelectionMode,
    );
  }

  void _exitSelectionMode() {
    setState(() {
      isSelectionMode = false;
      selectedIndexes.clear();
    });
    _updateSelectionState();
  }

  void load() async {
    barcodes = await SharedPreferencesService().getBarcodes();
    filteredBarcodes = List.from(barcodes);
    if (mounted) setState(() {});
  }

  void _filterBarcodes(String query) {
    final lowerQuery = query.toLowerCase();

    setState(() {
      filteredBarcodes = barcodes.where((b) {
        final codeMatch = b.code.toLowerCase().contains(lowerQuery);
        final descMatch = b.description.toLowerCase().contains(lowerQuery);
        return codeMatch || descMatch;
      }).toList();
    });

    FirebaseAnalytics.instance.logEvent(
      name: "barcode_search",
      parameters: {"query_length": query.length},
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _deleteSelected() async {
    final selectedItems = selectedIndexes
        .map((i) => filteredBarcodes[i])
        .toList();

    barcodes.removeWhere((b) => selectedItems.contains(b));

    await SharedPreferencesService().saveBarcodes(barcodes);

    setState(() {
      isSelectionMode = false;
      selectedIndexes.clear();
      filteredBarcodes = barcodes;
    });

    _updateSelectionState();

    CustomSnackBar.show(
      context,
      message: "${selectedItems.length} barcode dihapus",
      type: SnackType.success,
    );
  }

  void _selectAll() {
    setState(() {
      selectedIndexes = List.generate(
        filteredBarcodes.length,
        (i) => i,
      ).toSet();
    });
    _updateSelectionState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _filterBarcodes,
                decoration: InputDecoration(
                  hintText: "Cari nama atau kode barcode...",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            _filterBarcodes("");
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: barcodes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 100,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Belum ada barcode tersimpan",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : filteredBarcodes.isEmpty
                  ? const Center(
                      child: Text(
                        "Tidak ada hasil ditemukan",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredBarcodes.length,

                      itemBuilder: (context, i) {
                        final b = filteredBarcodes[i];

                        return GestureDetector(
                          onLongPress: () => _onLongPressItem(i),
                          onTap: () => _onTapItem(i),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                if (isSelectionMode)
                                  Checkbox(
                                    value: selectedIndexes.contains(i),
                                    onChanged: (_) => _onTapItem(i),
                                  ),
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: b.type == 'qrcode'
                                        ? Colors.teal[50]
                                        : Colors.blue[50],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    b.type == 'qrcode'
                                        ? Icons.qr_code_2
                                        : Icons.onetwothree,
                                    size: 28,
                                    color: b.type == 'qrcode'
                                        ? Colors.teal[700]
                                        : Colors.blue[700],
                                  ),
                                ),
                                const SizedBox(width: 20),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        b.code,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      (b.description.trim().isEmpty)
                                          ? const SizedBox.shrink()
                                          : Text(
                                              b.description,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                    ],
                                  ),
                                ),

                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey[400],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildExpandableFabMenu(),
    );
  }

  Widget _buildExpandableFabMenu() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildAnimatedChild(
          visible: isOpened,
          child: _buildActionButton(
            icon: Icons.qr_code_scanner,
            label: "Scan Barcode",
            color: const Color(0xFF2196F3),
            onPressed: () async {
              _toggleMenu();
              FirebaseAnalytics.instance.logEvent(name: "barcode_scan_opened");
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ScannerScreen()),
              );

              if (result != null) {
                if (!mounted) return;
                CustomSnackBar.show(
                  context,
                  message: "Barcode: $result",
                  type: SnackType.success,
                );
              }
            },
          ),
        ),
        const SizedBox(height: 12),

        _buildAnimatedChild(
          visible: isOpened,
          child: _buildActionButton(
            icon: Icons.add_circle_outline,
            label: "Tambah Barcode",
            color: const Color(0xFF009688),
            onPressed: () async {
              _toggleMenu();
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChooseBarcodeScreen()),
              );

              if (result != null) load();
            },
          ),
        ),
        const SizedBox(height: 12),

        FloatingActionButton(
          onPressed: _toggleMenu,

          backgroundColor: isOpened
              ? Colors.redAccent
              : const Color(0xFF37474F),
          elevation: 4,
          child: AnimatedRotation(
            duration: const Duration(milliseconds: 300),
            turns: isOpened ? 0.125 : 0,
            child: const Icon(Icons.add, color: Colors.white, size: 30),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedChild({required bool visible, required Widget child}) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: visible ? 1.0 : 0.0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 250),
        scale: visible ? 1.0 : 0.0,
        curve: Curves.easeOutBack,
        child: visible ? child : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
    );
  }
}
