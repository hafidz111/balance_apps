import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starvy/navigation/app_routes.dart';
import 'package:starvy/screen/widgets/ads/rewarded_ads.dart';
import 'package:starvy/screen/widgets/custom_text_field.dart';
import 'package:starvy/service/barcode_firebase_service.dart';

import '../../providers/firebase_auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/shared_preference_provider.dart';
import '../../static/firebase_auth_status.dart';
import '../../service/premium_service.dart';
import '../../service/purchase_service.dart';
import '../../service/shared_preferences_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/ads_helper.dart';
import '../../utils/date_format.dart';
import '../../utils/shift_time_utils.dart';
import '../../utils/user_friendly_error.dart';
import '../widgets/ads/banner_ads.dart';
import '../widgets/custom_snack_bar.dart';
import 'widgets/shift_time_four_fields_row.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  final List<List<TextEditingController>> _shiftTimeFieldRows = List.generate(
    4,
    (_) => List.generate(4, (_) => TextEditingController()),
  );
  bool _shiftTimesHydrated = false;
  String? _originalName;
  bool _isInitScreenState = false;
  bool _isAuthActionInProgress = false;

  SettingsProvider? _settingsProvider;
  SharedPreferenceProvider? _prefProvider;

  bool get _isNameChanged {
    return _nameController.text.trim() != (_originalName ?? "");
  }

  bool get _isSettingsChanged {
    final pref = _prefProvider;
    final settings = _settingsProvider;
    if (pref == null || settings == null) return false;

    if (_phoneController.text.trim() != (pref.phoneNumber ?? "")) return true;
    if (settings.selectedShift != (pref.shiftCount ?? 2)) return true;

    final savedLabels = SharedPreferencesService().getShiftTimeLabels();
    for (int i = 0; i < settings.selectedShift; i++) {
      final currentEight = ShiftTimeUtils.rowToEightDigits(
        _shiftTimeFieldRows[i],
      );
      if (currentEight == null || currentEight.length != 8) return true;

      final range = ShiftTimeUtils.tryParseEightDigits(currentEight);
      if (range == null) return true;

      final currentFormatted = ShiftTimeUtils.formatRange(
        range.start,
        range.end,
      );
      final savedRaw = i < savedLabels.length ? savedLabels[i] : '';
      if (currentFormatted != savedRaw) return true;
    }

    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    Future.microtask(() async {
      final auth = context.read<FirebaseAuthProvider>();
      final pref = context.read<SharedPreferenceProvider>();
      final hadLocalLogin = pref.isLogin;

      await auth.validateSession();

      if (!mounted) return;

      if (hadLocalLogin && auth.profile == null) {
        await pref.logout();
      }

      if (auth.profile != null) {
        _nameController.text = auth.profile?.name ?? "";
        _originalName = auth.profile?.name ?? "";
        setState(() {});
      }
    });

    _nameController.addListener(() {
      if (context.read<SettingsProvider>().isEditingProfile) {
        context.read<SettingsProvider>().markChanged();
      }
    });

    _phoneController.addListener(() {
      if (context.read<SettingsProvider>().isEditingSettings) {
        context.read<SettingsProvider>().markChanged();
      }
    });

    for (final row in _shiftTimeFieldRows) {
      for (final controller in row) {
        controller.addListener(() {
          if (context.read<SettingsProvider>().isEditingSettings) {
            context.read<SettingsProvider>().markChanged();
          }
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
  }

  void _exitEditModeWithoutSaving({required bool updateControllers}) {
    final settings = _settingsProvider;
    final pref = _prefProvider;
    if (settings == null || pref == null) return;
    if (!settings.isEditingSettings && !settings.isEditingProfile) return;

    if (settings.isEditingSettings) {
      settings.setSelectedShift(pref.shiftCount ?? 2);
      if (updateControllers && mounted) {
        _phoneController.text = pref.phoneNumber ?? "";
        final labels = SharedPreferencesService().getShiftTimeLabels();
        for (int i = 0; i < 4; i++) {
          final raw = i < labels.length ? labels[i] : '';
          ShiftTimeUtils.setRowFromStoredLabel(_shiftTimeFieldRows[i], raw);
        }
      }
    }
    if (settings.isEditingProfile && updateControllers && mounted) {
      _nameController.text = _originalName ?? "";
    }

    settings.setEditingSettings(false);
    settings.setEditingProfile(false);

    if (updateControllers && mounted) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settingsProvider?.clearEditingStateSilent();
    _phoneController.dispose();
    _nameController.dispose();
    for (final row in _shiftTimeFieldRows) {
      for (final c in row) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadLastBackupTime() async {
    final settings = context.read<SettingsProvider>();
    final user = context.read<FirebaseAuthProvider>().profile;
    if (user == null) return;

    final service = BarcodeFirebaseService();
    final shared = SharedPreferencesService();

    final cache = await shared.getLastBackupTimeCache();
    if (mounted && cache != null) {
      settings.setLastBackupTime(cache);
    }

    try {
      final serverTime = await service.getLastBackupTime(user.uid!);

      if (serverTime != null) {
        await shared.saveLastBackupTime(serverTime);

        if (mounted) {
          settings.setLastBackupTime(serverTime);
        }
      }
    } on FirebaseException catch (e) {
      if (e.code == "network-error") {
        CustomSnackBar.show(
          context,
          message: "Sedang offline, menampilkan data terakhir",
          type: SnackType.error,
        );
      } else {
        debugPrint("Realtime DB error: ${e.code}");
      }
    }
  }

  Future<void> _loadLastSyncTime() async {
    final settings = context.read<SettingsProvider>();
    final user = context.read<FirebaseAuthProvider>().profile;
    if (user == null) return;

    final service = BarcodeFirebaseService();
    final shared = SharedPreferencesService();

    final cache = await shared.getLastSyncTimeCache();

    if (mounted && cache != null) {
      settings.setLastSyncTime(cache);
    }

    try {
      final serverTime = await service.getLastSyncTime(user.uid!);

      if (serverTime != null) {
        await shared.saveLastSyncTime(serverTime);

        if (mounted) {
          settings.setLastSyncTime(serverTime);
        }
      }
    } on FirebaseException catch (e) {
      if (e.code == "network-error") {
        CustomSnackBar.show(
          context,
          message: "Sedang offline, menampilkan data terakhir",
          type: SnackType.error,
        );
      } else {
        debugPrint("Realtime DB error: ${e.code}");
      }
    } catch (e) {
      debugPrint("General error, pakai cache");
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settingsProvider = context.read<SettingsProvider>();
    _prefProvider = context.read<SharedPreferenceProvider>();

    if (_isInitScreenState) return;
    _isInitScreenState = true;

    final pref = _prefProvider!;
    final auth = context.read<FirebaseAuthProvider>();

    _phoneController.text = pref.phoneNumber ?? "";
    _nameController.text = auth.profile?.name ?? "";
    _originalName = auth.profile?.name ?? "";

    if (!_shiftTimesHydrated) {
      _shiftTimesHydrated = true;
      final labels = SharedPreferencesService().getShiftTimeLabels();
      for (int i = 0; i < 4; i++) {
        final raw = i < labels.length ? labels[i] : '';
        ShiftTimeUtils.setRowFromStoredLabel(_shiftTimeFieldRows[i], raw);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _settingsProvider == null) return;
      _settingsProvider!.initializeScreenState(
        shiftCount: pref.shiftCount ?? 2,
      );
      _loadLastBackupTime();
      _loadLastSyncTime();
    });
  }

  bool _isTransitioningEdit = false;
  bool _isSavingSettings = false;

  Future<void> _saveSettings() async {
    if (_isSavingSettings || _isTransitioningEdit) return;

    final settings = context.read<SettingsProvider>();
    if (!settings.isEditingSettings) {
      _isTransitioningEdit = true;
      settings.setEditingSettings(true);

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _isTransitioningEdit = false;
        }
      });
      return;
    }

    _isSavingSettings = true;
    setState(() {});

    try {
      final pref = context.read<SharedPreferenceProvider>();
      String phone = _phoneController.text.trim();
      phone = phone.replaceAll(RegExp(r'[\s\-]'), '');

      if (phone.isEmpty && settings.isEditingSettings) {
        CustomSnackBar.show(
          context,
          message: "Nomor HP tidak boleh kosong",
          type: SnackType.error,
        );

        return;
      }

      if (phone.startsWith('+62')) {
        phone = phone.replaceFirst('+62', '62');
      } else if (phone.startsWith('0')) {
        phone = '62${phone.substring(1)}';
      }

      final regex = RegExp(r'^[0-9]+$');
      if (!regex.hasMatch(phone) && settings.isEditingSettings) {
        CustomSnackBar.show(
          context,
          message: "Nomor HP hanya boleh angka",
          type: SnackType.error,
        );
        return;
      }

      if (!phone.startsWith("628")) {
        CustomSnackBar.show(
          context,
          message: "Nomor harus diawali 628",
          type: SnackType.error,
        );
        return;
      }

      if (phone.length < 10 && settings.isEditingSettings) {
        CustomSnackBar.show(
          context,
          message: "Nomor HP tidak valid",
          type: SnackType.error,
        );
        return;
      }

      _phoneController.text = phone;

      final n = settings.selectedShift;
      for (int i = 0; i < n; i++) {
        final eight = ShiftTimeUtils.rowToEightDigits(_shiftTimeFieldRows[i]);
        if (eight == null ||
            ShiftTimeUtils.tryParseEightDigits(eight) == null) {
          CustomSnackBar.show(
            context,
            message:
                'Jam shift ${i + 1}: isi keempat kotak (jam & menit, masing-masing 00–23 / 00–59).',
            type: SnackType.error,
          );
          return;
        }
      }

      await pref.savePhoneNumber(_phoneController.text);
      await pref.saveShiftCount(settings.selectedShift);
      final normalized = List<String>.generate(4, (i) {
        if (i >= n) return '';
        final eight = ShiftTimeUtils.rowToEightDigits(_shiftTimeFieldRows[i])!;
        final range = ShiftTimeUtils.tryParseEightDigits(eight)!;
        return ShiftTimeUtils.formatRange(range.start, range.end);
      });
      await SharedPreferencesService().saveShiftTimeLabels(normalized);
      for (int i = 0; i < 4; i++) {
        ShiftTimeUtils.setRowFromStoredLabel(
          _shiftTimeFieldRows[i],
          i < n ? normalized[i] : '',
        );
      }

      if (!mounted) return;

      settings.setEditingSettings(false);

      FirebaseAnalytics.instance.logEvent(name: "settings_saved");

      CustomSnackBar.show(
        context,
        message: "Pengaturan berhasil disimpan",
        type: SnackType.success,
      );
    } finally {
      if (mounted) {
        _isSavingSettings = false;
        setState(() {});
      }
    }
  }

  Future<void> _buyRemoveAds() async {
    try {
      final purchaseService = PurchaseService();

      await purchaseService.buyRemoveAds();
      await PremiumService.isPremium();

      if (mounted) context.read<SettingsProvider>().markChanged();
    } catch (e) {
      CustomSnackBar.show(
        context,
        message: "Pembelian gagal",
        type: SnackType.error,
      );
    }
  }

  Future<void> _tapToSignOutOrLogin() async {
    if (_isAuthActionInProgress) return;

    final firebaseAuthProvider = context.read<FirebaseAuthProvider>();
    final sharedPreferenceProvider = context.read<SharedPreferenceProvider>();
    final isLoggedIn = firebaseAuthProvider.profile != null;

    if (!isLoggedIn) {
      await context.pushAppRoute(AppRoutes.login);

      if (!mounted) return;

      final auth = context.read<FirebaseAuthProvider>();
      if (auth.profile != null) {
        _nameController.text = auth.profile?.name ?? "";
        _originalName = auth.profile?.name ?? "";
        setState(() {});
      }
      return;
    }

    setState(() => _isAuthActionInProgress = true);

    try {
      await firebaseAuthProvider.signOutUser();

      if (!mounted) return;

      if (firebaseAuthProvider.authStatus !=
          FirebaseAuthStatus.unauthenticated) {
        CustomSnackBar.show(
          context,
          message:
              firebaseAuthProvider.message ??
              "Logout gagal. Silakan coba lagi.",
          type: SnackType.error,
        );
        return;
      }

      await sharedPreferenceProvider.logout();

      _nameController.text = "";
      _originalName = "";

      FirebaseAnalytics.instance.logEvent(name: "logout");

      CustomSnackBar.show(
        context,
        message: firebaseAuthProvider.message ?? "Logout berhasil",
        type: SnackType.success,
      );

      if (!mounted) return;

      context.pushAndRemoveUntilAppRoute(AppRoutes.main);
    } finally {
      if (mounted) {
        setState(() => _isAuthActionInProgress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<FirebaseAuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final user = authProvider.profile;
    final barcodeService = BarcodeFirebaseService();

    final isLoggedIn = user != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF8FAFF), Color(0xFFF2F5FB)],
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!PremiumService.cachedPremium) const BannerAds(),
                const SizedBox(height: 8),
                if (!PremiumService.cachedPremium)
                  _buildButton(
                    label: "Hapus Iklan (Sekali Bayar)",
                    icon: Icons.workspace_premium,
                    color: Colors.amber[700]!,
                    onPressed: isLoggedIn ? _buyRemoveAds : null,
                  ),
                if (!isLoggedIn && !PremiumService.cachedPremium)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      "Login untuk membeli fitur premium",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        icon: Icons.person_outline,
                        title: "Profil Pengguna",
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 35,
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                settings.isEditingProfile
                                    ? SizedBox(
                                        width: double.infinity,
                                        child: TextField(
                                          controller: _nameController,
                                          autofocus: true,
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            hintText: "Masukkan nama",
                                            border: UnderlineInputBorder(),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        user?.name ?? "Guest",
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                isLoggedIn
                                    ? Row(
                                        children: [
                                          const Icon(
                                            Icons.email_outlined,
                                            size: 14,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            user.email ?? 'Guest',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      )
                                    : const SizedBox(),
                              ],
                            ),
                          ),
                          if (isLoggedIn)
                            IconButton(
                              icon: Icon(
                                !settings.isEditingProfile
                                    ? Icons.edit
                                    : _isNameChanged
                                    ? Icons.check
                                    : Icons.close,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              onPressed: () async {
                                if (!settings.isEditingProfile) {
                                  settings.setEditingProfile(true);
                                  return;
                                }

                                if (!_isNameChanged) {
                                  settings.setEditingProfile(false);
                                  _nameController.text = _originalName ?? "";
                                  FocusScope.of(context).unfocus();
                                  return;
                                }

                                final newName = _nameController.text.trim();

                                if (newName.isEmpty) {
                                  CustomSnackBar.show(
                                    context,
                                    message: "Nama tidak boleh kosong",
                                    type: SnackType.error,
                                  );
                                  return;
                                }

                                await context
                                    .read<FirebaseAuthProvider>()
                                    .updateUserName(newName);

                                settings.setEditingProfile(false);
                                _originalName = newName;

                                CustomSnackBar.show(
                                  context,
                                  message: "Nama berhasil diperbarui",
                                  type: SnackType.success,
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                _buildSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        icon: Icons.settings,
                        title: "Pengaturan Aplikasi",
                        color: Colors.teal,
                      ),
                      const SizedBox(height: 20),

                      CustomInputField(
                        label: "Nomor HP",
                        controller: _phoneController,
                        enabled: settings.isEditingSettings,
                        keyboardType: TextInputType.phone,
                        hintText: "Masukkan nomor HP",
                      ),

                      const SizedBox(height: 20),

                      const Text("Jumlah Shift"),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: settings.selectedShift,
                        items: [1, 2, 3, 4]
                            .map(
                              (shift) => DropdownMenuItem(
                                value: shift,
                                child: Text("$shift Shift"),
                              ),
                            )
                            .toList(),
                        onChanged: settings.isEditingSettings
                            ? (value) {
                                settings.setSelectedShift(value!);
                              }
                            : null,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: !settings.isEditingSettings,
                          fillColor: !settings.isEditingSettings
                              ? Colors.grey.shade100
                              : null,
                        ),
                      ),

                      const SizedBox(height: 16),

                      for (int i = 0; i < settings.selectedShift; i++) ...[
                        ShiftTimeFourFieldsRow(
                          label: 'Jam Kerja Shift ${i + 1}',
                          controllers: _shiftTimeFieldRows[i],
                          enabled: settings.isEditingSettings,
                        ),
                        const SizedBox(height: 12),
                      ],

                      const SizedBox(height: 8),

                      _buildButton(
                        label: !settings.isEditingSettings
                            ? "Edit"
                            : (_isSettingsChanged ? "Simpan" : "Batalkan"),
                        icon: !settings.isEditingSettings
                            ? Icons.edit
                            : (_isSettingsChanged ? Icons.save : Icons.close),
                        color: !settings.isEditingSettings
                            ? Colors.teal
                            : (_isSettingsChanged
                                  ? Colors.teal
                                  : Colors.red[400]!),
                        isLoading: _isSavingSettings,
                        onPressed: () {
                          if (settings.isEditingSettings &&
                              !_isSettingsChanged) {
                            _exitEditModeWithoutSaving(updateControllers: true);
                          } else {
                            _saveSettings();
                          }
                        },
                      ),
                    ],
                  ),
                ),

                _buildSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        icon: Icons.sync,
                        title: "Sinkronisasi Data",
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Sinkronkan data lokal dengan server",
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),

                      const SizedBox(height: 12),
                      if (PremiumService.cachedPremium)
                        _buildButton(
                          label: "Sinkronkan Sekarang",
                          icon: Icons.sync,
                          color: Colors.blue[700]!,
                          onPressed: () async {
                            if (user == null) {
                              CustomSnackBar.show(
                                context,
                                message:
                                    'Login terlebih dahulu untuk sinkronisasi.',
                                type: SnackType.error,
                              );
                              return;
                            }

                            try {
                              await barcodeService.syncAll(user.uid!);
                              await _loadLastSyncTime();

                              FirebaseAnalytics.instance.logEvent(
                                name: "sync_success",
                              );

                              if (!mounted) return;
                              CustomSnackBar.show(
                                context,
                                message: "Sinkronisasi berhasil!",
                                type: SnackType.success,
                              );
                            } catch (e) {
                              FirebaseAnalytics.instance.logEvent(
                                name: "sync_failed",
                              );

                              if (!mounted) return;

                              CustomSnackBar.show(
                                context,
                                message: userFriendlyError(
                                  e,
                                  fallback:
                                      'Sinkronisasi gagal. Coba lagi nanti.',
                                ),
                                type: SnackType.error,
                              );
                            }
                          },
                        )
                      else
                        RewardedAds(
                          featureName: "sync",
                          adUnitId: AdsHelper.rewardedSyncAdUnitId,
                          interstitialAdUnitId:
                              AdsHelper.rewardedSyncDataAdUnitId,
                          label: "Sinkronkan Sekarang",
                          loadingLabel: "Sedang Sync...",
                          icon: Icons.sync,
                          color: Colors.blue[700]!,
                          enabled:
                              isLoggedIn &&
                              !settings.isSyncing &&
                              (settings.syncCooldownUntil == null ||
                                  DateTime.now().isAfter(
                                    settings.syncCooldownUntil!,
                                  )),
                          onRewarded: () async {
                            if (settings.isSyncing) return;

                            settings.setSyncing(true);

                            try {
                              await barcodeService.syncAll(user!.uid!);
                              await _loadLastSyncTime();

                              FirebaseAnalytics.instance.logEvent(
                                name: "sync_success",
                              );

                              CustomSnackBar.show(
                                context,
                                message: "Sinkronisasi berhasil!",
                                type: SnackType.success,
                              );
                            } catch (e) {
                              FirebaseAnalytics.instance.logEvent(
                                name: "sync_failed",
                              );

                              CustomSnackBar.show(
                                context,
                                message: userFriendlyError(
                                  e,
                                  fallback:
                                      'Sinkronisasi gagal. Coba lagi nanti.',
                                ),
                                type: SnackType.error,
                              );
                            } finally {
                              if (mounted) {
                                settings.setSyncing(false);
                              }
                            }
                          },
                        ),
                      if (settings.lastSyncTime != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            "Sync terakhir: ${formatDates(settings.lastSyncTime!)}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                _buildSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        icon: Icons.cloud,
                        title: "Backup Data",
                        color: Colors.purple,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Cadangkan semua data aplikasi Anda",
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      if (PremiumService.cachedPremium)
                        _buildButton(
                          label: "Backup Sekarang",
                          icon: Icons.cloud_upload_outlined,
                          color: Colors.purple[700]!,
                          onPressed: () async {
                            if (user == null) {
                              CustomSnackBar.show(
                                context,
                                message: 'Login terlebih dahulu untuk backup.',
                                type: SnackType.error,
                              );
                              return;
                            }

                            final barcodes = await SharedPreferencesService()
                                .getBarcodes();

                            if (barcodes.isEmpty) {
                              CustomSnackBar.show(
                                context,
                                message: "Tidak ada data untuk dibackup",
                                type: SnackType.error,
                              );
                              return;
                            }

                            settings.setBackingUp(true);

                            try {
                              await barcodeService.backupAll(
                                user.uid!,
                                user.email ?? "unknown",
                              );
                              await _loadLastBackupTime();

                              FirebaseAnalytics.instance.logEvent(
                                name: "backup_success",
                              );

                              CustomSnackBar.show(
                                context,
                                message: "Backup berhasil!",
                                type: SnackType.success,
                              );
                            } catch (e) {
                              FirebaseAnalytics.instance.logEvent(
                                name: "backup_failed",
                              );

                              CustomSnackBar.show(
                                context,
                                message: userFriendlyError(
                                  e,
                                  fallback: 'Backup gagal. Coba lagi nanti.',
                                ),
                                type: SnackType.error,
                              );
                            } finally {
                              settings.setBackingUp(false);
                            }
                          },
                        )
                      else
                        RewardedAds(
                          featureName: "backup",
                          adUnitId: AdsHelper.rewardedBackupAdUnitId,
                          interstitialAdUnitId:
                              AdsHelper.rewardedBackupDataAdUnitId,
                          label: "Backup Sekarang",
                          loadingLabel: "Sedang Backup...",
                          icon: Icons.cloud_upload_outlined,
                          color: Colors.purple[700]!,
                          enabled: isLoggedIn && !settings.isBackingUp,
                          onRewarded: () async {
                            final barcodes = await SharedPreferencesService()
                                .getBarcodes();

                            if (barcodes.isEmpty) {
                              CustomSnackBar.show(
                                context,
                                message: "Tidak ada data untuk dibackup",
                                type: SnackType.error,
                              );

                              settings.setBackingUp(false);

                              return;
                            }

                            settings.setBackingUp(true);

                            try {
                              await barcodeService.backupAll(
                                user!.uid!,
                                user.email ?? "unknown",
                              );
                              await _loadLastBackupTime();

                              FirebaseAnalytics.instance.logEvent(
                                name: "backup_success",
                              );

                              CustomSnackBar.show(
                                context,
                                message: "Backup berhasil!",
                                type: SnackType.success,
                              );
                            } catch (e) {
                              FirebaseAnalytics.instance.logEvent(
                                name: "backup_failed",
                              );

                              CustomSnackBar.show(
                                context,
                                message: userFriendlyError(
                                  e,
                                  fallback: 'Backup gagal. Coba lagi nanti.',
                                ),
                                type: SnackType.error,
                              );
                            } finally {
                              settings.setBackingUp(false);
                            }
                          },
                        ),
                      if (settings.lastBackupTime != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            "Backup terakhir: ${formatDates(settings.lastBackupTime!)}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: _buildButton(
                    label: isLoggedIn ? "Logout" : "Login",
                    icon: isLoggedIn ? Icons.logout : Icons.login,
                    color: isLoggedIn ? Colors.red[700]! : AppColors.primary,
                    isLoading: _isAuthActionInProgress,
                    loadingLabel: isLoggedIn ? "Keluar..." : "Memproses...",
                    onPressed: _isAuthActionInProgress ? null : _tapToSignOutOrLogin,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EBF5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120D1B2A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: Color(0xFF1D2942),
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
    bool isLoading = false,
    String? loadingLabel,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 18),
        label: Text(
          isLoading ? (loadingLabel ?? "Menyimpan...") : label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[600],
          elevation: 0.5,
          shadowColor: color.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
