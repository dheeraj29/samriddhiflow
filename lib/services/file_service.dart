import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

// We will keep the web-specific logic internal to this service
import '../utils/connectivity_platform.dart';

class FileService {
  /// Saves a file to the device.
  /// On Web: Triggers a browser download.
  /// On Windows: Saves to the Downloads folder.
  /// On Android: Requests permissions and saves to the Downloads/Documents folder.
  Future<String?> saveFile(String fileName, List<int> bytes) async {
    if (kIsWeb) {
      return _saveFileWeb(fileName, bytes);
    } else if (Platform.isWindows) {
      return _saveFileWindows(fileName, bytes);
    } else if (Platform.isAndroid) {
      return _saveFileAndroid(fileName, bytes);
    }
    return null;
  }

  /// Picks a file from the device.
  Future<Uint8List?> pickFile({List<String>? allowedExtensions}) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      allowedExtensions: allowedExtensions,
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      return result.files.single.bytes;
    }
    return null;
  }

  // --- PRIVATE WEB LOGIC ---
  Future<String> _saveFileWeb(String fileName, List<int> bytes) async {
    return ConnectivityPlatform.saveFileWeb(fileName, bytes);
  }

  // --- PRIVATE WINDOWS LOGIC ---
  Future<String> _saveFileWindows(String fileName, List<int> bytes) async {
    try {
      final directory = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final path = "${directory.path}\\$fileName";
      final file = File(path);
      await file.writeAsBytes(bytes);
      return "Saved to: $path";
    } catch (e) {
      throw Exception("Windows save failed: $e");
    }
  }

  // --- PRIVATE ANDROID LOGIC ---
  Future<String> _saveFileAndroid(String fileName, List<int> bytes) async {
    try {
      // Android 13+ doesn't need storage permission for media, but for generic files we might.
      // For simplicity and compatibility:
      if (await Permission.storage.request().isGranted) {
        // use getExternalStorageDirectory or path_provider's equivalent
        // Use path_provider to get safe application directory (Sonar Compliant)
        final directory = await getApplicationSupportDirectory();

        final path = "${directory.path}/$fileName";
        await File(path).writeAsBytes(bytes);
        return "Saved to: $path";
      } else {
        throw Exception("Storage permission denied");
      }
    } catch (e) {
      throw Exception("Android save failed: $e");
    }
  }
}
