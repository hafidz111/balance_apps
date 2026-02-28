import 'package:balance/screen/widgets/custom_snack_bar.dart';
import 'package:balance/service/shared_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/model/point_coffe_history.dart';
import '../../data/model/store_data.dart';
import '../../providers/shared_preference_provider.dart';
import '../../utils/date_format.dart';
import '../../utils/number_format.dart';
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
  StoreData? store;

  late List<TextEditingController> salesControllers;
  late List<TextEditingController> stdControllers;
  late List<TextEditingController> apcControllers;
  late List<TextEditingController> cupControllers;
  late List<TextEditingController> addControllers;

  static const int maxShift = 4;
  int shiftCount = 2;

  @override
  void initState() {
    super.initState();
    _loadStore();
    _initControllers();
    _loadDraft();
  }

  void _initControllers() {
    salesControllers = List.generate(maxShift, (_) => TextEditingController());
    stdControllers = List.generate(maxShift, (_) => TextEditingController());
    apcControllers = List.generate(maxShift, (_) => TextEditingController());
    cupControllers = List.generate(maxShift, (_) => TextEditingController());
    addControllers = List.generate(maxShift, (_) => TextEditingController());

    for (int i = 0; i < maxShift; i++) {
      salesControllers[i].addListener(_updateAll);
      stdControllers[i].addListener(_updateAll);
      cupControllers[i].addListener(_updateAll);
      addControllers[i].addListener(_updateAll);
    }
  }

  Future<void> _loadStore() async {
    final data = await SharedPreferencesService().getPointCoffeeStore();
    setState(() {
      store = data;
    });
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

  int get totalStd {
    int total = 0;
    for (int i = 0; i < shiftCount; i++) {
      total += _toInt(stdControllers[i]);
    }
    return total;
  }

  int get totalCup {
    int total = 0;
    for (int i = 0; i < shiftCount; i++) {
      total += _toInt(cupControllers[i]);
    }
    return total;
  }

  int get totalAdd {
    int total = 0;
    for (int i = 0; i < shiftCount; i++) {
      total += _toInt(addControllers[i]);
    }
    return total;
  }

  String _rupiahShort(int value) {
    return (value / 1000000).toStringAsFixed(1);
  }

  String _rupiah(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  // String _number(int value) => value.toString();

  String _apc(int sales, int std) {
    if (std == 0) return "0";

    final result = (sales / std) / 1000;

    return result.toStringAsFixed(3).replaceAll('.', ',');
  }

  void _updateAll() {
    for (int i = 0; i < shiftCount; i++) {
      final sales = _toInt(salesControllers[i]);
      final std = _toInt(stdControllers[i]);

      apcControllers[i].text = _apc(sales, std);
    }

    _saveDraft();
    setState(() {});
  }

  // String _calculateAPC(
  //   TextEditingController salesCtrl,
  //   TextEditingController stdCtrl,
  // ) {
  //   final sales = int.tryParse(salesCtrl.text) ?? 0;
  //   final std = int.tryParse(stdCtrl.text) ?? 0;
  //   if (std == 0) return "0.000";
  //   return (sales / std).toStringAsFixed(3);
  // }

  double get apc => totalStd == 0 ? 0 : totalSales / totalStd / 1000;

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
    for (int i = 0; i < maxShift; i++) {
      salesControllers[i].dispose();
      stdControllers[i].dispose();
      apcControllers[i].dispose();
      cupControllers[i].dispose();
      addControllers[i].dispose();
    }
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

    String shiftText = "";

    for (int i = 0; i < shiftCount; i++) {
      shiftText +=
          """
*Shift ${i + 1}* ```
Sales : ${_rupiah(_toInt(salesControllers[i]))}
Std   : ${_toInt(stdControllers[i])}
Apc   : ${apcControllers[i].text}
Cup   : ${_toInt(cupControllers[i])}
Add   : ${_toInt(addControllers[i])} ```
""";
    }

    return """
*$title*
```Tanggal $tgl```

$shiftText

*TOTAL* ```
Sales    : ${_rupiah(totalSales)}
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

  Future<void> _saveData() async {
    final now = DateTime.now();
    final tgl = now.year * 10000 + now.month * 100 + now.day;

    final service = SharedPreferencesService();
    final history = await service.getPointCoffee();

    final akmCup = history.fold(0, (sum, e) => sum + e.cup) + totalCup;

    final data = PointCoffeeHistory(
      tgl: tgl,
      spd: totalSales,
      cup: totalCup,
      akmCup: akmCup,
      cpd: akmCup / now.day,
    );

    await service.savePointCoffee(data);
    await service.clearPointCoffeeDraft(tgl);

    CustomSnackBar.show(
      context,
      message: "Data Point Coffee tersimpan",
      type: SnackType.success,
    );
  }

  Future<void> _saveDraft() async {
    final now = DateTime.now();
    final tgl = now.year * 10000 + now.month * 100 + now.day;

    final data = {
      "shiftCount": shiftCount,
      "sales": salesControllers.map((e) => e.text).toList(),
      "std": stdControllers.map((e) => e.text).toList(),
      "cup": cupControllers.map((e) => e.text).toList(),
      "add": addControllers.map((e) => e.text).toList(),
    };

    await SharedPreferencesService().savePointCoffeeDraft(tgl, data);
  }

  Future<void> _loadDraft() async {
    final now = DateTime.now();
    final tgl = now.year * 10000 + now.month * 100 + now.day;

    final draft = await SharedPreferencesService().getPointCoffeeDraft(tgl);

    if (draft == null) return;

    shiftCount = draft["shiftCount"] ?? shiftCount;

    final sales = List<String>.from(draft["sales"] ?? []);
    final std = List<String>.from(draft["std"] ?? []);
    final cup = List<String>.from(draft["cup"] ?? []);
    final add = List<String>.from(draft["add"] ?? []);

    for (int i = 0; i < maxShift; i++) {
      if (i < sales.length) salesControllers[i].text = sales[i];
      if (i < std.length) stdControllers[i].text = std[i];
      if (i < cup.length) cupControllers[i].text = cup[i];
      if (i < add.length) addControllers[i].text = add[i];
    }

    _updateAll();
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
                      child: Column(
                        children: [
                          Row(
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
                                  label: "Std",
                                  controller: stdControllers[index],
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [RupiahInputFormatter()],
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
                                  controller: apcControllers[index],
                                  enabled: false,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: CustomInputField(
                                  label: "Cup",
                                  controller: cupControllers[index],
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [RupiahInputFormatter()],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          CustomInputField(
                            label: "Add",
                            controller: addControllers[index],
                            keyboardType: TextInputType.number,
                            inputFormatters: [RupiahInputFormatter()],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }),

              SummarySection(
                rows: [
                  SummaryRow(label: "Sales:", value: totalSales.toString()),
                  SummaryRow(label: "Std:", value: totalStd.toString()),
                  SummaryRow(label: "Apc:", value: _apc(totalSales, totalStd)),
                  SummaryRow(label: "Cup:", value: totalCup.toString()),
                  SummaryRow(label: "Add:", value: totalAdd.toString()),
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
                      message:
                          "Gagal membuka WhatsApp: ${e.toString().replaceAll('Exception: ', '')}",
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
