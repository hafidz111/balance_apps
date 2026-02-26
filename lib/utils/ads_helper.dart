import 'dart:io';

class AdsHelper {
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4122766238215136/8486809038';
    } else if (Platform.isIOS) {
      return '';
    } else {
      throw UnsupportedError('Unsupported Platform');
    }
  }
}
