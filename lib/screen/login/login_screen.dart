import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/firebase_auth_provider.dart';
import '../../providers/login_provider.dart';
import '../../providers/shared_preference_provider.dart';
import '../../static/firebase_auth_status.dart';
import '../main/main_screen.dart';
import '../widgets/custom_snack_bar.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailC = TextEditingController();
  final passC = TextEditingController();

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      final firebaseAuthProvider = context.read<FirebaseAuthProvider>();
      final isLogin = context.read<SharedPreferenceProvider>().isLogin;

      if (isLogin) {
        await firebaseAuthProvider.updateProfile();

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loginProvider = context.watch<LoginProvider>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF009688), Color(0xFF00695C)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.coffee, color: Colors.white, size: 30),
                    SizedBox(width: 10),
                    Text(
                      "Starvy",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Selamat Datang",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Login untuk melanjutkan ke dashboard aplikasi",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: emailC,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: "Email",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: passC,
                          obscureText: loginProvider.hidePass,
                          decoration: InputDecoration(
                            labelText: "Password",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                loginProvider.hidePass
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                context.read<LoginProvider>().toggleHidePass();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: loginProvider.loading
                                ? null
                                : _tapToLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF009688),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: loginProvider.loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text("Login"),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _openCreateAccountWhatsApp,
                            icon: const Icon(
                              Icons.chat,
                              color: Color(0xFF009688),
                            ),
                            label: const Text(
                              "Buat Akun via WhatsApp",
                              style: TextStyle(
                                color: Color(0xFF009688),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF009688)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Belum punya akun? Hubungi admin untuk dibuatkan akun.",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Center(
                          child: FutureBuilder<PackageInfo>(
                            future: PackageInfo.fromPlatform(),
                            builder: (context, snapshot) {
                              final version = snapshot.data?.version ?? "-";
                              return Text(
                                "Versi $version",
                                style: TextStyle(color: Colors.grey[500]),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateAccountWhatsApp() async {
    final template =
        "Halo Admin Starvy,%0A"
        "Saya ingin request pembuatan akun aplikasi.%0A%0A"
        "Email: [isi email]%0A"
        "Password custom: [isi password]%0A%0A"
        "Terima kasih.";
    final uri = Uri.parse("https://wa.me/6281290057505?text=$template");

    try {
      FirebaseAnalytics.instance.logEvent(
        name: "create_account_whatsapp_click",
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message: "Gagal membuka WhatsApp",
        type: SnackType.error,
      );
    }
  }

  void _tapToLogin() async {
    final email = emailC.text.trim();
    final password = passC.text.trim();

    if (email.isEmpty || password.isEmpty) {
      CustomSnackBar.show(
        context,
        message: "Isi email dan password dengan benar",
        type: SnackType.error,
      );
      return;
    }

    context.read<LoginProvider>().setLoading(true);

    final firebaseAuthProvider = context.read<FirebaseAuthProvider>();
    final sharedPreferenceProvider = context.read<SharedPreferenceProvider>();

    FirebaseAnalytics.instance.logEvent(name: "login_attempt");
    await firebaseAuthProvider.signInUser(email, password);

    if (!mounted) return;

    context.read<LoginProvider>().setLoading(false);

    switch (firebaseAuthProvider.authStatus) {
      case FirebaseAuthStatus.authenticated:
        await sharedPreferenceProvider.login();

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
        return;

      default:
        CustomSnackBar.show(
          context,
          message: "Login gagal",
          type: SnackType.error,
        );
    }
  }

  @override
  void dispose() {
    emailC.dispose();
    passC.dispose();
    super.dispose();
  }
}
