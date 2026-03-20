import 'dart:async';

import 'package:starvy/providers/firebase_auth_provider.dart';
import 'package:starvy/providers/shared_preference_provider.dart';
import 'package:starvy/screen/main/main_screen.dart';
import 'package:starvy/service/firebase_auth_service.dart';
import 'package:starvy/service/shared_preferences_service.dart';
import 'package:starvy/utils/track_app_start.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(MobileAds.instance.initialize());
  await SharedPreferencesService.init();
  await SharedPreferencesService().initDb();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final firebaseAuth = FirebaseAuth.instance;
  await trackAppStart();

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (context) => SharedPreferencesService()),
        ChangeNotifierProvider(
          create: (context) => SharedPreferenceProvider(
            context.read<SharedPreferencesService>(),
          ),
        ),
        Provider(create: (context) => FirebaseAuthService(firebaseAuth)),
        ChangeNotifierProvider(
          create: (context) =>
              FirebaseAuthProvider(context.read<FirebaseAuthService>()),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const appTitle = 'Starvy';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: MainScreen(),
      routes: {},
    );
  }
}
