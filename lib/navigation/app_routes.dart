import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:starvy/data/model/barcode_data.dart';
import 'package:starvy/screen/barcode/barcode_detail_screen.dart';
import 'package:starvy/screen/barcode/choose_barcode_screen.dart';
import 'package:starvy/screen/barcode/widgets/barcode_form.dart';
import 'package:starvy/screen/grid_photo/grid_background_photo_screen.dart';
import 'package:starvy/screen/grid_photo/grid_choose_photo_screen.dart';
import 'package:starvy/screen/login/login_screen.dart';
import 'package:starvy/screen/main/main_screen.dart';
import 'package:starvy/screen/scanner/scanner_screen.dart';
import 'package:starvy/screen/settings/notification_screen.dart';

abstract final class AppRoutes {
  static const main = '/';
  static const login = '/login';
  static const barcodeChoose = '/barcode/choose';
  static const barcodeDetail = '/barcode/detail';
  static const barcodeForm = '/barcode/form';
  static const scanner = '/scanner';
  static const gridChoose = '/grid/choose';
  static const gridBackground = '/grid/background';
  static const notifications = '/notifications';

  static Map<String, WidgetBuilder> get routes => {
    main: (_) => const MainScreen(),
    login: (_) => const LoginScreen(),
    barcodeChoose: (_) => const ChooseBarcodeScreen(),
    scanner: (_) => const ScannerScreen(),
    notifications: (_) => const NotificationScreen(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case barcodeDetail:
        final args = settings.arguments as BarcodeDetailArgs?;
        if (args == null) return _badArgs(settings);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => BarcodeDetailScreen(barcode: args.barcode),
        );
      case barcodeForm:
        final args = settings.arguments as BarcodeFormArgs?;
        if (args == null) return _badArgs(settings);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => BarcodeForm(
            type: args.type,
            barcode: args.barcode,
            initialCode: args.initialCode,
          ),
        );
      case gridChoose:
        final args = settings.arguments as GridChoosePhotoArgs?;
        if (args == null) return _badArgs(settings);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => GridChoosePhotoScreen(
            rows: args.rows,
            cols: args.cols,
            title: args.title,
          ),
        );
      case gridBackground:
        final args = settings.arguments as GridBackgroundPhotoArgs?;
        if (args == null) return _badArgs(settings);
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => GridBackgroundPhotoScreen(
            capturedImage: args.capturedImage,
            title: args.title,
          ),
        );
      default:
        return null;
    }
  }

  static Route<dynamic> _badArgs(RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => const Scaffold(
        body: Center(child: Text('Argumen route tidak valid')),
      ),
    );
  }
}

final class BarcodeDetailArgs {
  const BarcodeDetailArgs({required this.barcode});
  final BarcodeData barcode;
}

final class BarcodeFormArgs {
  const BarcodeFormArgs({required this.type, this.barcode, this.initialCode});

  final String type;
  final BarcodeData? barcode;
  final String? initialCode;
}

final class GridChoosePhotoArgs {
  const GridChoosePhotoArgs({
    required this.rows,
    required this.cols,
    required this.title,
  });

  final int rows;
  final int cols;
  final String title;
}

final class GridBackgroundPhotoArgs {
  const GridBackgroundPhotoArgs({
    required this.capturedImage,
    required this.title,
  });

  final Uint8List capturedImage;
  final String title;
}

extension AppNavigator on BuildContext {
  Future<T?> pushAppRoute<T>(String routeName, {Object? arguments}) {
    return Navigator.of(this).pushNamed<T>(routeName, arguments: arguments);
  }

  Future<T?> pushReplacementAppRoute<T, TO>(
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(
      this,
    ).pushReplacementNamed<T, TO>(routeName, arguments: arguments);
  }

  Future<T?> pushAndRemoveUntilAppRoute<T>(
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(
      this,
    ).pushNamedAndRemoveUntil<T>(routeName, (_) => false, arguments: arguments);
  }
}
