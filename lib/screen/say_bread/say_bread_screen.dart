import 'package:balance/service/shared_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/model/say_bread_history.dart';
import '../../utils/date_format.dart';
import '../widgets/action_buttons.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/shift_card.dart';
import '../widgets/summary_row.dart';
import '../widgets/summary_section.dart';

class SayBreadScreen extends StatefulWidget {
  const SayBreadScreen({super.key});

  @override
  State<SayBreadScreen> createState() => _SayBreadScreenState();
}

class _SayBreadScreenState extends State<SayBreadScreen> {
  final s1Sales = TextEditingController();
  final s1Qty = TextEditingController();
  final s2Sales = TextEditingController();
  final s2Qty = TextEditingController();
  final akmLastMonth = TextEditingController();

  @override
  void initState() {
    super.initState();

    s1Sales.addListener(_updateSummary);
    s1Qty.addListener(_updateSummary);
    s2Sales.addListener(_updateSummary);
    s2Qty.addListener(_updateSummary);
    akmLastMonth.addListener(_updateSummary);
  }

  int _toInt(TextEditingController c) => int.tryParse(c.text) ?? 0;

  int get totalSales => _toInt(s1Sales) + _toInt(s2Sales);

  int get totalQty => _toInt(s1Qty) + _toInt(s2Qty);

  String _rupiah(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  Future<String> _buildMonthlyHistory() async {
    final service = SharedPreferencesService();
    final history = await service.getSayBread();

    final now = DateTime.now();
    final thisMonth = now.year * 100 + now.month;

    final filtered = history.where((e) {
      final ym = e.tgl ~/ 100;
      return ym == thisMonth;
    }).toList()..sort((a, b) => a.tgl.compareTo(b.tgl));

    final buffer = StringBuffer();
    buffer.writeln("TGL_QTY_AKM_AVG");

    for (final e in filtered) {
      buffer.writeln(
        "${formatDayFromYmd(e.tgl)}_${e.qty}_${e.akmQty}_${e.average.toStringAsFixed(0)}",
      );
    }

    return buffer.toString();
  }

  void _updateSummary() => setState(() {});

  Future<String> _buildWhatsAppMessage() async {
    final today = DateTime.now();
    final tgl = formatDateV1(today);
    final blnIni = formatMonth(today);
    final blnLalu = formatPrevMonth(today);

    final service = SharedPreferencesService();
    final store = await service.getSayBreadStore();
    final historyText = await _buildMonthlyHistory();

    final sbtitle = store?.title ?? "LAPORAN SAY BREAD";
    final sbnama = store?.nama ?? "-";
    final sbcode = store?.kode ?? "-";
    final sbtgl = store?.tgl ?? "-";
    final sbarea = store?.area ?? "-";

    final history = await service.getSayBread();
    final akmQty = history.fold(0, (sum, e) => sum + e.qty);
    final akmSales = history.fold(0, (sum, e) => sum + e.sales);

    return """
*$sbtitle*
```Tanggal $tgl```

*Shift 1* ```
Sales.     : ${_rupiah(_toInt(s1Sales))}
Qty.        : ${_toInt(s1Qty)}```

*Shift 2* ```
Sales.     : ${_rupiah(_toInt(s2Sales))}
Qty.        : ${_toInt(s2Qty)}```

*TOTAL*```
Sales.     : ${_rupiah(totalSales)}
Qty.       : $totalQty
```
=========+=========
```
Nama toko = $sbnama
Kode toko = $sbcode
Tgl GO    = $sbtgl
Area toko = $sbarea
```
*TREND AKM & SPD*

AKM $blnLalu = ${akmLastMonth.text}

```Sales berjalan : ```
$blnIni
```
$historyText```
*Total sales = ${_rupiah(akmSales)}*

*Qty Akm = $akmQty*
*SPD          = ${_rupiah(totalSales)}*
""";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ShiftCard(
                title: "Shift 1",
                accentColor: Colors.teal,
                child: Row(
                  children: [
                    Expanded(
                      child: CustomInputField(
                        label: "Sales",
                        controller: s1Sales,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomInputField(
                        label: "Qty",
                        controller: s1Qty,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              ShiftCard(
                title: "Shift 2",
                accentColor: Colors.orange.shade200,
                child: Row(
                  children: [
                    Expanded(
                      child: CustomInputField(
                        label: "Sales",
                        controller: s2Sales,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomInputField(
                        label: "Qty",
                        controller: s2Qty,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              ShiftCard(
                title: "Last Month",
                accentColor: Colors.blue.shade200,
                child: CustomInputField(
                  label: "AKM Qty. Last Month",
                  controller: akmLastMonth,
                  keyboardType: TextInputType.number,
                ),
              ),

              const SizedBox(height: 20),

              SummarySection(
                rows: [
                  SummaryRow(label: "Sales:", value: _rupiah(totalSales)),
                  SummaryRow(label: "Qty:", value: totalQty.toString()),
                ],
              ),

              const SizedBox(height: 16),

              ActionButtons(
                onSave: () async {
                  final controllers = [
                    s1Sales,
                    s1Qty,
                    s2Sales,
                    s2Qty,
                    akmLastMonth,
                  ];
                  final emptyFields = controllers
                      .where((c) => c.text.trim().isEmpty)
                      .toList();

                  if (emptyFields.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Semua field harus diisi sebelum menyimpan!",
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final now = DateTime.now();
                  final tgl = now.year * 10000 + now.month * 100 + now.day;

                  final service = SharedPreferencesService();
                  final history = await service.getSayBread();

                  final akmQty =
                      history.fold(0, (sum, e) => sum + e.qty) + totalQty;

                  final akmSales =
                      history.fold(0, (sum, e) => sum + e.sales) + totalSales;

                  final data = SayBreadHistory(
                    tgl: tgl,
                    sales: totalSales,
                    qty: totalQty,
                    akmQty: akmQty,
                    akmSales: akmSales,
                    average: akmQty / now.day,
                  );

                  await service.saveSayBread(data);

                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Data Say Bread tersimpan")),
                  );
                },
                onWhatsApp: () async {
                  final controllers = [
                    s1Sales,
                    s1Qty,
                    s2Sales,
                    s2Qty,
                    akmLastMonth,
                  ];
                  final emptyFields = controllers
                      .where((c) => c.text.trim().isEmpty)
                      .toList();

                  if (emptyFields.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Semua field harus diisi sebelum mengirim WA!",
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final text = await _buildWhatsAppMessage();

                  final uri = Uri.parse(
                    "https://wa.me/6281290057505?text=${Uri.encodeComponent(text)}",
                  );

                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Gagal membuka WhatsApp"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
