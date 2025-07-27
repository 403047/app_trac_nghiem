import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ImageHelper {
  static Future<File?> pickImage() async {
    // Yêu cầu quyền truy cập ảnh
    final status = await Permission.photos.request(); // iOS
    final storageStatus = await Permission.storage.request(); // Android

    if (status.isGranted || storageStatus.isGranted) {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } else {
      // Nếu không có quyền, có thể mở App Settings
      openAppSettings();
    }

    return null;
  }
}
