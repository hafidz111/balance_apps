import 'package:barcode_widget/barcode_widget.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starvy/screen/widgets/ads/banner_ads.dart';

import '../../data/model/barcode_data.dart';
import '../../providers/barcode_detail_provider.dart';
import '../../service/premium_service.dart';
import '../../service/shared_preferences_service.dart';
import '../../theme/app_colors.dart';
import 'barcode_ui.dart';
import 'widgets/barcode_form.dart';

class BarcodeDetailScreen extends StatefulWidget {
  final BarcodeData barcode;

  const BarcodeDetailScreen({super.key, required this.barcode});

  @override
  State<BarcodeDetailScreen> createState() => _BarcodeDetailScreenState();
}

class _BarcodeDetailScreenState extends State<BarcodeDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<BarcodeDetailProvider>().init(widget.barcode);
  }

  void _delete() async {
    final confirm = await BarcodeUi.showDeleteBarcodeDialog(context);

    if (confirm == true) {
      await SharedPreferencesService().deleteBarcode(widget.barcode);
      if (!mounted) return;
      FirebaseAnalytics.instance.logEvent(name: "barcode_deleted");
      Navigator.pop(context, true);
    }
  }

  void _edit() async {
    final current = context.read<BarcodeDetailProvider>().current;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BarcodeForm(type: current.type, barcode: current),
      ),
    );

    if (result is BarcodeData) {
      context.read<BarcodeDetailProvider>().setCurrent(result);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = context.watch<BarcodeDetailProvider>().current;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final displayType = b.type == 'qrcode' ? 'QR Code' : 'Code 128';
    final typeStyle = BarcodeUi.typeColors(b.type);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: BarcodeUi.primaryAppBar(
        context: context,
        title: 'Detail barcode',
        actions: [
          IconButton(
            onPressed: _edit,
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit',
          ),
          IconButton(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Hapus',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                decoration: BarcodeUi.surfaceCard(context),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            typeStyle.accent.withValues(alpha: 0.16),
                            AppColors.primary.withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                b.type == 'qrcode'
                                    ? Icons.qr_code_2_rounded
                                    : Icons.onetwothree,
                                color: typeStyle.accent,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              displayType,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                              child: BarcodeWidget(
                                barcode: b.type == 'code128'
                                    ? Barcode.code128()
                                    : Barcode.qrCode(),
                                data: b.code,
                                width: double.infinity,
                                height: 100,
                                drawText: false,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildInfoSection(
                            context,
                            label: 'Kode',
                            value: b.code,
                            icon: b.type == 'qrcode'
                                ? Icons.qr_code_rounded
                                : Icons.tag_rounded,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoSection(
                            context,
                            label: 'Deskripsi',
                            value: b.description.isEmpty ? '—' : b.description,
                            icon: Icons.notes_rounded,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!PremiumService.cachedPremium)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: BannerAds(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context, {
    required String label,
    required String value,
    IconData? icon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: AppColors.primary),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: SelectableText(
                  value,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
