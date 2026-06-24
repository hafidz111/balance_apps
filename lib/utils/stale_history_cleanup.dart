import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/history_provider.dart';
import '../service/shared_preferences_service.dart';
import 'date_format.dart';

/// Tawarkan hapus history bulan yang sudah lewat (lebih tua dari bulan lalu).
Future<void> promptStaleHistoryCleanup(BuildContext context) async {
  if (!context.mounted) return;

  final prefs = SharedPreferencesService();
  final staleMonths = await prefs.getStaleHistoryMonths();

  if (staleMonths.isEmpty) {
    if (await prefs.isNewMonth()) {
      await prefs.updateCurrentMonth();
    }
    return;
  }

  var deletedAny = false;

  for (final ym in staleMonths) {
    if (!context.mounted) return;

    final monthLabel = formatMonthYear(ym.year, ym.month);
    final coffeeEntries = await prefs.getCoffeeByMonth(ym.year, ym.month);
    final breadEntries = await prefs.getBreadByMonth(ym.year, ym.month);

    if (coffeeEntries.isEmpty && breadEntries.isEmpty) continue;

    final detail = <String>[];
    if (coffeeEntries.isNotEmpty) {
      detail.add('Coffee: ${coffeeEntries.length} hari');
    }
    if (breadEntries.isNotEmpty) {
      detail.add('Bread: ${breadEntries.length} hari');
    }

    final confirm = await _confirmDeleteMonth(
      context,
      monthLabel: monthLabel,
      detail: detail.join('\n'),
    );

    if (confirm != true) return;

    if (coffeeEntries.isNotEmpty) {
      await prefs.deleteCoffeeByMonth(ym.year, ym.month);
    }
    if (breadEntries.isNotEmpty) {
      await prefs.deleteBreadByMonth(ym.year, ym.month);
    }

    deletedAny = true;

    FirebaseAnalytics.instance.logEvent(
      name: 'stale_history_month_deleted',
      parameters: {'year': ym.year, 'month': ym.month},
    );
  }

  if (!context.mounted) return;

  final remaining = await prefs.getStaleHistoryMonths();
  if (remaining.isEmpty) {
    if (await prefs.isNewMonth()) {
      await prefs.updateCurrentMonth();
    }
  }

  if (deletedAny) {
    try {
      await context.read<HistoryProvider>().loadHistory();
    } catch (_) {}

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data bulan lama berhasil dihapus')),
      );
    }
  }
}

Future<bool?> _confirmDeleteMonth(
  BuildContext context, {
  required String monthLabel,
  required String detail,
}) {
  final scheme = Theme.of(context).colorScheme;

  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.orange[800],
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Hapus data $monthLabel?',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'History $monthLabel masih tersimpan.\n'
                      'Hanya bulan lalu dan bulan berjalan yang dipertahankan.\n\n'
                      '$detail',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Nanti'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Hapus'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
