import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starvy/data/shift_time_phase.dart';
import 'package:starvy/theme/app_colors.dart';
import 'package:starvy/utils/number_format.dart';

/// Latar halaman Coffee/Bread (nuansa pink lembut seperti referensi).
Color productDashboardBackground(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return Color.lerp(scheme.surface, const Color(0xFFFFF1F2), 0.85)!;
}

/// Warna aksen berbeda per shift (seperti contoh [ShiftCard] + `Colors.primaries`).
Color shiftAccentColor(int shiftIndex) {
  return Colors.primaries[shiftIndex % Colors.primaries.length];
}

class ProductSummaryCard extends StatelessWidget {
  const ProductSummaryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.metrics,
  });

  final String title;
  final String subtitle;
  final List<ProductMetricData> metrics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.95),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _ProductSummaryMetricsDividerRow(metrics: metrics),
          ],
        ),
      ),
    );
  }
}

/// Satu baris: [label / value] | divider | [label / value] | … (seperti referensi).
class _ProductSummaryMetricsDividerRow extends StatelessWidget {
  const _ProductSummaryMetricsDividerRow({required this.metrics});

  final List<ProductMetricData> metrics;

  static const double _minCellWidth = 56;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    if (m.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final lineColor = scheme.outlineVariant.withValues(alpha: 0.55);

    Widget columnCell(int i) {
      final cap = m[i].caption;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              m[i].label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            if (cap != null && cap.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                cap,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w400,
                  fontSize: 10,
                  height: 1.25,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              m[i].value,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.25,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final perCell = (available - (m.length - 1)) / m.length;
        final useScroll = perCell < _minCellWidth;

        if (useScroll) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < m.length; i++) ...[
                    SizedBox(width: 76, child: columnCell(i)),
                    if (i < m.length - 1)
                      VerticalDivider(width: 1, thickness: 1, color: lineColor),
                  ],
                ],
              ),
            ),
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < m.length; i++) ...[
                Expanded(child: columnCell(i)),
                if (i < m.length - 1)
                  VerticalDivider(width: 1, thickness: 1, color: lineColor),
              ],
            ],
          ),
        );
      },
    );
  }
}

class ProductMetricData {
  const ProductMetricData({
    required this.label,
    required this.value,
    this.caption,
  });

  final String label;
  final String value;

  /// Teks kecil di bawah label, mis. penjelasan akumulasi.
  final String? caption;
}

/// Baris input shift seperti referensi: ikon + label + field kanan (tanpa stepper).
class ProductShiftInputRow extends StatelessWidget {
  const ProductShiftInputRow({
    super.key,
    required this.label,
    required this.controller,
    required this.leadingIcon,
    required this.iconColor,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.readOnly = false,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final IconData leadingIcon;
  final Color iconColor;
  final TextInputType keyboardType;
  final bool enabled;
  final bool readOnly;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final rowCardColor = Theme.of(context).brightness == Brightness.dark
        ? scheme.surface
        : Colors.white;

    final labelColor = scheme.onSurface.withValues(alpha: 0.88);
    final isFillable = enabled && !readOnly;

    const fieldFill = Colors.white;

    final fieldBorder = isFillable
        ? scheme.primary.withValues(alpha: 0.32)
        : scheme.outlineVariant.withValues(alpha: 0.6);

    final valueColor = readOnly
        ? scheme.onSurface.withValues(alpha: 0.5)
        : (isFillable
              ? scheme.onSurface
              : scheme.onSurface.withValues(alpha: 0.62));

    final valueStyle = textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: valueColor,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
        color: rowCardColor,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(leadingIcon, size: 24, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            flex: 11,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 14,
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                return Container(
                  decoration: BoxDecoration(
                    color: fieldFill,
                    borderRadius: BorderRadius.circular(10),
                    border: readOnly ? null : Border.all(color: fieldBorder),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  alignment: Alignment.centerRight,
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    enabled: readOnly ? false : enabled,
                    readOnly: readOnly,
                    inputFormatters: readOnly ? null : inputFormatters,
                    textAlign: TextAlign.end,
                    textAlignVertical: TextAlignVertical.center,
                    style: valueStyle,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isCollapsed: true,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProductShiftCard extends StatelessWidget {
  const ProductShiftCard({
    super.key,
    required this.shiftIndex,
    required this.subtitle,
    required this.shiftPhase,
    required this.child,
    this.accentColor,
  });

  final int shiftIndex;
  final String subtitle;

  final ShiftTimePhase shiftPhase;
  final Widget child;

  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accent = accentColor ?? shiftAccentColor(shiftIndex);

    final cardBg = Theme.of(context).brightness == Brightness.dark
        ? scheme.surface
        : Colors.white;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(19),
                topRight: Radius.circular(19),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shift ${shiftIndex + 1}',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle.isEmpty ? '—' : subtitle,
                            style: textTheme.bodySmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: switch (shiftPhase) {
                          ShiftTimePhase.aktif => Colors.green.withValues(
                            alpha: 0.22,
                          ),
                          ShiftTimePhase.selesai => Colors.orange.withValues(
                            alpha: 0.2,
                          ),
                          ShiftTimePhase.belumAktif =>
                            scheme.surface.withValues(alpha: 0.72),
                        },
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: switch (shiftPhase) {
                            ShiftTimePhase.aktif => Colors.green.withValues(
                              alpha: 0.45,
                            ),
                            ShiftTimePhase.selesai => Colors.orange.withValues(
                              alpha: 0.5,
                            ),
                            ShiftTimePhase.belumAktif =>
                              scheme.outlineVariant.withValues(alpha: 0.5),
                          },
                        ),
                      ),
                      child: Text(
                        switch (shiftPhase) {
                          ShiftTimePhase.aktif => 'Aktif',
                          ShiftTimePhase.selesai => 'Selesai',
                          ShiftTimePhase.belumAktif => 'Belum aktif',
                        },
                        style: textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: switch (shiftPhase) {
                            ShiftTimePhase.aktif => Colors.green.shade800,
                            ShiftTimePhase.selesai => Colors.orange.shade900,
                            ShiftTimePhase.belumAktif =>
                              scheme.onSurfaceVariant,
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class DashboardInlineRupiahField extends StatelessWidget {
  const DashboardInlineRupiahField({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
    );

    return SizedBox(
      width: 132,
      child: TextField(
        controller: controller,
        enabled: enabled,
        textAlign: TextAlign.end,
        keyboardType: TextInputType.number,
        inputFormatters: [RupiahInputFormatter()],
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          filled: true,
          fillColor: Colors.white,
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: scheme.primary, width: 1.5),
          ),
          disabledBorder: border,
        ),
      ),
    );
  }
}

class DashboardMetricRow extends StatelessWidget {
  const DashboardMetricRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withValues(alpha: 0.88),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ),
    );
  }
}
