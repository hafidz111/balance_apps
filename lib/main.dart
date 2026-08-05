import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:starvy/providers/ai_chat_provider.dart';
import 'package:starvy/providers/barcode_detail_provider.dart';
import 'package:starvy/providers/barcode_provider.dart';
import 'package:starvy/providers/firebase_auth_provider.dart';
import 'package:starvy/providers/grid_background_photo_provider.dart';
import 'package:starvy/providers/grid_choose_photo_provider.dart';
import 'package:starvy/providers/history_provider.dart';
import 'package:starvy/providers/login_provider.dart';
import 'package:starvy/providers/main_screen_provider.dart';
import 'package:starvy/providers/banner_ads_provider.dart';
import 'package:starvy/providers/coffee_provider.dart';
import 'package:starvy/providers/bread_provider.dart';
import 'package:starvy/providers/scanner_provider.dart';
import 'package:starvy/providers/schedule_provider.dart';
import 'package:starvy/providers/settings_provider.dart';
import 'package:starvy/providers/shared_preference_provider.dart';
import 'package:starvy/providers/store_provider.dart';
import 'package:starvy/providers/grid_photo_provider.dart';
import 'package:starvy/providers/warehouse_provider.dart';
import 'package:starvy/navigation/app_routes.dart';
import 'package:starvy/service/firebase_auth_service.dart';
import 'package:starvy/service/shared_preferences_service.dart';
import 'package:starvy/theme/app_colors.dart';
import 'package:starvy/utils/track_app_start.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

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
        ChangeNotifierProvider(
          create: (context) =>
              HistoryProvider(context.read<SharedPreferencesService>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              AiChatProvider(context.read<SharedPreferencesService>()),
        ),
        ChangeNotifierProvider(create: (_) => MainScreenProvider()),
        ChangeNotifierProvider(
          create: (context) => CoffeeProvider(
            context.read<SharedPreferencesService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => BreadProvider(
            context.read<SharedPreferencesService>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => GridBackgroundPhotoProvider()),
        ChangeNotifierProvider(create: (_) => GridPhotoProvider()),
        ChangeNotifierProvider(create: (_) => BarcodeProvider()),
        ChangeNotifierProvider(create: (_) => ScannerProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => LoginProvider()),
        ChangeNotifierProvider(
          create: (context) => StoreProvider(context.read<SharedPreferencesService>()),
        ),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
        ChangeNotifierProvider(create: (_) => GridChoosePhotoProvider()),
        ChangeNotifierProvider(create: (_) => BarcodeDetailProvider()),
        ChangeNotifierProvider(create: (_) => BannerAdsProvider()),
        ChangeNotifierProvider(create: (_) => WarehouseProvider()),
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
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.themeSeed),
      ),
      initialRoute: AppRoutes.main,
      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
