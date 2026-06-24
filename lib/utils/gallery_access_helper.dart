import 'dart:io';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Gallery access without broad READ_MEDIA_* permissions on Android.
/// Picking uses the system photo picker; saving uses MediaStore (Android).
class GalleryAccessHelper {
  GalleryAccessHelper._();

  static const MethodChannel _galleryChannel = MethodChannel('gallery_saver');
  static final ImagePicker _picker = ImagePicker();

  static Future<bool> _ensureIosGalleryAccess() async {
    if (!Platform.isIOS) return true;

    final photos = await Permission.photos.request();
    if (photos.isGranted || photos.isLimited) return true;

    if (photos.isPermanentlyDenied) {
      await openAppSettings();
    }
    return false;
  }

  static Future<XFile?> pickImage() async {
    if (!await _ensureIosGalleryAccess()) return null;
    return _picker.pickImage(source: ImageSource.gallery);
  }

  static Future<List<XFile>> pickMultiImage() async {
    if (!await _ensureIosGalleryAccess()) return [];
    return _picker.pickMultiImage();
  }

  static Future<bool> savePngToGallery(
    Uint8List bytes, {
    required String fileName,
  }) async {
    if (Platform.isAndroid) {
      final saved = await _galleryChannel.invokeMethod<bool>('saveImage', {
        'bytes': bytes,
        'fileName': fileName,
      });
      return saved == true;
    }

    final path = await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      fileExtension: 'png',
      mimeType: MimeType.png,
    );
    return !path.contains('Something went wrong');
  }
}
