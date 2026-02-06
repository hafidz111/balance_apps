import 'package:flutter/material.dart';

import '../../data/model/point_coffe_history.dart';
import '../../data/model/say_bread_history.dart';
import '../../service/shared_preferences_service.dart';
import '../../utils/date_format.dart';
import '../../utils/number_format.dart';
import '../widgets/point_coffe_dialog.dart';
import '../widgets/say_bread_dialog.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int activeTab = 0;

  final _prefsService = SharedPreferencesService();

  List<PointCoffeeHistory> pcHistory = [];
  List<SayBreadHistory> sbHistory = [];
  DateTime selectedMonthYear = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final pc = await _prefsService.getPointCoffee();
    final sb = await _prefsService.getSayBread();

    final thisMonth = selectedMonthYear.month;
    final thisYear = selectedMonthYear.year;

    setState(() {
      pcHistory = pc.where((e) {
        final year = e.tgl ~/ 10000;
        final month = (e.tgl % 10000) ~/ 100;
        return year == thisYear && month == thisMonth;
      }).toList()..sort((a, b) => a.tgl.compareTo(b.tgl));

      sbHistory = sb.where((e) {
        final year = e.tgl ~/ 10000;
        final month = (e.tgl % 10000) ~/ 100;
        return year == thisYear && month == thisMonth;
      }).toList()..sort((a, b) => a.tgl.compareTo(b.tgl));
    });
  }

  Future<void> _deletePointCoffee(PointCoffeeHistory data) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Hapus Data"),
        content: const Text("Yakin ingin menghapus history ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _prefsService.deletePointCoffee(data.tgl);
      _loadHistory();
    }
  }

  Future<void> _deleteSayBread(SayBreadHistory data) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Hapus Data"),
        content: const Text("Yakin ingin menghapus history ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _prefsService.deleteSayBread(data.tgl);
      _loadHistory();
    }
  }

  Future<void> _editPointCoffee(PointCoffeeHistory data) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => PointCoffeeDialog(editData: data),
    );

    if (result == true) {
      _loadHistory();
    }
  }

  Future<void> _editSayBread(SayBreadHistory data) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => SayBreadDialog(editData: data),
    );

    if (result == true) {
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _buildTabItem("Point Coffee", 0),
                  _buildTabItem("Say Bread", 1),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await pickMonthYear(
                        context,
                        initialDate: selectedMonthYear,
                      );
                      if (picked != null) {
                        setState(() {
                          selectedMonthYear = picked;
                        });
                        _loadHistory();
                      }
                    },
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      "Bulan: ${["Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember"][selectedMonthYear.month - 1]} ${selectedMonthYear.year}",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF009688),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showManualInputDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text("Tambah Data Manual"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009688),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: activeTab == 0
                  ? _buildPointCoffeeHistory()
                  : _buildSayBreadHistory(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(String title, int index) {
    bool isActive = activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => activeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    const BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Future<DateTime?> pickMonthYear(
    BuildContext context, {
    DateTime? initialDate,
  }) async {
    initialDate ??= DateTime.now();

    int selectedYear = initialDate.year;
    int selectedMonth = initialDate.month;

    return showDialog<DateTime>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Pilih Bulan & Tahun"),
          content: SizedBox(
            height: 150,
            child: Column(
              children: [
                DropdownButton<int>(
                  value: selectedYear,
                  onChanged: (val) {
                    if (val != null) selectedYear = val;
                    (context as Element).markNeedsBuild();
                  },
                  items: List.generate(10, (i) => DateTime.now().year - 5 + i)
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(e.toString()),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),

                DropdownButton<int>(
                  value: selectedMonth,
                  onChanged: (val) {
                    if (val != null) selectedMonth = val;
                    (context as Element).markNeedsBuild();
                  },
                  items: List.generate(12, (i) => i + 1)
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            [
                              "Januari",
                              "Februari",
                              "Maret",
                              "April",
                              "Mei",
                              "Juni",
                              "Juli",
                              "Agustus",
                              "September",
                              "Oktober",
                              "November",
                              "Desember",
                            ][e - 1],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, DateTime(selectedYear, selectedMonth)),
              child: const Text("Pilih"),
            ),
          ],
        );
      },
    );
  }

  void _showManualInputDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return activeTab == 0
            ? const PointCoffeeDialog()
            : const SayBreadDialog();
      },
    );

    if (result == true) {
      _loadHistory();
    }
  }

  Widget _buildPointCoffeeHistory() {
    if (pcHistory.isEmpty) {
      return _emptyView();
    }

    return ListView.builder(
      itemCount: pcHistory.length,
      itemBuilder: (context, index) {
        final data = pcHistory[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Tanggal: ${formatDate(data.tgl)}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editPointCoffee(data);
                        } else if (value == 'delete') {
                          _deletePointCoffee(data);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text("Edit")),
                        PopupMenuItem(value: 'delete', child: Text("Hapus")),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                _row("SPD", data.spd.toMillion()),
                _row("CUP", data.cup.toString()),
                _row("AKM CUP", data.akmCup.toString()),
                _row("CPD", data.cpd.toString()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSayBreadHistory() {
    if (sbHistory.isEmpty) {
      return _emptyView();
    }

    return ListView.builder(
      itemCount: sbHistory.length,
      itemBuilder: (context, index) {
        final data = sbHistory[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Tanggal: ${formatDate(data.tgl)}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editSayBread(data);
                        } else if (value == 'delete') {
                          _deleteSayBread(data);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text("Edit")),
                        PopupMenuItem(value: 'delete', child: Text("Hapus")),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                _row("Qty", data.qty.toString()),
                _row("AKM QTY", data.akmQty.toString()),
                _row("SPD", data.sales.toString()),
                _row("Total Sales", data.akmSales.toString()),
                _row("Average", data.average.toStringAsFixed(2)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _emptyView() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          "Belum ada data history",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      ),
    );
  }
}
