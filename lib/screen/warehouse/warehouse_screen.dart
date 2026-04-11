import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../data/model/warehouse_transaction.dart';
import '../../providers/warehouse_provider.dart';
import '../../theme/app_colors.dart';
import '../../service/shared_preferences_service.dart';
import '../scanner/scanner_screen.dart';
import '../widgets/custom_snack_bar.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFabExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(() => context.read<WarehouseProvider>().load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openScanner(String transactionType) async {
    setState(() => _isFabExpanded = false);

    FirebaseAnalytics.instance.logEvent(
      name: 'warehouse_scan_opened',
      parameters: {'type': transactionType},
    );

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WarehouseScannerScreen(transactionType: transactionType),
      ),
    );

    if (result != null && mounted) {
      await context.read<WarehouseProvider>().load();
    }
  }

  Future<void> _confirmClear() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus semua transaksi?'),
        content: const Text(
          'Semua data transaksi gudang akan dihapus permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<WarehouseProvider>().clearAll();
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Semua transaksi dihapus',
          type: SnackType.success,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WarehouseProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _SummaryHeader(
                  totalMasuk: provider.totalMasuk,
                  totalKeluar: provider.totalKeluar,
                  netStok: provider.netStok,
                  itemCount: provider.currentStockCount,
                ),
                Container(
                  color: scheme.surface,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: scheme.onSurfaceVariant,
                    indicatorColor: AppColors.primary,
                    tabs: const [
                      Tab(text: 'Stok'),
                      Tab(text: 'Masuk'),
                      Tab(text: 'Keluar'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      const _StokList(),
                      _TransactionList(
                        transactions: provider.transactions
                            .where((t) => t.type == 'masuk')
                            .toList(),
                        onDelete: (id) => context
                            .read<WarehouseProvider>()
                            .deleteTransaction(id),
                      ),
                      _TransactionList(
                        transactions: provider.transactions
                            .where((t) => t.type == 'keluar')
                            .toList(),
                        onDelete: (id) => context
                            .read<WarehouseProvider>()
                            .deleteTransaction(id),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isFabExpanded) ...[
            if (provider.transactions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FloatingActionButton.extended(
                  heroTag: 'wh_clear',
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  icon: const Icon(Icons.delete_sweep_rounded),
                  label: const Text(
                    'Hapus Semua',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: () {
                    setState(() => _isFabExpanded = false);
                    _confirmClear();
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton.extended(
                heroTag: 'wh_keluar',
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red.shade700,
                icon: const Icon(Icons.arrow_upward_rounded),
                label: const Text(
                  'Barang Keluar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () => _openScanner('keluar'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FloatingActionButton.extended(
                heroTag: 'wh_masuk',
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.arrow_downward_rounded),
                label: const Text(
                  'Barang Masuk',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () => _openScanner('masuk'),
              ),
            ),
          ],

          FloatingActionButton(
            heroTag: 'wh_main_fab',
            backgroundColor: _isFabExpanded
                ? Colors.grey.shade300
                : AppColors.primary,
            foregroundColor: _isFabExpanded ? Colors.black : Colors.white,
            onPressed: () => setState(() => _isFabExpanded = !_isFabExpanded),
            child: Icon(
              _isFabExpanded ? Icons.close : Icons.qr_code_scanner_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final int totalMasuk;
  final int totalKeluar;
  final int netStok;
  final int itemCount;

  const _SummaryHeader({
    required this.totalMasuk,
    required this.totalKeluar,
    required this.netStok,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'Masuk',
              value: totalMasuk,
              icon: Icons.arrow_downward_rounded,
              color: AppColors.primary,
              bgColor: AppColors.primary.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              label: 'Keluar',
              value: totalKeluar,
              icon: Icons.arrow_upward_rounded,
              color: Colors.red.shade600,
              bgColor: Colors.red.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              label: 'Stok',
              value: netStok,
              icon: Icons.inventory_2_rounded,
              color: netStok >= 0
                  ? Colors.teal.shade700
                  : Colors.orange.shade700,
              bgColor: (netStok >= 0 ? Colors.teal : Colors.orange).withValues(
                alpha: 0.1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              label: 'Jml Barang',
              value: itemCount,
              icon: Icons.category_rounded,
              color: AppColors.primaryDark,
              bgColor: AppColors.primaryLight.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StokList extends StatefulWidget {
  const _StokList();

  @override
  State<_StokList> createState() => _StokListState();
}

class _StokListState extends State<_StokList> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WarehouseProvider>();
    final barcodesList = provider.barcodes;

    final stockMap = <String, int>{};
    for (final tx in provider.transactions) {
      if (tx.type == 'masuk') {
        stockMap[tx.barcodeCode] =
            (stockMap[tx.barcodeCode] ?? 0) + tx.quantity;
      } else {
        stockMap[tx.barcodeCode] =
            (stockMap[tx.barcodeCode] ?? 0) - tx.quantity;
      }
    }

    var stockEntries = stockMap.entries.where((e) => e.value > 0).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      stockEntries = stockEntries.where((e) {
        final found = barcodesList.where((b) => b.code == e.key).firstOrNull;
        final desc = (found?.description ?? '').toLowerCase();
        return e.key.toLowerCase().contains(q) || desc.contains(q);
      }).toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Cari barcode atau nama barang...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        Expanded(
          child: stockEntries.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? 'Barang tidak ditemukan.'
                        : 'Tidak ada stok barang.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: stockEntries.length,
                  itemBuilder: (ctx, i) {
                    final code = stockEntries[i].key;
                    final qty = stockEntries[i].value;
                    final found = barcodesList
                        .where((b) => b.code == code)
                        .firstOrNull;
                    final desc = found?.description ?? '';
                    final type = found?.type ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.teal.shade700.withValues(alpha: 0.18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              type.toLowerCase() == 'qrcode' ? Icons.qr_code_2 :
                              type.toLowerCase() == 'code128' ? Icons.onetwothree :
                              Icons.inventory_2_rounded,
                              color: Colors.teal.shade700,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  desc.isNotEmpty ? desc : code,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              qty.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Colors.teal.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TransactionList extends StatelessWidget {
  final List<WarehouseTransaction> transactions;
  final void Function(String id) onDelete;

  const _TransactionList({required this.transactions, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Belum ada transaksi',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: transactions.length,
      itemBuilder: (context, i) {
        final t = transactions[i];
        return _TransactionTile(transaction: t, onDelete: onDelete);
      },
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WarehouseTransaction transaction;
  final void Function(String id) onDelete;

  const _TransactionTile({required this.transaction, required this.onDelete});

  void _showOutboundOptions(BuildContext context) async {
    final isMasuk = transaction.type == 'masuk';
    if (!isMasuk) return;

    final provider = context.read<WarehouseProvider>();
    final currentStok = provider.netStokFor(transaction.barcodeCode);

    if (currentStok <= 0) {
      CustomSnackBar.show(
        context,
        message: 'Stok barang sudah habis',
        type: SnackType.error,
      );
      return;
    }

    final qtyController = TextEditingController(text: '1');
    final reasonController = TextEditingController();
    String selectedReason = 'Kadaluarsa';

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final scheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.orange.withValues(alpha: 0.2),
                            Colors.orange.withValues(alpha: 0.06),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 8, 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.output_rounded,
                                color: Colors.orange,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Keluarkan Barang',
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
                                    'Stok tersedia: $currentStok',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: IconButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: Icon(
                                Icons.close_rounded,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  transaction.barcodeType?.toLowerCase() == 'qrcode' ? Icons.qr_code_2 :
                                  transaction.barcodeType?.toLowerCase() == 'code128' ? Icons.onetwothree :
                                  transaction.barcodeDescription.isNotEmpty 
                                      ? Icons.description_rounded 
                                      : Icons.qr_code_rounded,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    transaction.barcodeDescription.isNotEmpty 
                                        ? transaction.barcodeDescription 
                                        : transaction.barcodeCode,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (transaction.barcodeType != null && transaction.barcodeType!.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      transaction.barcodeType!,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal.shade700),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: qtyController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Jumlah Keluar',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: selectedReason,
                            decoration: InputDecoration(
                              labelText: 'Alasan Barang Keluar',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items:
                                [
                                      'Kadaluarsa',
                                      'Rusak',
                                      'Hilang',
                                      'Konsumsi Internal',
                                      'Retur',
                                      'Pindah Stok',
                                      'Lainnya',
                                    ]
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) =>
                                setState(() => selectedReason = v!),
                          ),
                          if (selectedReason == 'Lainnya') ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: reasonController,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                labelText: 'Keterangan Lainnya',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text('Batal'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: FilledButton.icon(
                                  onPressed: () {
                                    if (selectedReason == 'Lainnya' &&
                                        reasonController.text.trim().isEmpty) {
                                      CustomSnackBar.show(
                                        context,
                                        message: 'Alasan wajib diisi!',
                                        type: SnackType.error,
                                      );
                                      return;
                                    }
                                    Navigator.pop(ctx, true);
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.orange.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.check_rounded,
                                    size: 20,
                                  ),
                                  label: const Text(
                                    'Simpan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
      },
    );

    if (confirm == true && context.mounted) {
      final qty = int.tryParse(qtyController.text) ?? 1;
      if (qty > 0) {
        if (qty > currentStok) {
          CustomSnackBar.show(
            context,
            message: 'Jumlah keluar $qty melebihi stok $currentStok!',
            type: SnackType.error,
          );
          return;
        }
        await context.read<WarehouseProvider>().addTransactionFromScan(
          code: transaction.barcodeCode,
          transactionType: 'keluar',
          quantity: qty,
          reason: selectedReason == 'Lainnya'
              ? reasonController.text.trim()
              : selectedReason,
        );
        if (context.mounted) {
          CustomSnackBar.show(
            context,
            message: 'Berhasil mencatat barang keluar',
            type: SnackType.success,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMasuk = transaction.type == 'masuk';
    final color = isMasuk ? AppColors.primary : Colors.red.shade600;
    final bgColor = isMasuk
        ? AppColors.primary.withValues(alpha: 0.08)
        : Colors.red.withValues(alpha: 0.07);

    final time = _formatTime(transaction.timestamp);

    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
      ),
      onDismissed: (_) => onDelete(transaction.id),
      child: GestureDetector(
        onTap: () {
          if (isMasuk) _showOutboundOptions(context);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isMasuk
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.barcodeDescription.isNotEmpty
                          ? transaction.barcodeDescription
                          : transaction.barcodeCode,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (transaction.barcodeType != null && transaction.barcodeType!.isNotEmpty)
                      Text(
                        transaction.barcodeType!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (transaction.reason != null &&
                        transaction.reason!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          transaction.reason!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isMasuk
                          ? '+${transaction.quantity}'
                          : '-${transaction.quantity}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isMasuk ? 'Masuk' : 'Keluar',
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class WarehouseScannerScreen extends StatefulWidget {
  final String transactionType;

  const WarehouseScannerScreen({super.key, required this.transactionType});

  @override
  State<WarehouseScannerScreen> createState() => _WarehouseScannerScreenState();
}

class _WarehouseScannerScreenState extends State<WarehouseScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController cameraController = MobileScannerController();
  late AnimationController _animationController;

  int _scanCount = 0;
  String? _lastCode;
  bool _isScanning = false;

  bool get isMasuk => widget.transactionType == 'masuk';

  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      if (mounted) setState(() => _hasPermission = true);
      return;
    }

    final request = await Permission.camera.request();
    if (request.isGranted && mounted) {
      setState(() => _hasPermission = true);
    }
  }

  Future<void> _handleScan(String code, BarcodeFormat format) async {
    if (_isScanning) return;
    setState(() => _isScanning = true);

    try {
      await cameraController.stop();
    } catch (_) {}

    final service = SharedPreferencesService();
    final freshBarcodes = await service.getBarcodes();
    final formattedCode = code.trim();

    final foundInfo = freshBarcodes
        .where((b) => b.code.trim() == formattedCode)
        .firstOrNull;
    final desc = foundInfo?.description ?? '';
    
    String scannedType = format.name.toLowerCase();
    if (format == BarcodeFormat.qrCode) scannedType = 'qrcode';
    
    final type = (foundInfo != null && foundInfo.type.isNotEmpty) ? foundInfo.type : scannedType;
    final defaultQty = foundInfo?.jumlah;

    final result = await _showQuantityDialog(formattedCode, desc, defaultQty, type);

    if (result != null && result.$1 > 0 && mounted) {
      await context.read<WarehouseProvider>().addTransactionFromScan(
        code: formattedCode,
        transactionType: widget.transactionType,
        quantity: result.$1,
        reason: result.$2,
      );

      setState(() {
        _scanCount += result.$1;
        _lastCode = code;
      });

      if (mounted) {
        CustomSnackBar.show(
          context,
          message: '${isMasuk ? "Masuk" : "Keluar"}: $code (+${result.$1})',
          type: SnackType.success,
        );
      }
    }

    if (mounted) {
      setState(() => _isScanning = false);
      try {
        await cameraController.start();
      } catch (_) {}
    }
  }

  Future<(int, String?)?> _showQuantityDialog(
    String code,
    String desc,
    int? defaultQty,
    String type,
  ) async {
    final controller = TextEditingController(
      text: (defaultQty ?? 1).toString(),
    );
    final reasonController = TextEditingController();
    String selectedReason = 'Kadaluarsa';

    final provider = context.read<WarehouseProvider>();
    final currentStok = provider.netStokFor(code);

    if (!isMasuk && currentStok <= 0) {
      CustomSnackBar.show(
        context,
        message: 'Barang ini belum ada stok',
        type: SnackType.error,
      );
      return null;
    }

    return showDialog<(int, String?)>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final scheme = Theme.of(context).colorScheme;
        final color = isMasuk ? AppColors.primary : Colors.orange.shade700;
        final title = isMasuk ? 'Barang Masuk' : 'Barang Keluar';
        final icon = isMasuk
            ? Icons.arrow_downward_rounded
            : Icons.output_rounded;
        final gradientColors = isMasuk
            ? [
                AppColors.primary.withValues(alpha: 0.2),
                AppColors.primary.withValues(alpha: 0.06),
              ]
            : [
                Colors.orange.withValues(alpha: 0.2),
                Colors.orange.withValues(alpha: 0.06),
              ];

        return StatefulBuilder(
          builder: (ctx, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradientColors,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 8, 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(icon, color: color, size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
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
                                    isMasuk
                                        ? 'Input jumlah barang yang masuk'
                                        : 'Stok tersedia: $currentStok',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              onPressed: () => Navigator.pop(ctx, null),
                              style: IconButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: Icon(
                                Icons.close_rounded,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  type.toLowerCase() == 'qrcode' ? Icons.qr_code_2 :
                                  type.toLowerCase() == 'code128' ? Icons.onetwothree :
                                  desc.isNotEmpty 
                                      ? Icons.description_rounded 
                                      : Icons.qr_code_rounded,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    desc.isNotEmpty ? desc : code,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (type.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      type,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.teal.shade700),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            autofocus: true,
                            decoration: InputDecoration(
                              labelText: 'Jumlah',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          if (!isMasuk) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: selectedReason,
                              decoration: InputDecoration(
                                labelText: 'Alasan Barang Keluar',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items:
                                  [
                                        'Kadaluarsa',
                                        'Rusak',
                                        'Hilang',
                                        'Konsumsi Internal',
                                        'Retur',
                                        'Pindah Stok',
                                        'Lainnya',
                                      ]
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (v) =>
                                  setState(() => selectedReason = v!),
                            ),
                            if (selectedReason == 'Lainnya') ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: reasonController,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: InputDecoration(
                                  labelText: 'Keterangan Lainnya (Wajib Isi)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ],
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx, null),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text('Batal'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: FilledButton.icon(
                                  onPressed: () {
                                    final qty = int.tryParse(
                                      controller.text.trim(),
                                    );
                                    if (qty != null && qty > 0) {
                                      if (!isMasuk) {
                                        if (qty > currentStok) {
                                          CustomSnackBar.show(
                                            context,
                                            message:
                                                'Maks. keluar: $currentStok',
                                            type: SnackType.error,
                                          );
                                          return;
                                        }
                                        if (selectedReason == 'Lainnya' &&
                                            reasonController.text
                                                .trim()
                                                .isEmpty) {
                                          CustomSnackBar.show(
                                            context,
                                            message: 'Alasan wajib diisi!',
                                            type: SnackType.error,
                                          );
                                          return;
                                        }
                                        Navigator.pop(ctx, (
                                          qty,
                                          selectedReason == 'Lainnya'
                                              ? reasonController.text.trim()
                                              : selectedReason,
                                        ));
                                      } else {
                                        Navigator.pop(ctx, (qty, null));
                                      }
                                    }
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: color,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.check_rounded,
                                    size: 20,
                                  ),
                                  label: const Text(
                                    'Simpan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  'Memeriksa izin kamera...',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final color = isMasuk ? AppColors.primary : Colors.red;
    final label = isMasuk ? 'Scan Barang Masuk' : 'Scan Barang Keluar';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) async {
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              if (_isScanning) return;

              final code = barcodes.first.rawValue ?? '';
              if (code.isEmpty) return;

              final format = barcodes.first.format;

              await _handleScan(code, format);
            },
          ),

          _buildOverlay(color),

          Positioned(
            top: MediaQuery.of(context).padding.top + 15,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                LEDCornerWrapper(
                  animation: _animationController,
                  isCircle: true,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                LEDCornerWrapper(
                  animation: _animationController,
                  isCircle: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder<MobileScannerState>(
                  valueListenable: cameraController,
                  builder: (context, state, child) {
                    final isOn = state.torchState == TorchState.on;
                    return LEDCornerWrapper(
                      animation: _animationController,
                      isCircle: true,
                      child: IconButton(
                        icon: Icon(
                          isOn ? Icons.flash_on : Icons.flash_off,
                          color: isOn ? Colors.yellow : Colors.white,
                        ),
                        onPressed: () => cameraController.toggleTorch(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 40,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: color.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isMasuk ? 'Masuk sesi ini' : 'Keluar sesi ini',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _scanCount.toString(),
                      style: TextStyle(
                        color: color,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    if (_lastCode != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _lastCode!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay(Color color) {
    final size = MediaQuery.of(context).size.width * 0.7;
    return Stack(
      children: [
        Align(
          alignment: Alignment.center,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return CustomPaint(
                size: Size(size, size),
                painter: ScannerLEDCornerPainter(
                  animationValue: _animationController.value,
                  baseColor: color,
                  ledColor: Colors.white,
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          left: false,
          right: false,
          bottom: true,
          minimum: EdgeInsets.zero,
          child: Align(
            alignment: const Alignment(0, 0.65),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.45)),
              ),
              child: Text(
                'Posisikan barcode di dalam kotak',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isMasuk ? Colors.white : Colors.red.shade200,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
