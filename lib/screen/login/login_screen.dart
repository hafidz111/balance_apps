import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/firebase_auth_provider.dart';
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

  bool loading = false;
  bool hidePass = true;

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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),

              const Text(
                "Selamat Datang",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              Text(
                "Silakan login untuk melanjutkan",
                style: TextStyle(color: Colors.grey[600]),
              ),

              const SizedBox(height: 32),

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

              const SizedBox(height: 16),

              TextField(
                controller: passC,
                obscureText: hidePass,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      hidePass ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() => hidePass = !hidePass);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: loading ? null : _tapToLogin,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Login"),
                ),
              ),

              const Spacer(),

              Center(
                child: Text(
                  "Versi 1.0.0",
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

    setState(() => loading = true);

    final firebaseAuthProvider = context.read<FirebaseAuthProvider>();
    final sharedPreferenceProvider = context.read<SharedPreferenceProvider>();

    FirebaseAnalytics.instance.logEvent(name: "login_attempt");
    await firebaseAuthProvider.signInUser(email, password);

    if (!mounted) return;

    setState(() => loading = false);

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
