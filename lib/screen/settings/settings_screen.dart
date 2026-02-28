import 'package:balance/screen/login/login_screen.dart';
import 'package:balance/screen/main/main_screen.dart';
import 'package:balance/screen/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/firebase_auth_provider.dart';
import '../../providers/shared_preference_provider.dart';
import '../widgets/banner_ads.dart';
import '../widgets/custom_snack_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSyncing = false;
  bool _isBackingUp = false;

  final TextEditingController _phoneController = TextEditingController();

  int _selectedShift = 2;
  bool _isEditing = false;
  String? _originalPhone;

  Future<void> _saveSettings() async {
    if (!_isEditing) {
      setState(() {
        _isEditing = true;
      });
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
    await pref.saveShiftCount(_selectedShift);

    setState(() {
      _isEditing = false;
      _originalPhone = phone;
    });

    CustomSnackBar.show(
      context,
      message: "Pengaturan berhasil disimpan",
      type: SnackType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryTeal = Color(0xFF009688);
    final authProvider = context.watch<FirebaseAuthProvider>();
    final user = authProvider.profile;

    void _tapToSignOutOrLogin() async {
      final sharedPreferenceProvider = context.read<SharedPreferenceProvider>();
      final firebaseAuthProvider = context.read<FirebaseAuthProvider>();

      if (user != null) {
        await firebaseAuthProvider
            .signOutUser()
            .then((value) async {
              await sharedPreferenceProvider.logout();
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
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const BannerAds(),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
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
                      enabled: _isEditing,
                      keyboardType: TextInputType.phone,
                      hintText: "Masukkan nomor HP",
                    ),

                    const SizedBox(height: 20),

                    const Text("Jumlah Shift"),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedShift,
                      items: [1, 2, 3, 4]
                          .map(
                            (shift) => DropdownMenuItem(
                              value: shift,
                              child: Text("$shift Shift"),
                            ),
                          )
                          .toList(),
                      onChanged: _isEditing
                          ? (value) {
                              setState(() {
                                _selectedShift = value!;
                              });
                            }
                          : null,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: !_isEditing,
                        fillColor: !_isEditing ? Colors.grey.shade100 : null,
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildButton(
                      label: _isEditing ? "Simpan" : "Edit",
                      icon: _isEditing ? Icons.save : Icons.edit,
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
                    const SizedBox(height: 20),

                    const SizedBox(height: 12),
                    _buildButton(
                      label: _isSyncing
                          ? "Sedang Sync..."
                          : "Sinkronkan Sekarang",
                      icon: _isSyncing ? Icons.hourglass_top : Icons.sync,
                      color: Colors.blue[700]!,
                      onPressed: null,
                      // isLoggedIn && !_isSyncing
                      //     ? ()  {}
                      // async {
                      //   setState(() => _isSyncing = true);
                      //   try {
                      //     final backupProvider =
                      //     context.read<BackupProvider>();
                      //     await backupProvider.sync(user.uid!);
                      //   CustomSnackBar.show(context, message: "Sync berhasil", type: SnackType.success);
                      //   } finally {
                      //     setState(() => _isSyncing = false);
                      //   }
                      // }
                      //     : null,
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
                    const SizedBox(height: 20),

                    const SizedBox(height: 12),
                    _buildButton(
                      label: _isBackingUp
                          ? "Sedang Backup..."
                          : "Backup Sekarang",
                      icon: _isBackingUp
                          ? Icons.hourglass_top
                          : Icons.cloud_upload_outlined,
                      color: Colors.purple[700]!,
                      onPressed: null,
                      // isLoggedIn && !_isBackingUp
                      //     ? () async {
                      //   setState(() => _isBackingUp = true);
                      //   try {
                      //     final backupProvider =
                      //     context.read<BackupProvider>();
                      //     await backupProvider.backup(user.uid!);
                      //   CustomSnackBar.show(context, message: "Backup berhasil", type: SnackType.success);
                      //   } finally {
                      //     setState(() => _isBackingUp = false);
                      //   }
                      // }
                      //     : null,
                    ),
                  ],
                ),
              ),

              // Padding(
              //   padding: const EdgeInsets.all(8.0),
              //   child: _buildButton(
              //     label: isLoggedIn ? "Logout" : "Login",
              //     icon: isLoggedIn ? Icons.login_outlined : Icons.person,
              //     color: isLoggedIn ? Colors.red[700]! : Color(0xFF009688),
              //     onPressed: _tapToSignOutOrLogin,
              //   ),
              // ),
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
    if (_isEditing && _originalPhone != null) {
      _phoneController.text = _originalPhone!;
    }
    super.dispose();
  }
}
