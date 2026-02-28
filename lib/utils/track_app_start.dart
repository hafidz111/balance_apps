import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<void> trackAppStart() async {
  final analytics = FirebaseAnalytics.instance;
  final packageInfo = await PackageInfo.fromPlatform();

  await analytics.logEvent(
    name: "app_started",
    parameters: {
      "app_version": packageInfo.version,
      "build_number": packageInfo.buildNumber,
      "platform": Platform.operatingSystem,
    },
  );
}
