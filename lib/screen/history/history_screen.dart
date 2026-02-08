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

        bool monthMatch = (thisMonth == 0) ? true : (month == thisMonth);

        return year == thisYear && monthMatch;
      }).toList()..sort((a, b) => a.tgl.compareTo(b.tgl));

      sbHistory = sb.where((e) {
        final year = e.tgl ~/ 10000;
        final month = (e.tgl % 10000) ~/ 100;

        bool monthMatch = (thisMonth == 0) ? true : (month == thisMonth);

        return year == thisYear && monthMatch;
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
                    onPressed: () => _showManualInputDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text("Tambah Data Manual"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF009688),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: IconButton(
                    onPressed: () async {
                      final picked = await showMonthYearPicker(
                        context,
                        selectedMonthYear,
                      );
                      if (picked != null) {
                        setState(() => selectedMonthYear = picked);
                        _loadHistory();
                      }
                    },
                    icon: const Icon(
                      Icons.calendar_month,
                      color: Color(0xFF009688),
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

  Future<DateTime?> showMonthYearPicker(
    BuildContext context,
    DateTime initialDate,
  ) {
    return showDialog<DateTime>(
      context: context,
      builder: (context) {
        int selectedYear = initialDate.year;
        int selectedMonth = initialDate.month;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final months = [
              "Semua",
              "Jan",
              "Feb",
              "Mar",
              "Apr",
              "Mei",
              "Jun",
              "Jul",
              "Agu",
              "Sep",
              "Okt",
              "Nov",
              "Des",
            ];

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              color: Color(0xFF009688),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Filter Periode",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Pilih Tahun",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildNavButton(
                          icon: Icons.chevron_left,
                          onTap: () => setDialogState(() => selectedYear--),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onHorizontalDragEnd: (details) {
                              if (details.primaryVelocity! > 0) {
                                setDialogState(() => selectedYear--);
                              } else if (details.primaryVelocity! < 0) {
                                setDialogState(() => selectedYear++);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "$selectedYear",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildNavButton(
                          icon: Icons.chevron_right,
                          onTap: () => setDialogState(() => selectedYear++),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Pilih Bulan",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 2.2,
                          ),
                      itemCount: 13,
                      itemBuilder: (context, index) {
                        bool isSelected = selectedMonth == index;
                        return InkWell(
                          onTap: () =>
                              setDialogState(() => selectedMonth = index),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF009688)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              months[index],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Filter aktif:",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          Text(
                            selectedMonth == 0
                                ? "Tahun $selectedYear (Semua Bulan)"
                                : "${["", "Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember"][selectedMonth]} $selectedYear",
                            style: const TextStyle(
                              color: Color(0xFF00695C),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(
                            context,
                            DateTime(selectedYear, selectedMonth),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF009688),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          "Terapkan Filter",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 24, color: const Color(0xFF009688)),
      ),
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
