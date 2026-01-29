import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:samriddhi_flow/services/file_service.dart';
import 'package:samriddhi_flow/utils/file_picker_wrapper.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFilePickerWrapper extends Mock implements FilePickerWrapper {}

class MockPathProviderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String tempPath;
  MockPathProviderPlatform(this.tempPath);

  @override
  Future<String?> getDownloadsPath() async => tempPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;

  @override
  Future<String?> getApplicationSupportPath() async => tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;

  @override
  Future<List<String>?> getExternalStoragePaths(
          {StorageDirectory? type}) async =>
      [tempPath];

  @override
  Future<String?> getExternalStoragePath({StorageDirectory? type}) async =>
      tempPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFilePickerWrapper mockPicker;
  late FileService fileService;
  late Directory tempDir;

  setUpAll(() async {
    registerFallbackValue(FileType.any);

    // Create a real temp directory for file operations
    tempDir = await Directory.systemTemp.createTemp('file_service_test');

    // Mock Path Provider Platform
    PathProviderPlatform.instance = MockPathProviderPlatform(tempDir.path);
  });

  setUp(() {
    mockPicker = MockFilePickerWrapper();
    fileService = FileService(picker: mockPicker);
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('pickFile returns bytes when file selected', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final result = FilePickerResult([
      PlatformFile(name: 'test.xlsx', size: 3, bytes: bytes, readStream: null),
    ]);

    when(() => mockPicker.pickFiles(
          type: any(named: 'type'),
          allowedExtensions: any(named: 'allowedExtensions'),
          withData: true,
        )).thenAnswer((_) async => result);

    final picked = await fileService.pickFile(allowedExtensions: ['xlsx']);
    expect(picked, bytes);
  });

  test('pickFile returns null when canceled', () async {
    when(() => mockPicker.pickFiles(
          type: any(named: 'type'),
          allowedExtensions: any(named: 'allowedExtensions'),
          withData: true,
        )).thenAnswer((_) async => null);

    final picked = await fileService.pickFile();
    expect(picked, null);
  });

  test('saveFile writes to disk (simulated)', () async {
    // NOTE: file_service.dart checks Platform.isWindows/Android.
    // We cannot easily mock Platform.isWindows in Dart.
    // However, we can run this test logic if the execution environment is Windows.
    // Or we can rely on the fact that `_saveFileWindows` uses `getDownloadsDirectory`.
    // If we are on windows, it will use our mock path.

    if (Platform.isWindows) {
      final result = await fileService.saveFile('test.txt', [65, 66]);
      expect(result, contains(tempDir.path)); // Should return path

      final file = File('${tempDir.path}\\test.txt');
      expect(file.existsSync(), true);
      expect(file.readAsBytesSync(), [65, 66]);
    }
  });
}
