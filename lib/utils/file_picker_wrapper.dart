import 'package:file_picker/file_picker.dart';

// Wrapper class to allow mocking of static FilePicker calls
class FilePickerWrapper {
  Future<FilePickerResult?> pickFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool withData = false,
  }) async {
    return FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
      withData: withData,
    );
  }
}
