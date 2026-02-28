import 'package:balance/screen/widgets/custom_snack_bar.dart';
import 'package:balance/service/shared_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/model/say_bread_history.dart';
import '../../providers/shared_preference_provider.dart';
import '../../utils/date_format.dart';
import '../../utils/number_format.dart';
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
  late List<TextEditingController> salesControllers;
  late List<TextEditingController> qtyControllers;

  static const int maxShift = 4;
  int shiftCount = 2; // DEFAULT 2
  final akmLastMonth = TextEditingController();

  @override
  void initState() {
    super.initState();

    salesControllers = List.generate(maxShift, (_) => TextEditingController());
    qtyControllers = List.generate(maxShift, (_) => TextEditingController());

    for (int i = 0; i < maxShift; i++) {
      salesControllers[i].addListener(_updateSummary);
      qtyControllers[i].addListener(_updateSummary);
    }
    akmLastMonth.addListener(_updateSummary);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final pref = context.watch<SharedPreferenceProvider>();

    final shift = pref.shiftCount ?? 2;

    if (shiftCount != shift) {
      setState(() {
        shiftCount = shift.clamp(1, maxShift);
      });
    }
  }

  int _toInt(TextEditingController c) {
    final clean = c.text.replaceAll('.', '');
    return int.tryParse(clean) ?? 0;
  }

  int get totalSales {
    int total = 0;
    for (int i = 0; i < shiftCount; i++) {
      total += _toInt(salesControllers[i]);
    }
    return total;
  }

  int get totalQty {
    int total = 0;
    for (int i = 0; i < shiftCount; i++) {
      total += _toInt(qtyControllers[i]);
    }
    return total;
  }

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

    String shiftText = "";

    for (int i = 0; i < shiftCount; i++) {
      shiftText +=
          """
*Shift ${i + 1}* ```
Sales : ${_rupiah(_toInt(salesControllers[i]))}
Qty   : ${_toInt(qtyControllers[i])}```
""";
    }
    return """
*$sbtitle*
```Tanggal $tgl```

$shiftText

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
  void dispose() {
    for (int i = 0; i < maxShift; i++) {
      salesControllers[i].dispose();
      qtyControllers[i].dispose();
    }
    akmLastMonth.dispose();
    super.dispose();
  }

  Future<void> _saveData() async {
    final now = DateTime.now();
    final tgl = now.year * 10000 + now.month * 100 + now.day;

    final service = SharedPreferencesService();
    final history = await service.getSayBread();

    final akmQty = history.fold(0, (sum, e) => sum + e.qty) + totalQty;

    final akmSales = history.fold(0, (sum, e) => sum + e.sales) + totalSales;

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
    CustomSnackBar.show(
      context,
      message: "Data Say Bread tersimpan",
      type: SnackType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ...List.generate(shiftCount, (index) {
                return Column(
                  children: [
                    ShiftCard(
                      title: "Shift ${index + 1}",
                      accentColor:
                          Colors.primaries[index % Colors.primaries.length],
                      child: Row(
                        children: [
                          Expanded(
                            child: CustomInputField(
                              label: "Sales",
                              controller: salesControllers[index],
                              keyboardType: TextInputType.number,
                              inputFormatters: [RupiahInputFormatter()],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: CustomInputField(
                              label: "Qty",
                              controller: qtyControllers[index],
                              keyboardType: TextInputType.number,
                              inputFormatters: [RupiahInputFormatter()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }),

              ShiftCard(
                title: "Last Month",
                accentColor: Colors.blue.shade200,
                child: CustomInputField(
                  label: "AKM Qty. Last Month",
                  controller: akmLastMonth,
                  keyboardType: TextInputType.number,
                  inputFormatters: [RupiahInputFormatter()],
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
                onWhatsApp: () async {
                  await _saveData();

                  final text = await _buildWhatsAppMessage();
                  final service = SharedPreferencesService();
                  final phone = service.getPhoneNumber();

                  if (phone == null || phone.trim().isEmpty) {
                    CustomSnackBar.show(
                      context,
                      message: "Nomor WhatsApp belum diatur di Settings",
                      type: SnackType.error,
                    );
                    return;
                  }
                  final uri = Uri.parse(
                    "https://wa.me/$phone?text=${Uri.encodeComponent(text)}",
                  );

                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    // ignore: use_build_context_synchronously
                    CustomSnackBar.show(
                      context,
                      message: "Gagal membuka WhatsApp",
                      type: SnackType.error,
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
