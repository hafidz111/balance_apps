import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starvy/screen/assistant/assistant_screen.dart';
import 'package:starvy/screen/barcode/barcode_screen.dart';
import 'package:starvy/screen/history/history_screen.dart';
import 'package:starvy/screen/coffee/coffee_screen.dart';
import 'package:starvy/screen/schedule/schedule_screen.dart';
import 'package:starvy/screen/settings/settings_screen.dart';
import 'package:starvy/screen/store/store_screen.dart';
import 'package:starvy/screen/warehouse/warehouse_screen.dart';
import 'package:starvy/screen/widgets/custom_snack_bar.dart';
import 'package:starvy/theme/app_colors.dart';

import '../../providers/firebase_auth_provider.dart';
import '../../providers/main_screen_provider.dart';
import '../../providers/shared_preference_provider.dart';
import '../../service/premium_service.dart';
import '../../service/shared_preferences_service.dart';
import '../../utils/ads_helper.dart';
import '../../utils/user_friendly_error.dart';
import '../grid_photo/grid_photo_screen.dart';
import 'package:starvy/navigation/app_routes.dart';
import '../bread/bread_screen.dart';
import '../widgets/ads/rewarded_ads.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  DateTime? _screenStartTime;
  VoidCallback? deleteSelectedBarcodes;
  VoidCallback? selectAllBarcodes;
  VoidCallback? exitSelectionMode;

  static const List<String> _titles = [
    "Store",
    "Coffee",
    "Bread",
    "History",
    "Barcode",
    "Warehouse",
    "Space",
    "Schedule",
    "Asisten AI",
    'Settings',
  ];

  static const int _barcodeIdx = 4;
  static const int _assistantIdx = 8;
  static const int _settingsIdx = 9;

  static const List<IconData> _icons = [
    Icons.store,
    Icons.coffee,
    Icons.bakery_dining,
    Icons.history,
    Icons.qr_code,
    Icons.warehouse_rounded,
    Icons.space_dashboard,
    Icons.calendar_month,
    Icons.smart_toy_outlined,
    Icons.settings,
  ];

  @override
  void initState() {
    super.initState();
    _checkStoreData();
  }

  void _checkStoreData() async {
    final service = SharedPreferencesService();

    final pc = await service.getCoffeeStore();
    final sb = await service.getBreadStore();

    if (pc == null ||
        pc.title.isEmpty ||
        pc.nama.isEmpty ||
        pc.kode.isEmpty ||
        pc.tgl.isEmpty ||
        pc.area.isEmpty ||
        sb == null ||
        sb.title.isEmpty ||
        sb.nama.isEmpty ||
        sb.kode.isEmpty ||
        sb.tgl.isEmpty ||
        sb.area.isEmpty) {
      if (!mounted) return;
      context.read<MainScreenProvider>().setInitialIndex(0);
    } else {
      if (!mounted) return;
      context.read<MainScreenProvider>().setInitialIndex(1);
    }
  }

  void _onItemTapped(int index) {
    final selectedIndex = context.read<MainScreenProvider>().selectedIndex;
    final now = DateTime.now();

    if (_screenStartTime != null) {
      final duration = now.difference(_screenStartTime!).inSeconds;

      _analytics.logEvent(
        name: "screen_duration",
        parameters: {
          "screen_name": _titles[selectedIndex],
          "duration_seconds": duration,
        },
      );
    }

    _screenStartTime = now;

    context.read<MainScreenProvider>().setSelectedIndex(index);

    _analytics.logScreenView(
      screenName: _titles[index],
      screenClass: _titles[index],
    );
  }

  Future<void> _exportBarcodes() async {
    _analytics.logEvent(name: "barcode_export_clicked");
    try {
      final list = await SharedPreferencesService().getBarcodes();

      if (list.isEmpty) {
        CustomSnackBar.show(
          context,
          message: "Tidak ada data barcode untuk diexport",
          type: SnackType.error,
        );
        return;
      }

      final jsonString = await SharedPreferencesService()
          .exportBarcodesToJson();

      Uint8List bytes = Uint8List.fromList(utf8.encode(jsonString));

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan Backup Barcode',
        fileName:
            'starvy_barcode_backup_${DateTime.now().millisecondsSinceEpoch}.json',
        bytes: bytes,
      );

      if (path == null) return;

      _analytics.logEvent(name: "barcode_export_success");

      CustomSnackBar.show(
        context,
        message: "Backup berhasil disimpan",
        type: SnackType.success,
      );
    } catch (e) {
      CustomSnackBar.show(
        context,
        message: userFriendlyError(e, fallback: 'Export gagal. Coba lagi.'),
        type: SnackType.error,
      );
    }
  }

  Future<void> _importBarcodes() async {
    _analytics.logEvent(name: "barcode_import_clicked");

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null) return;

    final file = File(result.files.single.path!);
    final content = await file.readAsString();

    await SharedPreferencesService().importBarcodesFromJson(content);

    if (!mounted) return;
    context.read<MainScreenProvider>().refreshBarcodeAndOpenTab();

    _analytics.logEvent(name: "barcode_import_success");

    CustomSnackBar.show(
      context,
      message: "Import berhasil",
      type: SnackType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<FirebaseAuthProvider>();
    final isLogin = context.watch<SharedPreferenceProvider>().isLogin;
    final mainProvider = context.watch<MainScreenProvider>();
    final selectedIndex = mainProvider.selectedIndex;
    final isBarcodeSelectionMode = mainProvider.isBarcodeSelectionMode;
    final selectedBarcodeCount = mainProvider.selectedBarcodeCount;

    final widgetOptions = [
      const StoreScreen(),
      const CoffeeScreen(),
      const BreadScreen(),
      const HistoryScreen(),
      BarcodeScreen(
        key: ValueKey(mainProvider.barcodeRefreshKey),
        onSelectionChanged: (isSelecting, count) {
          context.read<MainScreenProvider>().setBarcodeSelection(
            isSelecting,
            count,
          );
        },
        onRegisterActions: (delete, selectAll, exit) {
          deleteSelectedBarcodes = delete;
          selectAllBarcodes = selectAll;
          exitSelectionMode = exit;
        },
      ),
      const WarehouseScreen(),
      const GridPhotoScreen(),
      const ScheduleScreen(),
      const AssistantScreen(),
      const SettingsScreen(),
    ];

    final user = authProvider.profile;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: isBarcodeSelectionMode && selectedIndex == _barcodeIdx
            ? Text(
                "$selectedBarcodeCount dipilih",
                style: const TextStyle(color: Colors.white),
              )
            : Text(
                _titles[selectedIndex],
                style: const TextStyle(color: Colors.white),
              ),
        leading: isBarcodeSelectionMode && selectedIndex == _barcodeIdx
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: exitSelectionMode,
              )
            : Builder(
                builder: (context) => IconButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu),
                  color: Colors.white,
                ),
              ),
        actions: isBarcodeSelectionMode && selectedIndex == _barcodeIdx
            ? [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: deleteSelectedBarcodes,
                ),
                IconButton(
                  icon: const Icon(Icons.select_all, color: Colors.white),
                  onPressed: selectAllBarcodes,
                ),
              ]
            : (selectedIndex == _barcodeIdx
                  ? [
                      PremiumService.cachedPremium
                          ? IconButton(
                              icon: const Icon(
                                Icons.upload_file,
                                color: Colors.white,
                              ),
                              onPressed: _exportBarcodes,
                            )
                          : RewardedAds(
                              featureName: "export",
                              adUnitId: AdsHelper.rewardedExportAdUnitId,
                              interstitialAdUnitId:
                                  AdsHelper.rewardedExportBarcodeAdUnitId,
                              onRewarded: _exportBarcodes,
                              icon: Icons.upload_file,
                              color: Colors.white,
                            ),

                      PremiumService.cachedPremium
                          ? IconButton(
                              icon: const Icon(
                                Icons.download,
                                color: Colors.white,
                              ),
                              onPressed: _importBarcodes,
                            )
                          : RewardedAds(
                              featureName: "import",
                              adUnitId: AdsHelper.rewardedImportAdUnitId,
                              interstitialAdUnitId:
                                  AdsHelper.rewardedImportBarcodeAdUnitId,
                              onRewarded: _importBarcodes,
                              icon: Icons.download,
                              color: Colors.white,
                            ),
                    ]
                  : []),
      ),
      body: widgetOptions[selectedIndex],
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primary),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Starvy',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);

                      if (isLogin) {
                        _onItemTapped(_settingsIdx);
                      } else {
                        context.pushAppRoute(AppRoutes.login);
                      }
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: user?.photoUrl != null
                              ? NetworkImage(user!.photoUrl!)
                              : null,
                          child: user?.photoUrl == null
                              ? const Icon(Icons.person, size: 40)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isLogin
                                    ? (authProvider.profile?.name ?? "User")
                                    : "Masuk / Login",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                isLogin ? "Admin" : "Klik untuk akses akun",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (int i = 0; i < _titles.length; i++)
                    ListTile(
                      leading: Icon(
                        _icons[i],
                        color: selectedIndex == i
                            ? AppColors.primary
                            : Colors.grey,
                      ),
                      title: Text(
                        _titles[i],
                        style: TextStyle(
                          color: selectedIndex == i
                              ? AppColors.primary
                              : Colors.black87,
                          fontWeight: selectedIndex == i
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: i == _assistantIdx &&
                              !PremiumService.cachedPremium
                          ? Text(
                              'Premium',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.amber.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                      selected: selectedIndex == i,
                      onTap: () {
                        _onItemTapped(i);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
