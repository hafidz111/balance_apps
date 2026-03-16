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

  static String get rewardedExportAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4122766238215136/2449422839';
    } else if (Platform.isIOS) {
      return '';
    } else {
      throw UnsupportedError('Unsupported Platform');
    }
  }

  static String get rewardedExportBarcodeAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4122766238215136/8495788562';
    } else if (Platform.isIOS) {
      return '';
    } else {
      throw UnsupportedError('Unsupported Platform');
    }
  }

  static String get rewardedImportAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4122766238215136/3791113024';
    } else if (Platform.isIOS) {
      return '';
    } else {
      throw UnsupportedError('Unsupported Platform');
    }
  }

  static String get rewardedImportBarcodeAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4122766238215136/4137052790';
    } else if (Platform.isIOS) {
      return '';
    } else {
      throw UnsupportedError('Unsupported Platform');
    }
  }

  static String get rewardedBackupAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4122766238215136/9910274179';
    } else if (Platform.isIOS) {
      return '';
    } else {
      throw UnsupportedError('Unsupported Platform');
    }
  }

  static String get rewardedBackupDataAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4122766238215136/4931948073';
    } else if (Platform.isIOS) {
      return '';
    } else {
      throw UnsupportedError('Unsupported Platform');
    }
  }

  static String get rewardedSyncAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4122766238215136/1512909400';
    } else if (Platform.isIOS) {
      return '';
    } else {
      throw UnsupportedError('Unsupported Platform');
    }
  }

  static String get rewardedSyncDataAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4122766238215136/3650655999';
    } else if (Platform.isIOS) {
      return '';
    } else {
      throw UnsupportedError('Unsupported Platform');
    }
  }

  static String get rewardedDownloadTemplateAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4122766238215136/6319852251';
    } else if (Platform.isIOS) {
      return '';
    } else {
      throw UnsupportedError('Unsupported Platform');
    }
  }

  static String get rewardedDownloadScheduleTemplateAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4122766238215136/2633563150';
    } else if (Platform.isIOS) {
      return '';
    } else {
      throw UnsupportedError('Unsupported Platform');
    }
  }

  static String get rewardedImportTemplateAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4122766238215136/4226169824';
    } else if (Platform.isIOS) {
      return '';
    } else {
      throw UnsupportedError('Unsupported Platform');
    }
  }

  static String get rewardedImportScheduleAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4122766238215136/2983753229';
    } else if (Platform.isIOS) {
      return '';
    } else {
      throw UnsupportedError('Unsupported Platform');
    }
  }

  static String get rewardedSaveScheduleAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4122766238215136/5006770582';
    } else if (Platform.isIOS) {
      return '';
    } else {
      throw UnsupportedError('Unsupported Platform');
    }
  }

  static String get rewardedExportScheduleAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-4122766238215136/9223022235';
    } else if (Platform.isIOS) {
      return '';
    } else {
      throw UnsupportedError('Unsupported Platform');
    }
  }
}
