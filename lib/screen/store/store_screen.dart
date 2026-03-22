import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starvy/screen/widgets/custom_snack_bar.dart';

import '../../data/model/store_data.dart';
import '../../providers/store_provider.dart';
import '../../service/shared_preferences_service.dart';
import 'widgets/store_card.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final pcTitle = TextEditingController();
  final pcNama = TextEditingController();
  final pcKode = TextEditingController();
  final pcTgl = TextEditingController();
  final pcArea = TextEditingController();

  final sbTitle = TextEditingController();
  final sbNama = TextEditingController();
  final sbKode = TextEditingController();
  final sbTgl = TextEditingController();
  final sbArea = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStoreData();
  }

  Future<void> _loadStoreData() async {
    final storeProvider = context.read<StoreProvider>();
    final service = SharedPreferencesService();

    final pc = await service.getPointCoffeeStore();
    if (pc != null) {
      pcTitle.text = pc.title;
      pcNama.text = pc.nama;
      pcKode.text = pc.kode;
      pcTgl.text = pc.tgl;
      pcArea.text = pc.area;
    } else {
      pcTitle.clear();
      pcNama.clear();
      pcKode.clear();
      pcTgl.clear();
      pcArea.clear();
    }

    final sb = await service.getSayBreadStore();
    if (sb != null) {
      sbTitle.text = sb.title;
      sbNama.text = sb.nama;
      sbKode.text = sb.kode;
      sbTgl.text = sb.tgl;
      sbArea.text = sb.area;
    } else {
      sbTitle.clear();
      sbNama.clear();
      sbKode.clear();
      sbTgl.clear();
      sbArea.clear();
    }
    storeProvider.markDataLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = context.select<StoreProvider, int>(
      (provider) => provider.activeTab,
    );
    context.select<StoreProvider, int>((provider) => provider.dataVersion);

    return Scaffold(
      body: Padding(
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
                  _buildTabItem("Coffee", 0),
                  _buildTabItem("Bread", 1),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: activeTab == 0 ? _pointCoffeeTab() : _sayBreadTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(String title, int index) {
    final activeTab = context.select<StoreProvider, int>(
      (provider) => provider.activeTab,
    );
    bool isActive = activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          FirebaseAnalytics.instance.logEvent(
            name: "store_tab_changed",
            parameters: {"tab": index == 0 ? "point_coffee" : "say_bread"},
          );
          if (activeTab != index) {
            await _loadStoreData();
            if (!context.mounted) return;
            context.read<StoreProvider>().setActiveTab(index);
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

  Widget _pointCoffeeTab() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        StoreCard(
          key: const ValueKey("point_coffee_store"),
          titleController: pcTitle,
          namaController: pcNama,
          kodeController: pcKode,
          tglController: pcTgl,
          areaController: pcArea,
          onSave: () => _handleSave("Coffee"),
        ),
      ],
    );
  }

  Widget _sayBreadTab() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        StoreCard(
          key: const ValueKey("say_bread_store"),
          titleController: sbTitle,
          namaController: sbNama,
          kodeController: sbKode,
          tglController: sbTgl,
          areaController: sbArea,
          onSave: () => _handleSave("Bread"),
        ),
      ],
    );
  }

  void _handleSave(String category) async {
    final service = SharedPreferencesService();

    if (category == "Coffee") {
      await service.savePointCoffeeStore(
        StoreData(
          title: pcTitle.text,
          nama: pcNama.text,
          kode: pcKode.text,
          tgl: pcTgl.text,
          area: pcArea.text,
        ),
      );
    } else {
      await service.saveSayBreadStore(
        StoreData(
          title: sbTitle.text,
          nama: sbNama.text,
          kode: sbKode.text,
          tgl: sbTgl.text,
          area: sbArea.text,
        ),
      );
    }
    if (!mounted) return;
    FirebaseAnalytics.instance.logEvent(
      name: "store_saved",
      parameters: {"category": category},
    );
    CustomSnackBar.show(
      context,
      message: "Data $category berhasil disimpan",
      type: SnackType.success,
    );
  }
}
