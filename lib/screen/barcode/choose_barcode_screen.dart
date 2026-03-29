import 'package:flutter/material.dart';
import 'package:starvy/theme/app_colors.dart';

import 'barcode_ui.dart';
import 'widgets/barcode_form.dart';

class ChooseBarcodeScreen extends StatelessWidget {
  const ChooseBarcodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: BarcodeUi.primaryAppBar(
        context: context,
        title: 'Pilih jenis barcode',
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Pilih format sebelum mengisi kode. Keduanya bisa disimpan di daftar barcode.',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            _buildBarcodeCard(
              context: context,
              title: 'Code 128',
              subtitle: 'Hingga 80 karakter ASCII (contoh: ABC123)',
              type: 'code128',
              icon: Icons.onetwothree,
              accent: AppColors.barcodeNeutralDark,
            ),
            const SizedBox(height: 14),
            _buildBarcodeCard(
              context: context,
              title: 'QR Code',
              subtitle: 'Hingga ~1K karakter UTF-8 (teks panjang)',
              type: 'qrcode',
              icon: Icons.qr_code_2_rounded,
              accent: AppColors.barcodeQrBlue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarcodeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String type,
    required IconData icon,
    required Color accent,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BarcodeForm(type: type)),
          );

          if (result != null && context.mounted) {
            Navigator.pop(context, true);
          }
        },
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BarcodeUi.surfaceCard(context),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withValues(alpha: 0.22)),
                  ),
                  child: Icon(icon, size: 36, color: accent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
