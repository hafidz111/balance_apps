import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starvy/screen/widgets/custom_snack_bar.dart';
import 'package:starvy/service/shared_preferences_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/model/bread_history.dart';
import '../../providers/bread_provider.dart';
import '../../providers/shared_preference_provider.dart';
import '../../utils/date_format.dart';
import '../../utils/number_format.dart';
import '../widgets/action_buttons.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/product_dashboard_widgets.dart';

class BreadScreen extends StatefulWidget {
  const BreadScreen({super.key});

  @override
  State<BreadScreen> createState() => _BreadScreenState();
}

class _BreadScreenState extends State<BreadScreen> {
  late List<TextEditingController> salesControllers;
  late List<TextEditingController> qtyControllers;

  static const int maxShift = 4;
  final akmLastMonth = TextEditingController();

  List<String> _shiftLabels = List<String>.from(
    SharedPreferencesService.defaultShiftTimeLabels,
  );

  Timer? _shiftClockTimer;

  int _accumSalesRupiah = 0;
  int _accumQty = 0;

  @override
  void initState() {
    super.initState();

    _shiftLabels = SharedPreferencesService().getShiftTimeLabels();

    salesControllers = List.generate(maxShift, (_) => TextEditingController());
    qtyControllers = List.generate(maxShift, (_) => TextEditingController());

    for (int i = 0; i < maxShift; i++) {
      salesControllers[i].addListener(_updateSummary);
      qtyControllers[i].addListener(_updateSummary);
    }
    akmLastMonth.addListener(_updateSummary);

    _loadDraft();
    _shiftClockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAccumulationFromHistory();
    });
  }

  Future<void> _refreshAccumulationFromHistory() async {
    final list = await SharedPreferencesService().getBread();
    if (!mounted) return;

    final salesSum = list.fold<int>(0, (a, e) => a + e.sales);
    final qtySum = list.fold<int>(0, (a, e) => a + e.qty);

    setState(() {
      _accumSalesRupiah = salesSum;
      _accumQty = qtySum;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final pref = context.watch<SharedPreferenceProvider>();
    final formProvider = context.read<BreadProvider>();

    final shift = pref.shiftCount ?? 2;
    final next = shift.clamp(1, maxShift);
    if (formProvider.shiftCount != next) {
      formProvider.setShiftCount(next);
      FirebaseAnalytics.instance.logEvent(
        name: "bread_shift_changed",
        parameters: {"shift_count": next},
      );
    }
    _shiftLabels = SharedPreferencesService().getShiftTimeLabels();
  }

  int _toInt(TextEditingController c) {
    final clean = c.text.replaceAll('.', '');
    return int.tryParse(clean) ?? 0;
  }

  int get totalSales {
    final shiftCount = context.read<BreadProvider>().shiftCount;
    int total = 0;
    for (int i = 0; i < shiftCount; i++) {
      total += _toInt(salesControllers[i]);
    }
    return total;
  }

  int get totalQty {
    final shiftCount = context.read<BreadProvider>().shiftCount;
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
    final history = await service.getBread();

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

  void _updateSummary() {
    _saveDraft();
    context.read<BreadProvider>().markFormChanged();
  }

  Future<String> _buildWhatsAppMessage() async {
    final today = DateTime.now();
    final tgl = formatDateV1(today);
    final blnIni = formatMonth(today);
    final blnLalu = formatPrevMonth(today);

    final service = SharedPreferencesService();
    final store = await service.getBreadStore();
    final historyText = await _buildMonthlyHistory();

    final sbtitle = store?.title ?? "LAPORAN BREAD";
    final sbnama = store?.nama ?? "-";
    final sbcode = store?.kode ?? "-";
    final sbtgl = store?.tgl ?? "-";
    final sbarea = store?.area ?? "-";

    final history = await service.getBread();
    final akmQty = history.fold(0, (sum, e) => sum + e.qty);
    final akmSales = history.fold(0, (sum, e) => sum + e.sales);

    String shiftText = "";
    final shiftCount = context.read<BreadProvider>().shiftCount;

    for (int i = 0; i < shiftCount; i++) {
      shiftText +=
          "*Shift ${i + 1}*\n"
          "```Sales : ${_rupiah(_toInt(salesControllers[i]))}\n"
          "Qty   : ${_toInt(qtyControllers[i])}\n"
          "```\n";
    }
    return """
*$sbtitle*
```Tanggal $tgl```

${shiftText.trim()}

*TOTAL* ```
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
    _shiftClockTimer?.cancel();
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
    final history = await service.getBread();

    final akmQty = history.fold(0, (sum, e) => sum + e.qty) + totalQty;

    final akmSales = history.fold(0, (sum, e) => sum + e.sales) + totalSales;

    final data = BreadHistory(
      tgl: tgl,
      sales: totalSales,
      qty: totalQty,
      akmQty: akmQty,
      akmSales: akmSales,
      average: akmQty / now.day,
    );

    await service.saveBread(data);
    await service.clearBreadDraft(tgl);
    await _refreshAccumulationFromHistory();

    FirebaseAnalytics.instance.logEvent(
      name: "bread_saved",
      parameters: {"total_sales": totalSales, "total_qty": totalQty},
    );

    // ignore: use_build_context_synchronously
    CustomSnackBar.show(
      context,
      message: "Data Bread tersimpan",
      type: SnackType.success,
    );
  }

  Future<void> _saveDraft() async {
    final now = DateTime.now();
    final tgl = now.year * 10000 + now.month * 100 + now.day;

    final data = {
      "shiftCount": context.read<BreadProvider>().shiftCount,
      "sales": salesControllers.map((e) => e.text).toList(),
      "qty": qtyControllers.map((e) => e.text).toList(),
      "akmLastMonth": akmLastMonth.text,
    };

    await SharedPreferencesService().saveBreadDraft(tgl, data);
    FirebaseAnalytics.instance.logEvent(name: "bread_draft_saved");
  }

  Future<void> _loadDraft() async {
    final now = DateTime.now();
    final tgl = now.year * 10000 + now.month * 100 + now.day;

    final draft = await SharedPreferencesService().getBreadDraft(tgl);

    if (draft == null) return;

    final currentShift = context.read<BreadProvider>().shiftCount;
    final shiftCount = draft["shiftCount"] ?? currentShift;
    context.read<BreadProvider>().setShiftCount(shiftCount);
    final sales = List<String>.from(draft["sales"] ?? []);
    final qty = List<String>.from(draft["qty"] ?? []);

    for (int i = 0; i < maxShift; i++) {
      if (i < sales.length) salesControllers[i].text = sales[i];
      if (i < qty.length) qtyControllers[i].text = qty[i];
    }

    akmLastMonth.text = draft["akmLastMonth"] ?? "";

    context.read<BreadProvider>().markFormChanged();
  }

  @override
  Widget build(BuildContext context) {
    final shiftCount = context.select<BreadProvider, int>(
      (provider) => provider.shiftCount,
    );
    context.select<BreadProvider, int>((provider) => provider.formVersion);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: productDashboardBackground(context),
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
                  ProductMetricData(label: 'Qty', value: _rupiah(_accumQty)),
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
                    child: Column(
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
                          label: 'Qty',
                          leadingIcon: Icons.bakery_dining_rounded,
                          iconColor: Colors.deepOrange.shade400,
                          controller: qtyControllers[index],
                          keyboardType: TextInputType.number,
                          inputFormatters: [RupiahInputFormatter()],
                        ),
                      ],
                    ),
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
                  label: 'AKM Qty. bulan lalu',
                  controller: akmLastMonth,
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
                      name: 'bread_whatsapp_sent',
                    );
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    // ignore: use_build_context_synchronously
                    CustomSnackBar.show(
                      context,
                      message: 'Gagal membuka WhatsApp',
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
