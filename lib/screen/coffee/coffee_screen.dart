import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starvy/screen/widgets/custom_snack_bar.dart';
import 'package:starvy/service/shared_preferences_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/coffee_provider.dart';
import '../../providers/main_screen_provider.dart';
import '../../providers/shared_preference_provider.dart';
import '../../utils/number_format.dart';
import '../../utils/stale_history_cleanup.dart';
import '../widgets/action_buttons.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/product_dashboard_widgets.dart';
import '../widgets/product_insight_card.dart';

class CoffeeScreen extends StatefulWidget {
  const CoffeeScreen({super.key});

  @override
  State<CoffeeScreen> createState() => _CoffeeScreenState();
}

class _CoffeeScreenState extends State<CoffeeScreen> {
  late List<TextEditingController> salesControllers;
  late List<TextEditingController> stdControllers;
  late List<TextEditingController> apcControllers;
  late List<TextEditingController> cupControllers;
  late List<TextEditingController> addControllers;
  late TextEditingController cpdManualController;
  late TextEditingController salesPrevManualController;

  Timer? _shiftClockTimer;

  CoffeeProvider get _coffee => context.read<CoffeeProvider>();

  @override
  void initState() {
    super.initState();
    _initControllers();
    cpdManualController = TextEditingController();
    cpdManualController.addListener(_onCpdManualChanged);
    salesPrevManualController = TextEditingController();
    salesPrevManualController.addListener(_onSalesPrevManualChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final coffee = context.read<CoffeeProvider>();
      await coffee.initialize();
      if (!mounted) return;
      _hydrateManualFields(coffee);
      await _loadDraft();
      await _refreshSummary();
      if (!mounted) return;
      await promptStaleHistoryCleanup(context);
      if (mounted) await _refreshSummary();
    });

    _shiftClockTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted) return;
      await context.read<CoffeeProvider>().syncSalesPrevManual();
      if (!mounted) return;
      _hydrateManualFields(context.read<CoffeeProvider>());
      await _refreshSummary();
    });
  }

  void _hydrateManualFields(CoffeeProvider coffee) {
    void setIfNeeded(TextEditingController c, String? value) {
      final next = value ?? '';
      if (c.text == next) return;
      c.text = next;
    }

    setIfNeeded(cpdManualController, coffee.cpdManual);
    setIfNeeded(salesPrevManualController, coffee.salesPrevManual);
  }

  void _initControllers() {
    salesControllers = List.generate(
      CoffeeProvider.maxShift,
      (_) => TextEditingController(),
    );
    stdControllers = List.generate(
      CoffeeProvider.maxShift,
      (_) => TextEditingController(),
    );
    apcControllers = List.generate(
      CoffeeProvider.maxShift,
      (_) => TextEditingController(),
    );
    cupControllers = List.generate(
      CoffeeProvider.maxShift,
      (_) => TextEditingController(),
    );
    addControllers = List.generate(
      CoffeeProvider.maxShift,
      (_) => TextEditingController(),
    );

    for (int i = 0; i < CoffeeProvider.maxShift; i++) {
      salesControllers[i].addListener(_updateAll);
      stdControllers[i].addListener(_updateAll);
      cupControllers[i].addListener(_updateAll);
      addControllers[i].addListener(_updateAll);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pref = context.watch<SharedPreferenceProvider>();
    final coffee = context.read<CoffeeProvider>();
    coffee.setShiftCount((pref.shiftCount ?? 2).clamp(1, CoffeeProvider.maxShift));
    coffee.refreshShiftLabels();
  }

  int get totalSales => _sumControllers(salesControllers);
  int get totalStd => _sumControllers(stdControllers);
  int get totalCup => _sumControllers(cupControllers);
  int get totalAdd => _sumControllers(addControllers);

  int _sumControllers(List<TextEditingController> controllers) {
    final shiftCount = _coffee.shiftCount;
    var total = 0;
    for (int i = 0; i < shiftCount; i++) {
      total += CoffeeProvider.parseInt(controllers[i].text);
    }
    return total;
  }

  Future<void> _refreshSummary() {
    return _coffee.refreshSummary(
      totalSales: totalSales,
      salesPrevManualField: CoffeeProvider.parseInt(salesPrevManualController.text),
    );
  }

  void _updateAll() {
    final shiftCount = _coffee.shiftCount;
    for (int i = 0; i < shiftCount; i++) {
      final sales = CoffeeProvider.parseInt(salesControllers[i].text);
      final std = CoffeeProvider.parseInt(stdControllers[i].text);
      apcControllers[i].text = CoffeeProvider.apcDisplay(sales, std);
    }

    unawaited(_saveDraft());
    _coffee.markFormChanged();
    unawaited(_refreshSummary());
  }

  void _onCpdManualChanged() {
    unawaited(_coffee.saveCpdManual(cpdManualController.text));
  }

  void _onSalesPrevManualChanged() {
    unawaited(() async {
      await _coffee.saveSalesPrevManual(salesPrevManualController.text);
      await _refreshSummary();
    }());
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
          label: 'Std',
          leadingIcon: Icons.speed_rounded,
          iconColor: goldStd,
          controller: stdControllers[index],
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

  Future<void> _saveDraft() {
    return _coffee.saveDraft(
      sales: salesControllers.map((e) => e.text).toList(),
      std: stdControllers.map((e) => e.text).toList(),
      cup: cupControllers.map((e) => e.text).toList(),
      add: addControllers.map((e) => e.text).toList(),
    );
  }

  Future<void> _loadDraft() async {
    final draft = await _coffee.loadDraftForToday();
    if (draft == null || !mounted) return;

    final shiftCount = draft['shiftCount'] ?? _coffee.shiftCount;
    _coffee.setShiftCount(shiftCount);

    final sales = List<String>.from(draft['sales'] ?? []);
    final std = List<String>.from(draft['std'] ?? []);
    final cup = List<String>.from(draft['cup'] ?? []);
    final add = List<String>.from(draft['add'] ?? []);

    for (int i = 0; i < CoffeeProvider.maxShift; i++) {
      if (i < sales.length) salesControllers[i].text = sales[i];
      if (i < std.length) stdControllers[i].text = std[i];
      if (i < cup.length) cupControllers[i].text = cup[i];
      if (i < add.length) addControllers[i].text = add[i];
    }

    _updateAll();
  }

  Future<void> _saveData() async {
    await _coffee.saveEntry(
      totalSales: totalSales,
      totalCup: totalCup,
      totalStd: totalStd,
    );
    await _refreshSummary();

    if (!mounted) return;
    CustomSnackBar.show(
      context,
      message: 'Data Coffee tersimpan',
      type: SnackType.success,
    );
  }

  Future<void> _sendWhatsApp() async {
    final phone = SharedPreferencesService().getPhoneNumber();
    if (phone == null || phone.trim().isEmpty) {
      CustomSnackBar.show(
        context,
        message: 'Nomor WhatsApp belum diatur di Settings',
        type: SnackType.error,
      );
      return;
    }

    await _saveData();
    final text = await _coffee.buildWhatsAppMessage(
      totalSales: totalSales,
      totalStd: totalStd,
      totalCup: totalCup,
      totalAdd: totalAdd,
      shiftSales: salesControllers.map((e) => e.text).toList(),
      shiftStd: stdControllers.map((e) => e.text).toList(),
      shiftApc: apcControllers.map((e) => e.text).toList(),
      shiftCup: cupControllers.map((e) => e.text).toList(),
      shiftAdd: addControllers.map((e) => e.text).toList(),
    );

    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(text)}',
    );

    try {
      FirebaseAnalytics.instance.logEvent(name: 'coffee_whatsapp_sent');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message:
            'Gagal membuka WhatsApp: ${e.toString().replaceAll('Exception: ', '')}',
        type: SnackType.error,
      );
    }
  }

  @override
  void dispose() {
    _shiftClockTimer?.cancel();
    cpdManualController.dispose();
    salesPrevManualController.dispose();
    for (int i = 0; i < CoffeeProvider.maxShift; i++) {
      salesControllers[i].dispose();
      stdControllers[i].dispose();
      apcControllers[i].dispose();
      cupControllers[i].dispose();
      addControllers[i].dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coffee = context.watch<CoffeeProvider>();
    final shiftCount = coffee.shiftCount;
    context.select<CoffeeProvider, int>((p) => p.formVersion);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProductSummaryCard(
                title: 'Akumulasi & Capaian Target',
                subtitle: 'Rangkuman penjualan & target',
                metrics: [
                  ProductMetricData(
                    label: 'Sales',
                    value: CoffeeProvider.formatRupiah(coffee.accumSalesRupiah),
                  ),
                  ProductMetricData(
                    label: 'Cup Terjual',
                    value: CoffeeProvider.formatRupiah(coffee.accumCup),
                  ),
                  ProductMetricData(
                    label: 'Achiev Target',
                    value: CoffeeProvider.formatAchievTarget(
                      coffee.achievTargetDaily,
                      coffee.achievTargetPercent,
                      coffee.hasPreviousMonthBaseline,
                    ),
                  ),
                ],
              ),
              if (coffee.historyInsight != null) ...[
                const SizedBox(height: 12),
                ProductInsightCard(
                  insight: coffee.historyInsight!,
                  onAskAi: () {
                    context.read<MainScreenProvider>().setSelectedIndex(8);
                  },
                ),
              ],
              const SizedBox(height: 8),
              ...List.generate(shiftCount, (index) {
                final raw = index < coffee.shiftLabels.length
                    ? coffee.shiftLabels[index]
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
                child: Column(
                  children: [
                    CustomInputField(
                      label: 'Sales bulan lalu',
                      controller: salesPrevManualController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [RupiahInputFormatter()],
                    ),
                    const SizedBox(height: 14),
                    CustomInputField(
                      label: 'CPD bulan lalu',
                      controller: cpdManualController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [RupiahInputFormatter()],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ActionButtons(onWhatsApp: _sendWhatsApp),
            ],
          ),
        ),
      ),
    );
  }
}
