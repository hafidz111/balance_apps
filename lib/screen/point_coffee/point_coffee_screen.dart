import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starvy/screen/widgets/custom_snack_bar.dart';
import 'package:starvy/service/shared_preferences_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/model/point_coffe_history.dart';
import '../../data/model/store_data.dart';
import '../../providers/point_coffee_provider.dart';
import '../../providers/shared_preference_provider.dart';
import '../../utils/date_format.dart';
import '../../utils/number_format.dart';
import '../widgets/action_buttons.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/product_dashboard_widgets.dart';

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

  late TextEditingController cpdManualController;
  String? savedMonthKey;

  List<String> _shiftLabels = List<String>.from(
    SharedPreferencesService.defaultShiftTimeLabels,
  );

  Timer? _shiftClockTimer;

  int _accumSalesRupiah = 0;
  int _accumCup = 0;
  double _lastApcValue = 0;

  @override
  void initState() {
    super.initState();
    _shiftLabels = SharedPreferencesService().getShiftTimeLabels();
    _loadStore();
    _initControllers();
    _loadDraft();
    cpdManualController = TextEditingController();
    cpdManualController.addListener(_saveCpdManual);
    _loadCpdManual();
    _shiftClockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAccumulationFromHistory();
    });
  }

  Future<void> _refreshAccumulationFromHistory() async {
    final list = await SharedPreferencesService().getPointCoffee();
    if (!mounted) return;

    final salesSum = list.fold<int>(0, (a, e) => a + e.spd);
    final cupSum = list.fold<int>(0, (a, e) => a + e.cup);
    double lastApc = 0;
    if (list.isNotEmpty) {
      final sorted = [...list]..sort((a, b) => b.tgl.compareTo(a.tgl));
      lastApc = sorted.first.apc;
    }

    setState(() {
      _accumSalesRupiah = salesSum;
      _accumCup = cupSum;
      _lastApcValue = lastApc;
    });
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
    store = data;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final pref = context.watch<SharedPreferenceProvider>();
    final formProvider = context.read<PointCoffeeProvider>();

    final shift = pref.shiftCount ?? 2;
    formProvider.setShiftCount(shift.clamp(1, maxShift));
    _shiftLabels = SharedPreferencesService().getShiftTimeLabels();
  }

  int _toInt(TextEditingController c) {
    final clean = c.text.replaceAll('.', '');
    return int.tryParse(clean) ?? 0;
  }

  int get totalSales {
    final shiftCount = context.read<PointCoffeeProvider>().shiftCount;
    int total = 0;
    for (int i = 0; i < shiftCount; i++) {
      total += _toInt(salesControllers[i]);
    }
    return total;
  }

  int get totalStd {
    final shiftCount = context.read<PointCoffeeProvider>().shiftCount;
    int total = 0;
    for (int i = 0; i < shiftCount; i++) {
      total += _toInt(stdControllers[i]);
    }
    return total;
  }

  int get totalCup {
    final shiftCount = context.read<PointCoffeeProvider>().shiftCount;
    int total = 0;
    for (int i = 0; i < shiftCount; i++) {
      total += _toInt(cupControllers[i]);
    }
    return total;
  }

  int get totalAdd {
    final shiftCount = context.read<PointCoffeeProvider>().shiftCount;
    int total = 0;
    for (int i = 0; i < shiftCount; i++) {
      total += _toInt(addControllers[i]);
    }
    return total;
  }

  String _rupiahShort(int value) {
    final juta = value / 1000000;

    final truncated = (juta * 10).floor() / 10;

    return truncated.toStringAsFixed(1);
  }

  String _rupiah(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  double _apcValue(int sales, int std) {
    if (std == 0) return 0;
    return (sales / std) / 1000;
  }

  String _apc(int sales, int std) {
    final v = _apcValue(sales, std);
    if (v == 0) return '0';
    return v.toStringAsFixed(3).replaceAll('.', ',');
  }

  String _apcDisplay(double v) {
    if (v == 0) return '0';
    return v.toStringAsFixed(3).replaceAll('.', ',');
  }

  void _updateAll() {
    final shiftCount = context.read<PointCoffeeProvider>().shiftCount;
    for (int i = 0; i < shiftCount; i++) {
      final sales = _toInt(salesControllers[i]);
      final std = _toInt(stdControllers[i]);

      apcControllers[i].text = _apc(sales, std);
    }

    _saveDraft();
    context.read<PointCoffeeProvider>().markFormChanged();
  }

  Widget _buildShiftInputs(int index) {
    const goldStd = Color(0xFFC9A227);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProductShiftInputRow(
          label: 'Penjualan',
          leadingIcon: Icons.account_balance_wallet_rounded,
          iconColor: Colors.orange.shade700,
          controller: salesControllers[index],
          keyboardType: TextInputType.number,
          inputFormatters: [RupiahInputFormatter()],
        ),
        const SizedBox(height: 10),
        ProductShiftInputRow(
          label: 'Cup terjual',
          leadingIcon: Icons.local_cafe_rounded,
          iconColor: Colors.deepOrange.shade400,
          controller: cupControllers[index],
          keyboardType: TextInputType.number,
          inputFormatters: [RupiahInputFormatter()],
        ),
        const SizedBox(height: 10),
        ProductShiftInputRow(
          label: 'APC (Auto)',
          leadingIcon: Icons.insights_rounded,
          iconColor: Colors.green.shade700,
          controller: apcControllers[index],
          readOnly: true,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 10),
        ProductShiftInputRow(
          label: 'Std',
          leadingIcon: Icons.speed_rounded,
          iconColor: goldStd,
          controller: stdControllers[index],
          keyboardType: TextInputType.number,
          inputFormatters: [RupiahInputFormatter()],
        ),
        const SizedBox(height: 10),
        ProductShiftInputRow(
          label: 'Add',
          leadingIcon: Icons.note_alt_outlined,
          iconColor: Colors.teal.shade700,
          controller: addControllers[index],
          keyboardType: TextInputType.number,
          inputFormatters: [RupiahInputFormatter()],
        ),
      ],
    );
  }

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

  Future<void> _loadCpdManual() async {
    final service = SharedPreferencesService();
    final value = await service.getPointCoffeeCpdManual();

    if (value != null) {
      cpdManualController.text = value;
    }
  }

  Future<void> _saveCpdManual() async {
    final value = cpdManualController.text.trim();
    final service = SharedPreferencesService();

    if (value.isEmpty) {
      await service.clearPointCoffeeCpdManual();
      return;
    }

    await service.savePointCoffeeCpdManual(value);
  }

  @override
  void dispose() {
    _shiftClockTimer?.cancel();
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
    final manualCpd = await service.getPointCoffeeCpdManual();

    String? cpdNow;

    if (manualCpd != null && manualCpd.isNotEmpty) {
      cpdNow = manualCpd;
    }

    final title = store?.title ?? "LAPORAN COFFEE";
    final nama = store?.nama ?? "-";
    final kode = store?.kode ?? "-";
    final tglGo = store?.tgl ?? "-";
    final area = store?.area ?? "-";

    String shiftText = "";
    final shiftCount = context.read<PointCoffeeProvider>().shiftCount;

    for (int i = 0; i < shiftCount; i++) {
      shiftText +=
          "*Shift ${i + 1}*\n"
          "```Sales : ${_rupiah(_toInt(salesControllers[i]))}\n"
          "Std   : ${_toInt(stdControllers[i])}\n"
          "Apc   : ${apcControllers[i].text}\n"
          "Cup   : ${_toInt(cupControllers[i])}\n"
          "Add   : ${_toInt(addControllers[i])}\n"
          "```\n";
    }

    return """
*$title*
```Tanggal $tgl```

${shiftText.trim()}

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
${cpdNow != null ? "\nCPD: $cpdNow\n" : ""}
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
      apc: _apcValue(totalSales, totalStd),
    );

    await service.savePointCoffee(data);
    await service.clearPointCoffeeDraft(tgl);
    await _refreshAccumulationFromHistory();

    FirebaseAnalytics.instance.logEvent(
      name: "point_coffee_saved",
      parameters: {"total_sales": totalSales, "total_cup": totalCup},
    );

    CustomSnackBar.show(
      context,
      message: "Data Coffee tersimpan",
      type: SnackType.success,
    );
  }

  Future<void> _saveDraft() async {
    final now = DateTime.now();
    final tgl = now.year * 10000 + now.month * 100 + now.day;

    final data = {
      "shiftCount": context.read<PointCoffeeProvider>().shiftCount,
      "sales": salesControllers.map((e) => e.text).toList(),
      "std": stdControllers.map((e) => e.text).toList(),
      "cup": cupControllers.map((e) => e.text).toList(),
      "add": addControllers.map((e) => e.text).toList(),
    };

    await SharedPreferencesService().savePointCoffeeDraft(tgl, data);
    FirebaseAnalytics.instance.logEvent(name: "point_coffee_draft_saved");
  }

  Future<void> _loadDraft() async {
    final now = DateTime.now();
    final tgl = now.year * 10000 + now.month * 100 + now.day;

    final draft = await SharedPreferencesService().getPointCoffeeDraft(tgl);

    if (draft == null) return;

    final currentShift = context.read<PointCoffeeProvider>().shiftCount;
    final shiftCount = draft["shiftCount"] ?? currentShift;
    context.read<PointCoffeeProvider>().setShiftCount(shiftCount);

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
    final shiftCount = context.select<PointCoffeeProvider, int>(
      (provider) => provider.shiftCount,
    );
    context.select<PointCoffeeProvider, int>(
      (provider) => provider.formVersion,
    );
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProductSummaryCard(
                title: 'Total Akumulasi',
                subtitle: 'Rangkuman hingga data terakhir',
                metrics: [
                  ProductMetricData(
                    label: 'Sales',
                    value: _rupiah(_accumSalesRupiah),
                  ),
                  ProductMetricData(
                    label: 'Cup Terjual',
                    value: _rupiah(_accumCup),
                  ),
                  ProductMetricData(
                    label: 'APC',
                    value: _apcDisplay(_lastApcValue),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(shiftCount, (index) {
                final raw = index < _shiftLabels.length
                    ? _shiftLabels[index]
                    : '';
                final sub = SharedPreferencesService.jamKerjaSubtitle(raw);
                final phase = SharedPreferencesService.shiftTimePhaseAt(raw);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: ProductShiftCard(
                    shiftIndex: index,
                    subtitle: sub,
                    shiftPhase: phase,
                    child: _buildShiftInputs(index),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: CustomInputField(
                  label: 'CPD bulan lalu',
                  controller: cpdManualController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [RupiahInputFormatter()],
                ),
              ),
              const SizedBox(height: 16),
              ActionButtons(
                onWhatsApp: () async {
                  final service = SharedPreferencesService();
                  final phone = service.getPhoneNumber();

                  if (phone == null || phone.trim().isEmpty) {
                    CustomSnackBar.show(
                      context,
                      message: 'Nomor WhatsApp belum diatur di Settings',
                      type: SnackType.error,
                    );
                    return;
                  }

                  await _saveData();
                  final text = await _buildWhatsAppMessage();

                  final uri = Uri.parse(
                    'https://wa.me/$phone?text=${Uri.encodeComponent(text)}',
                  );

                  try {
                    FirebaseAnalytics.instance.logEvent(
                      name: 'point_coffee_whatsapp_sent',
                    );
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    // ignore: use_build_context_synchronously
                    CustomSnackBar.show(
                      context,
                      message:
                          'Gagal membuka WhatsApp: ${e.toString().replaceAll('Exception: ', '')}',
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
