import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starvy/providers/history_provider.dart';

import '../../data/model/coffee_history.dart';
import '../../data/model/bread_history.dart';
import '../../service/shared_preferences_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_format.dart';
import '../../utils/number_format.dart';
import '../../utils/stale_history_cleanup.dart';
import 'widgets/coffee_dialog.dart';
import 'widgets/bread_dialog.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const int _pageSize = 10;

  final _prefsService = SharedPreferencesService();

  final ScrollController _coffeeScrollController = ScrollController();
  final ScrollController _breadScrollController = ScrollController();

  int _coffeeVisibleCount = _pageSize;
  int _breadVisibleCount = _pageSize;

  String? _lastPaginationKey;

  Timer? _coffeeScrollDebounce;
  Timer? _breadScrollDebounce;

  @override
  void initState() {
    super.initState();
    _coffeeScrollController.addListener(_onCoffeeScroll);
    _breadScrollController.addListener(_onBreadScroll);
    _checkMonthChange();
    Future.microtask(() => context.read<HistoryProvider>().loadHistory());
  }

  @override
  void dispose() {
    _coffeeScrollDebounce?.cancel();
    _breadScrollDebounce?.cancel();
    _coffeeScrollController.removeListener(_onCoffeeScroll);
    _breadScrollController.removeListener(_onBreadScroll);
    _coffeeScrollController.dispose();
    _breadScrollController.dispose();
    super.dispose();
  }

  void _onCoffeeScroll() {
    _coffeeScrollDebounce?.cancel();
    _coffeeScrollDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || !_coffeeScrollController.hasClients) return;
      final pos = _coffeeScrollController.position;
      if (pos.maxScrollExtent <= 0) return;
      if (pos.pixels < pos.maxScrollExtent - 100) return;

      final total = context.read<HistoryProvider>().pcHistory.length;
      if (_coffeeVisibleCount >= total) return;

      setState(() {
        final next = _coffeeVisibleCount + _pageSize;
        _coffeeVisibleCount = next > total ? total : next;
      });
    });
  }

  void _onBreadScroll() {
    _breadScrollDebounce?.cancel();
    _breadScrollDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || !_breadScrollController.hasClients) return;
      final pos = _breadScrollController.position;
      if (pos.maxScrollExtent <= 0) return;
      if (pos.pixels < pos.maxScrollExtent - 100) return;

      final total = context.read<HistoryProvider>().sbHistory.length;
      if (_breadVisibleCount >= total) return;

      setState(() {
        final next = _breadVisibleCount + _pageSize;
        _breadVisibleCount = next > total ? total : next;
      });
    });
  }

  void _syncPaginationKey(HistoryProvider hp) {
    final key =
        '${hp.activeTab}_${hp.selectedMonthYear.year}_${hp.selectedMonthYear.month}';
    if (_lastPaginationKey != key) {
      _lastPaginationKey = key;
      _coffeeVisibleCount = _pageSize;
      _breadVisibleCount = _pageSize;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_coffeeScrollController.hasClients) {
          _coffeeScrollController.jumpTo(0);
        }
        if (_breadScrollController.hasClients) {
          _breadScrollController.jumpTo(0);
        }
      });
    }
  }

  void _expandCoffeeIfNoScroll() {
    if (!mounted) return;
    final total = context.read<HistoryProvider>().pcHistory.length;
    if (_coffeeVisibleCount >= total) return;
    if (!_coffeeScrollController.hasClients) return;
    if (_coffeeScrollController.position.maxScrollExtent > 8) return;

    setState(() {
      final next = _coffeeVisibleCount + _pageSize;
      _coffeeVisibleCount = next > total ? total : next;
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _expandCoffeeIfNoScroll(),
    );
  }

  void _expandBreadIfNoScroll() {
    if (!mounted) return;
    final total = context.read<HistoryProvider>().sbHistory.length;
    if (_breadVisibleCount >= total) return;
    if (!_breadScrollController.hasClients) return;
    if (_breadScrollController.position.maxScrollExtent > 8) return;

    setState(() {
      final next = _breadVisibleCount + _pageSize;
      _breadVisibleCount = next > total ? total : next;
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _expandBreadIfNoScroll(),
    );
  }

  Future<void> _checkMonthChange() async {
    if (!mounted) return;
    await promptStaleHistoryCleanup(context);
  }

  Future<void> _loadHistory() async {
    await context.read<HistoryProvider>().loadHistory();
  }

  Future<void> _deleteCoffee(CoffeeHistory data) async {
    final ok = await _showModernConfirmDialog(
      title: 'Hapus data?',
      message: 'Entri history Coffee ini akan dihapus permanen dari perangkat.',
      icon: Icons.delete_outline_rounded,
      iconColor: Colors.red[700]!,
      iconBgColor: Colors.red.withValues(alpha: 0.12),
      confirmLabel: 'Hapus',
      confirmIsPrimary: false,
    );

    if (ok == true) {
      await _prefsService.deleteCoffee(data.tgl);
      _loadHistory();
    }

    FirebaseAnalytics.instance.logEvent(name: "coffee_deleted");
  }

  Future<void> _deleteBread(BreadHistory data) async {
    final ok = await _showModernConfirmDialog(
      title: 'Hapus data?',
      message: 'Entri history Bread ini akan dihapus permanen dari perangkat.',
      icon: Icons.delete_outline_rounded,
      iconColor: Colors.red[700]!,
      iconBgColor: Colors.red.withValues(alpha: 0.12),
      confirmLabel: 'Hapus',
      confirmIsPrimary: false,
    );

    if (ok == true) {
      await _prefsService.deleteBread(data.tgl);
      _loadHistory();
    }

    FirebaseAnalytics.instance.logEvent(name: "bread_deleted");
  }

  Future<void> _editCoffee(CoffeeHistory data) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => CoffeeDialog(editData: data),
    );

    if (result == true) {
      _loadHistory();
    }
    FirebaseAnalytics.instance.logEvent(name: "coffee_edit");
  }

  Future<void> _editBread(BreadHistory data) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => BreadDialog(editData: data),
    );

    if (result == true) {
      _loadHistory();
    }
    FirebaseAnalytics.instance.logEvent(name: "bread_edit");
  }

  Future<void> _deleteAllData() async {
    final historyProvider = context.read<HistoryProvider>();
    final activeTab = historyProvider.activeTab;
    final ok = await _showModernConfirmDialog(
      title: 'Hapus semua data?',
      message: activeTab == 0
          ? 'Semua entri history Coffee untuk filter bulan ini akan dihapus.'
          : 'Semua entri history Bread untuk filter bulan ini akan dihapus.',
      icon: Icons.delete_forever_rounded,
      iconColor: Colors.red[700]!,
      iconBgColor: Colors.red.withValues(alpha: 0.12),
      confirmLabel: 'Hapus semua',
      confirmIsPrimary: false,
    );

    if (ok == true) {
      if (activeTab == 0) {
        await _prefsService.clearCoffee();
      } else {
        await _prefsService.clearBread();
      }

      await historyProvider.loadHistory();
    }

    FirebaseAnalytics.instance.logEvent(
      name: "history_delete_all",
      parameters: {"tab": activeTab == 0 ? "coffee" : "bread"},
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyProvider = context.watch<HistoryProvider>();
    _syncPaginationKey(historyProvider);
    final activeTab = historyProvider.activeTab;
    final selectedMonthYear = historyProvider.selectedMonthYear;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (activeTab == 0) {
        _expandCoffeeIfNoScroll();
      } else {
        _expandBreadIfNoScroll();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildTabItem("Coffee", 0),
                    _buildTabItem("Bread", 1),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showManualInputDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text("Tambah Data Manual"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: IconButton(
                      onPressed: _deleteAllData,
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                    ),
                  ),

                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: IconButton(
                      onPressed: () async {
                        final picked = await showMonthYearPicker(
                          context,
                          selectedMonthYear,
                        );
                        if (picked != null) {
                          await context
                              .read<HistoryProvider>()
                              .setSelectedMonthYear(picked);
                        }
                      },
                      icon: const Icon(
                        Icons.calendar_month,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: activeTab == 0
                    ? _buildCoffeeHistory()
                    : _buildBreadHistory(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(String title, int index) {
    final activeTab = context.select<HistoryProvider, int>(
      (provider) => provider.activeTab,
    );
    bool isActive = activeTab == index;
    FirebaseAnalytics.instance.logEvent(
      name: "history_tab_changed",
      parameters: {"tab": index == 0 ? "coffee" : "bread"},
    );

    return Expanded(
      child: GestureDetector(
        onTap: () => context.read<HistoryProvider>().setActiveTab(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    const BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showModernConfirmDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String confirmLabel,
    required bool confirmIsPrimary,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
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
                          color: iconBgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: iconColor, size: 28),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message,
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
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: confirmIsPrimary
                                ? AppColors.primary
                                : Colors.red.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            confirmLabel,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
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

  Future<DateTime?> showMonthYearPicker(
    BuildContext context,
    DateTime initialDate,
  ) {
    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        int selectedYear = initialDate.year;
        int selectedMonth = initialDate.month;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final scheme = Theme.of(context).colorScheme;
            final months = [
              "Semua",
              "Jan",
              "Feb",
              "Mar",
              "Apr",
              "Mei",
              "Jun",
              "Jul",
              "Agu",
              "Sep",
              "Okt",
              "Nov",
              "Des",
            ];

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 28,
              ),
              backgroundColor: scheme.surface,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.2),
                            AppColors.primary.withValues(alpha: 0.06),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 8, 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.calendar_month_rounded,
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
                                    'Filter periode',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Pilih tahun & bulan untuk daftar history',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: IconButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: Icon(
                                Icons.close_rounded,
                                size: 22,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: (MediaQuery.sizeOf(context).height * 0.62)
                            .clamp(240.0, 560.0),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Tahun',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Material(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    _buildNavButton(
                                      icon: Icons.chevron_left_rounded,
                                      onTap: () =>
                                          setDialogState(() => selectedYear--),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onHorizontalDragEnd: (details) {
                                          if (details.primaryVelocity == null) {
                                            return;
                                          }
                                          if (details.primaryVelocity! > 0) {
                                            setDialogState(
                                              () => selectedYear--,
                                            );
                                          } else if (details.primaryVelocity! <
                                              0) {
                                            setDialogState(
                                              () => selectedYear++,
                                            );
                                          }
                                        },
                                        child: Text(
                                          '$selectedYear',
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.5,
                                                color: AppColors.primaryDark,
                                              ),
                                        ),
                                      ),
                                    ),
                                    _buildNavButton(
                                      icon: Icons.chevron_right_rounded,
                                      onTap: () =>
                                          setDialogState(() => selectedYear++),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'Bulan',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 2.35,
                                  ),
                              itemCount: 13,
                              itemBuilder: (context, index) {
                                final isSelected = selectedMonth == index;
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => setDialogState(
                                      () => selectedMonth = index,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary
                                            : scheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : scheme.outlineVariant
                                                    .withValues(alpha: 0.6),
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.28),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Text(
                                        months[index],
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : scheme.onSurface,
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.pop(
                                  dialogContext,
                                  DateTime(selectedYear, selectedMonth),
                                );
                                FirebaseAnalytics.instance.logEvent(
                                  name: "history_filter_applied",
                                  parameters: {
                                    "year": selectedYear,
                                    "month": selectedMonth,
                                  },
                                );
                              },
                              icon: const Icon(Icons.check_rounded, size: 22),
                              label: const Text(
                                'Terapkan filter',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 52),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return IconButton.filledTonal(
      onPressed: onTap,
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 24, color: AppColors.primaryDark),
    );
  }

  void _showManualInputDialog() async {
    final activeTab = context.read<HistoryProvider>().activeTab;
    FirebaseAnalytics.instance.logEvent(
      name: "history_manual_input_opened",
      parameters: {"tab": activeTab == 0 ? "coffee" : "bread"},
    );

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return activeTab == 0
            ? const CoffeeDialog()
            : const BreadDialog();
      },
    );

    if (result == true) {
      _loadHistory();
    }
  }

  Widget _buildCoffeeHistory() {
    final pcHistory = context.select<HistoryProvider, List<CoffeeHistory>>(
      (provider) => provider.pcHistory,
    );
    if (pcHistory.isEmpty) {
      return _emptyView(context);
    }

    final total = pcHistory.length;
    final visible = _coffeeVisibleCount.clamp(0, total);
    final slice = pcHistory.sublist(0, visible);
    final hasMore = visible < total;

    return ListView.builder(
      controller: _coffeeScrollController,
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: slice.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasMore && index == slice.length) {
          return _paginationFooter(context, loaded: visible, total: total);
        }
        final data = slice[index];
        return _modernHistoryCard(
          context: context,
          headerTitle: formatDate(data.tgl),
          menu: _historyPopupMenu(
            onEdit: () => _editCoffee(data),
            onDelete: () => _deleteCoffee(data),
          ),
          stats: [
            ("SPD", data.spd.toMillion()),
            ("CUP", data.cup.toString()),
            ("AKM CUP", data.akmCup.toString()),
            ("CPD", _truncateToTwoDecimals(data.cpd)),
          ],
        );
      },
    );
  }

  Widget _buildBreadHistory() {
    final sbHistory = context.select<HistoryProvider, List<BreadHistory>>(
      (provider) => provider.sbHistory,
    );
    if (sbHistory.isEmpty) {
      return _emptyView(context);
    }

    final total = sbHistory.length;
    final visible = _breadVisibleCount.clamp(0, total);
    final slice = sbHistory.sublist(0, visible);
    final hasMore = visible < total;

    return ListView.builder(
      controller: _breadScrollController,
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: slice.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasMore && index == slice.length) {
          return _paginationFooter(context, loaded: visible, total: total);
        }
        final data = slice[index];
        return _modernHistoryCard(
          context: context,
          headerTitle: "Tanggal: ${formatDate(data.tgl)}",
          menu: _historyPopupMenu(
            onEdit: () => _editBread(data),
            onDelete: () => _deleteBread(data),
          ),
          stats: [
            ("Qty", data.qty.toString()),
            ("AKM QTY", data.akmQty.toString()),
            ("SPD", data.sales.toString()),
            ("Total Sales", data.akmSales.toString()),
            ("Average", data.average.toStringAsFixed(2)),
          ],
        );
      },
    );
  }

  Widget _paginationFooter(
    BuildContext context, {
    required int loaded,
    required int total,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.south_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Menampilkan $loaded dari $total — gulir untuk memuat berikutnya',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyPopupMenu({
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return PopupMenuButton<String>(
      tooltip: 'Opsi',
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              const Text('Edit'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: Colors.red[700]),
              const SizedBox(width: 10),
              Text('Hapus', style: TextStyle(color: Colors.red[700])),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'edit') {
          onEdit();
        } else if (value == 'delete') {
          onDelete();
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(Icons.more_horiz_rounded, color: AppColors.primaryDark),
      ),
    );
  }

  Widget _modernHistoryCard({
    required BuildContext context,
    required String headerTitle,
    required Widget menu,
    required List<(String, String)> stats,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: scheme.surface,
        elevation: 0,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.07),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.12),
                        AppColors.primary.withValues(alpha: 0.03),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.event_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            headerTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        menu,
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                  child: Column(
                    children: [
                      for (var i = 0; i < stats.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _modernStatRow(context, stats[i].$1, stats[i].$2),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modernStatRow(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.primaryDark,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _truncateToTwoDecimals(num value) {
    final truncated = value >= 0
        ? (value * 100).floor() / 100
        : (value * 100).ceil() / 100;
    return truncated.toStringAsFixed(2);
  }

  Widget _emptyView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_rounded,
              size: 40,
              color: AppColors.primary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada data history',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Data akan muncul setelah ada entri di periode ini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
