import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starvy/screen/widgets/custom_snack_bar.dart';
import 'package:starvy/service/shared_preferences_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/bread_provider.dart';
import '../../providers/main_screen_provider.dart';
import '../../providers/shared_preference_provider.dart';
import '../../utils/number_format.dart';
import '../widgets/action_buttons.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/product_dashboard_widgets.dart';
import '../widgets/product_insight_card.dart';

class BreadScreen extends StatefulWidget {
  const BreadScreen({super.key});

  @override
  State<BreadScreen> createState() => _BreadScreenState();
}

class _BreadScreenState extends State<BreadScreen> {
  late List<TextEditingController> salesControllers;
  late List<TextEditingController> qtyControllers;
  final akmLastMonth = TextEditingController();
  Timer? _shiftClockTimer;

  BreadProvider get _bread => context.read<BreadProvider>();

  @override
  void initState() {
    super.initState();

    salesControllers = List.generate(
      BreadProvider.maxShift,
      (_) => TextEditingController(),
    );
    qtyControllers = List.generate(
      BreadProvider.maxShift,
      (_) => TextEditingController(),
    );

    for (int i = 0; i < BreadProvider.maxShift; i++) {
      salesControllers[i].addListener(_updateSummary);
      qtyControllers[i].addListener(_updateSummary);
    }
    akmLastMonth.addListener(_updateSummary);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<BreadProvider>().initialize();
      if (mounted) await _loadDraft();
    });

    _shiftClockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final pref = context.watch<SharedPreferenceProvider>();
    final bread = context.read<BreadProvider>();
    final next = (pref.shiftCount ?? 2).clamp(1, BreadProvider.maxShift);
    if (bread.shiftCount != next) {
      bread.setShiftCount(next);
      FirebaseAnalytics.instance.logEvent(
        name: 'bread_shift_changed',
        parameters: {'shift_count': next},
      );
    }
    bread.refreshShiftLabels();
  }

  int get totalSales => _sumControllers(salesControllers);
  int get totalQty => _sumControllers(qtyControllers);

  int _sumControllers(List<TextEditingController> controllers) {
    final shiftCount = _bread.shiftCount;
    var total = 0;
    for (int i = 0; i < shiftCount; i++) {
      total += BreadProvider.parseInt(controllers[i].text);
    }
    return total;
  }

  void _updateSummary() {
    unawaited(_saveDraft());
    _bread.markFormChanged();
  }

  Future<void> _saveDraft() {
    return _bread.saveDraft(
      sales: salesControllers.map((e) => e.text).toList(),
      qty: qtyControllers.map((e) => e.text).toList(),
      akmLastMonth: akmLastMonth.text,
    );
  }

  Future<void> _loadDraft() async {
    final draft = await _bread.loadDraftForToday();
    if (draft == null || !mounted) return;

    _bread.setShiftCount(draft['shiftCount'] ?? _bread.shiftCount);
    final sales = List<String>.from(draft['sales'] ?? []);
    final qty = List<String>.from(draft['qty'] ?? []);

    for (int i = 0; i < BreadProvider.maxShift; i++) {
      if (i < sales.length) salesControllers[i].text = sales[i];
      if (i < qty.length) qtyControllers[i].text = qty[i];
    }

    akmLastMonth.text = draft['akmLastMonth'] ?? '';
    _bread.markFormChanged();
  }

  Future<void> _saveData() async {
    await _bread.saveEntry(totalSales: totalSales, totalQty: totalQty);
    await _bread.refreshSummary();

    if (!mounted) return;
    CustomSnackBar.show(
      context,
      message: 'Data Bread tersimpan',
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
    final text = await _bread.buildWhatsAppMessage(
      totalSales: totalSales,
      totalQty: totalQty,
      shiftSales: salesControllers.map((e) => e.text).toList(),
      shiftQty: qtyControllers.map((e) => e.text).toList(),
    );

    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(text)}',
    );

    try {
      FirebaseAnalytics.instance.logEvent(name: 'bread_whatsapp_sent');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message: 'Gagal membuka WhatsApp',
        type: SnackType.error,
      );
    }
  }

  @override
  void dispose() {
    _shiftClockTimer?.cancel();
    for (int i = 0; i < BreadProvider.maxShift; i++) {
      salesControllers[i].dispose();
      qtyControllers[i].dispose();
    }
    akmLastMonth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bread = context.watch<BreadProvider>();
    final shiftCount = bread.shiftCount;
    context.select<BreadProvider, int>((p) => p.formVersion);
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
                    value: BreadProvider.formatRupiah(bread.accumSalesRupiah),
                  ),
                  ProductMetricData(
                    label: 'Qty',
                    value: BreadProvider.formatRupiah(bread.accumQty),
                  ),
                ],
              ),
              if (bread.historyInsight != null) ...[
                const SizedBox(height: 12),
                ProductInsightCard(
                  insight: bread.historyInsight!,
                  onAskAi: () {
                    context.read<MainScreenProvider>().setSelectedIndex(8);
                  },
                ),
              ],
              const SizedBox(height: 8),
              ...List.generate(shiftCount, (index) {
                final raw = index < bread.shiftLabels.length
                    ? bread.shiftLabels[index]
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
              ActionButtons(onWhatsApp: _sendWhatsApp),
            ],
          ),
        ),
      ),
    );
  }
}
