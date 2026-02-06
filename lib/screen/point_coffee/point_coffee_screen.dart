import 'package:balance/service/shared_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/model/point_coffe_history.dart';
import '../../data/model/store_data.dart';
import '../../utils/date_format.dart';
import '../widgets/action_buttons.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/shift_card.dart';
import '../widgets/summary_row.dart';
import '../widgets/summary_section.dart';

class PointCoffeeScreen extends StatefulWidget {
  const PointCoffeeScreen({super.key});

  @override
  State<PointCoffeeScreen> createState() => _PointCoffeeScreenState();
}

class _PointCoffeeScreenState extends State<PointCoffeeScreen> {
  final s1Sales = TextEditingController();
  final s1Std = TextEditingController();
  final s1Apc = TextEditingController();
  final s1Cup = TextEditingController();
  final s1Add = TextEditingController();

  final s2Sales = TextEditingController();
  final s2Std = TextEditingController();
  final s2Apc = TextEditingController();
  final s2Cup = TextEditingController();
  final s2Add = TextEditingController();

  StoreData? store;

  @override
  void initState() {
    super.initState();
    _loadStore();

    s1Sales.addListener(_updateAll);
    s1Std.addListener(_updateAll);
    s2Sales.addListener(_updateAll);
    s2Std.addListener(_updateAll);
    s1Cup.addListener(_updateAll);
    s1Add.addListener(_updateAll);
    s2Add.addListener(_updateAll);
  }

  Future<void> _loadStore() async {
    final data = await SharedPreferencesService().getPointCoffeeStore();
    setState(() {
      store = data;
    });
  }

  int _toInt(TextEditingController c) => int.tryParse(c.text) ?? 0;

  int get totalSales => _toInt(s1Sales) + _toInt(s2Sales);

  int get totalStd => _toInt(s1Std) + _toInt(s2Std);

  int get totalCup => _toInt(s1Cup) + _toInt(s2Cup);

  int get totalAdd => _toInt(s1Add) + _toInt(s2Add);

  String _rupiahShort(int value) {
    return (value / 1000000).toStringAsFixed(1);
  }

  String _number(int value) => value.toString();

  String _apc(int sales, int std) {
    if (std == 0) return "0";
    return (sales / std).toStringAsFixed(0);
  }

  void _updateAll() {
    final newS1Apc = _calculateAPC(s1Sales, s1Std);
    final newS2Apc = _calculateAPC(s2Sales, s2Std);

    if (s1Apc.text != newS1Apc) s1Apc.text = newS1Apc;
    if (s2Apc.text != newS2Apc) s2Apc.text = newS2Apc;

    setState(() {});
  }

  String _calculateAPC(
    TextEditingController salesCtrl,
    TextEditingController stdCtrl,
  ) {
    final sales = int.tryParse(salesCtrl.text) ?? 0;
    final std = int.tryParse(stdCtrl.text) ?? 0;
    if (std == 0) return "0.000";
    return (sales / std).toStringAsFixed(3);
  }

  double get apc => totalStd == 0 ? 0 : totalSales / totalStd;

  Future<String> _buildMonthlyHistory() async {
    final service = SharedPreferencesService();
    final history = await service.getPointCoffee();

    final buffer = StringBuffer();
    buffer.writeln("TGL_SPD_CUP_AKMCUP_CPD");

    for (final e in history) {
      buffer.writeln(
        "${formatDayFromYmd(e.tgl)}_${_rupiahShort(e.spd)}_${e.cup}_${e.akmCup}_${e.cpd.toStringAsFixed(0)}",
      );
    }

    return buffer.toString();
  }

  double _calculateCpdToday({
    required List<PointCoffeeHistory> history,
    required int todayCup,
    required int dayOfMonth,
  }) {
    final akmCup = history.fold(0, (sum, e) => sum + e.cup) + todayCup;
    if (dayOfMonth == 0) return 0;
    return akmCup / dayOfMonth;
  }

  @override
  void dispose() {
    s1Sales.dispose();
    s1Std.dispose();
    s1Apc.dispose();
    s1Cup.dispose();
    s1Add.dispose();

    s2Sales.dispose();
    s2Std.dispose();
    s2Apc.dispose();
    s2Cup.dispose();
    s2Add.dispose();

    super.dispose();
  }

  Future<String> _buildWhatsAppMessage() async {
    final today = DateTime.now();
    final tgl = formatDateV1(today);
    final blnIni = formatMonth(today);
    final historyText = await _buildMonthlyHistory();

    final service = SharedPreferencesService();
    final history = await service.getPointCoffee();

    final cpdNow = _calculateCpdToday(
      history: history,
      todayCup: totalCup,
      dayOfMonth: today.day,
    ).toStringAsFixed(0);

    final title = store?.title ?? "LAPORAN POINT COFFEE";
    final nama = store?.nama ?? "-";
    final kode = store?.kode ?? "-";
    final tglGo = store?.tgl ?? "-";
    final area = store?.area ?? "-";

    return """
*$title*
```Tanggal $tgl```

*Shift 1* ```
Sales.   : ${_rupiahShort(_toInt(s1Sales))}
Std.     : ${_number(_toInt(s1Std))}
Apc      : ${_apc(_toInt(s1Sales), _toInt(s1Std))}
Cup.     : ${_number(_toInt(s1Cup))}
Add      : ${_number(_toInt(s1Add))} ```

*Shift 2* ```
Sales.   : ${_rupiahShort(_toInt(s2Sales))}
Std      : ${_number(_toInt(s2Std))}
Apc      : ${_apc(_toInt(s2Sales), _toInt(s2Std))}
Cup      : ${_number(_toInt(s2Cup))}
Add      : ${_number(_toInt(s2Add))} ```

*TOTAL* ```
Sales    : ${_rupiahShort(totalSales)}
Std.     : $totalStd
Apc      : ${_apc(totalSales, totalStd)}
Cup.     : $totalCup
Add      : $totalAdd

Nama toko  = $nama
Kode toko  = $kode
Tgl GO     = $tglGo
Area toko  = $area

CPD: $cpdNow

_Bulan berjalan :
$blnIni

$historyText```
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
                child: Column(
                  children: [
                    Row(
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
                            label: "Std",
                            controller: s1Std,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CustomInputField(
                            label: "Apc",
                            controller: s1Apc,
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomInputField(
                            label: "Cup",
                            controller: s1Cup,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CustomInputField(
                            label: "Add",
                            controller: s1Add,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              ShiftCard(
                title: "Shift 2",
                accentColor: Colors.orange.shade200,
                child: Column(
                  children: [
                    Row(
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
                            label: "Std",
                            controller: s2Std,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CustomInputField(
                            label: "Apc",
                            controller: s2Apc,
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomInputField(
                            label: "Cup",
                            controller: s2Cup,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CustomInputField(
                            label: "Add",
                            controller: s2Add,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SummarySection(
                rows: [
                  SummaryRow(label: "Sales:", value: totalSales.toString()),
                  SummaryRow(label: "Std:", value: totalStd.toString()),
                  SummaryRow(label: "Apc:", value: apc.toStringAsFixed(3)),
                  SummaryRow(label: "Cup:", value: totalCup.toString()),
                  SummaryRow(label: "Add:", value: totalAdd.toString()),
                ],
              ),

              const SizedBox(height: 16),

              ActionButtons(
                onSave: () async {
                  final controllers = [
                    s1Sales,
                    s1Std,
                    s1Apc,
                    s1Cup,
                    s1Add,
                    s2Sales,
                    s2Std,
                    s2Apc,
                    s2Cup,
                    s2Add,
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
                  final history = await service.getPointCoffee();

                  final akmCup =
                      history.fold(0, (sum, e) => sum + e.cup) + totalCup;

                  final data = PointCoffeeHistory(
                    tgl: tgl,
                    spd: totalSales,
                    cup: totalCup,
                    akmCup: akmCup,
                    cpd: akmCup / now.day,
                  );

                  await service.savePointCoffee(data);

                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Data Point Coffee tersimpan"),
                    ),
                  );
                },
                onWhatsApp: () async {
                  final controllers = [
                    s1Sales,
                    s1Std,
                    s1Apc,
                    s1Cup,
                    s1Add,
                    s2Sales,
                    s2Std,
                    s2Apc,
                    s2Cup,
                    s2Add,
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
                        content: Text(
                          "Gagal membuka WhatsApp: ${e.toString().replaceAll('Exception: ', '')}",
                        ),
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
