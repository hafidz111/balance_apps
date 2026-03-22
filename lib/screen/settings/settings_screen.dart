import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starvy/screen/login/login_screen.dart';
import 'package:starvy/screen/main/main_screen.dart';
import 'package:starvy/screen/widgets/ads/rewarded_ads.dart';
import 'package:starvy/screen/widgets/custom_text_field.dart';
import 'package:starvy/service/barcode_firebase_service.dart';

import '../../providers/firebase_auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/shared_preference_provider.dart';
import '../../service/premium_service.dart';
import '../../service/purchase_service.dart';
import '../../service/shared_preferences_service.dart';
import '../../utils/ads_helper.dart';
import '../../utils/date_format.dart';
import '../widgets/ads/banner_ads.dart';
import '../widgets/custom_snack_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String? _originalName;

  bool get _isNameChanged {
    return _nameController.text.trim() != (_originalName ?? "");
  }

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      context.read<FirebaseAuthProvider>().validateSession();
    });

    _nameController.addListener(() {
      if (context.read<SettingsProvider>().isEditingProfile) {
        context.read<SettingsProvider>().markChanged();
      }
    });
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
    final settings = context.read<SettingsProvider>();

    if (settings.isLoaded) return;

    final auth = context.read<FirebaseAuthProvider>();
    final pref = context.read<SharedPreferenceProvider>();

    _phoneController.text = pref.phoneNumber ?? "";
    settings.setSelectedShift(pref.shiftCount ?? 2);
    _nameController.text = auth.profile?.name ?? "";
    _originalName = auth.profile?.name ?? "";

    settings.setLoaded(true);
    _loadLastBackupTime();
    _loadLastSyncTime();
  }

  Future<void> _saveSettings() async {
    final settings = context.read<SettingsProvider>();
    if (!settings.isEditingSettings) {
      settings.setEditingSettings(true);
      return;
    }

    final pref = context.read<SharedPreferenceProvider>();
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      CustomSnackBar.show(
        context,
        message: "Nomor HP tidak boleh kosong",
        type: SnackType.error,
      );
      return;
    }

    final regex = RegExp(r'^[0-9]+$');
    if (!regex.hasMatch(phone)) {
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

    if (phone.length < 10) {
      CustomSnackBar.show(
        context,
        message: "Nomor HP tidak valid",
        type: SnackType.error,
      );
      return;
    }

    await pref.savePhoneNumber(_phoneController.text);
    await pref.saveShiftCount(settings.selectedShift);

    settings.setEditingSettings(false);

    FirebaseAnalytics.instance.logEvent(name: "settings_saved");

    CustomSnackBar.show(
      context,
      message: "Pengaturan berhasil disimpan",
      type: SnackType.success,
    );
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

  @override
  Widget build(BuildContext context) {
    const Color primaryTeal = Color(0xFF009688);
    final authProvider = context.watch<FirebaseAuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final user = authProvider.profile;
    final barcodeService = BarcodeFirebaseService();

    void _tapToSignOutOrLogin() async {
      final sharedPreferenceProvider = context.read<SharedPreferenceProvider>();
      final firebaseAuthProvider = context.read<FirebaseAuthProvider>();

      if (user != null) {
        await firebaseAuthProvider
            .signOutUser()
            .then((value) async {
              await sharedPreferenceProvider.logout();
              PremiumService.reset();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const MainScreen()),
                (route) => false,
              );
            })
            .whenComplete(() {
              CustomSnackBar.show(
                context,
                message: firebaseAuthProvider.message ?? "",
                type: SnackType.success,
              );
            });

        FirebaseAnalytics.instance.logEvent(name: "logout");
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }

    final isLoggedIn = user != null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
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
              const SizedBox(height: 8),
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
                    const Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          color: primaryTeal,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Profil Pengguna",
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
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
                              color: primaryTeal,
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
                    const Row(
                      children: [
                        Icon(Icons.settings, color: Colors.teal, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Pengaturan Aplikasi",
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
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

                    const SizedBox(height: 20),

                    _buildButton(
                      label: settings.isEditingSettings ? "Simpan" : "Edit",
                      icon: settings.isEditingSettings
                          ? Icons.save
                          : Icons.edit,
                      color: Colors.teal,
                      onPressed: _saveSettings,
                    ),
                  ],
                ),
              ),

              _buildSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.sync, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Sinkronisasi Data",
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
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
                          if (user == null) return;

                          await barcodeService.syncAll(user.uid!);
                          await _loadLastSyncTime();
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
                            await barcodeService.syncBarcodes(user!.uid!);
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

                            final message = e.toString();

                            if (message.contains(
                                  "Belum ada backup di server",
                                ) ||
                                message.contains("Data kosong di server")) {
                              settings.setSyncCooldownUntil(
                                DateTime.now().add(const Duration(minutes: 10)),
                              );

                              CustomSnackBar.show(
                                context,
                                message:
                                    "Tidak ada data yang disinkronkan. Coba lagi 10 menit.",
                                type: SnackType.error,
                              );
                            } else {
                              CustomSnackBar.show(
                                context,
                                message: "Sync gagal: $e",
                                type: SnackType.error,
                              );
                            }
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
                    const Row(
                      children: [
                        Icon(Icons.cloud, color: Colors.purple, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Backup Data",
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
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
                              message: "Backup gagal: $e",
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
                              message: "Backup gagal: $e",
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
                padding: const EdgeInsets.all(8.0),
                child: _buildButton(
                  label: isLoggedIn ? "Logout" : "Login",
                  icon: isLoggedIn ? Icons.login_outlined : Icons.person,
                  color: isLoggedIn ? Colors.red[700]! : Color(0xFF009688),
                  onPressed: _tapToSignOutOrLogin,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: child,
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
