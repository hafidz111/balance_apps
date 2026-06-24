import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starvy/screen/widgets/custom_snack_bar.dart';

import '../../providers/store_provider.dart';
import 'widgets/store_card.dart';

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final activeTab = context.select<StoreProvider, int>(
      (provider) => provider.activeTab,
    );
    context.select<StoreProvider, int>((provider) => provider.dataVersion);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildTabItem(context, "Coffee", 0),
                    _buildTabItem(context, "Bread", 1),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: activeTab == 0
                    ? _coffeeTab(context)
                    : _breadTab(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, String title, int index) {
    final activeTab = context.select<StoreProvider, int>(
      (provider) => provider.activeTab,
    );
    bool isActive = activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          FirebaseAnalytics.instance.logEvent(
            name: "store_tab_changed",
            parameters: {"tab": index == 0 ? "coffee" : "bread"},
          );
          if (activeTab != index) {
            final provider = context.read<StoreProvider>();
            provider.setActiveTab(index);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _coffeeTab(BuildContext context) {
    final provider = context.read<StoreProvider>();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        StoreCard(
          key: const ValueKey("coffee_store"),
          category: "Coffee",
          titleController: provider.pcTitle,
          namaController: provider.pcNama,
          kodeController: provider.pcKode,
          tglController: provider.pcTgl,
          areaController: provider.pcArea,
          onSave: () => _handleSave(context, "Coffee"),
        ),
      ],
    );
  }

  Widget _breadTab(BuildContext context) {
    final provider = context.read<StoreProvider>();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        StoreCard(
          key: const ValueKey("bread_store"),
          category: "Bread",
          titleController: provider.sbTitle,
          namaController: provider.sbNama,
          kodeController: provider.sbKode,
          tglController: provider.sbTgl,
          areaController: provider.sbArea,
          onSave: () => _handleSave(context, "Bread"),
        ),
      ],
    );
  }

  void _handleSave(BuildContext context, String category) async {
    final provider = context.read<StoreProvider>();

    await provider.saveStoreData(category);

    FirebaseAnalytics.instance.logEvent(
      name: "store_saved",
      parameters: {"category": category},
    );
    if (!context.mounted) return;
    CustomSnackBar.show(
      context,
      message: "Data $category berhasil disimpan",
      type: SnackType.success,
    );
  }
}
