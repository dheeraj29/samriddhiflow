import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/services/file_service.dart';
import 'package:samriddhi_flow/utils/file_picker_wrapper.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

class MockFilePickerWrapper extends Mock implements FilePickerWrapper {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FileService fileService;
  late MockFilePickerWrapper mockPicker;
  late Directory tempDir;

  const MethodChannel channel =
      MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    registerFallbackValue(FileType.any);
    tempDir = await Directory.systemTemp.createTemp('file_service_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getTemporaryDirectory' ||
          methodCall.method == 'getApplicationDocumentsDirectory' ||
          methodCall.method == 'getApplicationSupportDirectory' ||
          methodCall.method == 'getDownloadsDirectory') {
        return tempDir.path;
      }
      return null;
    });
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  setUp(() {
    mockPicker = MockFilePickerWrapper();
    fileService = FileService(picker: mockPicker);
  });

  group('FileService', () {
    test('saveFile creates a file with contents on Windows', () async {
      const fileName = 'test_save.txt';
      final bytes = [72, 101, 108, 108, 111];

      fileService.forceWindowsForTest = true;
      final result = await fileService.saveFile(fileName, bytes);

      expect(result, contains(fileName));
      final file = File('${tempDir.path}\\$fileName');
      expect(file.existsSync(), true);
      expect(await file.readAsBytes(), bytes);
      fileService.forceWindowsForTest = false;
    });

    test('pickFile returns bytes when successful', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final result = FilePickerResult(
          [PlatformFile(name: 'test.bin', size: 3, bytes: bytes)]);

      when(() => mockPicker.pickFiles(
            type: any(named: 'type'),
            allowedExtensions: any(named: 'allowedExtensions'),
            withData: any(named: 'withData'),
          )).thenAnswer((_) async => result);

      final pickedBytes = await fileService.pickFile();
      expect(pickedBytes, bytes);
    });

    test('pickFile returns null when no file picked', () async {
      when(() => mockPicker.pickFiles(
            type: any(named: 'type'),
            allowedExtensions: any(named: 'allowedExtensions'),
            withData: any(named: 'withData'),
          )).thenAnswer((_) async => null);

      final pickedBytes = await fileService.pickFile();
      expect(pickedBytes, isNull);
    });

    test(
        'saveFile Windows branch completes successfully without mocks throwing',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return tempDir.path;
      });

      const fileName = 'test_success_again.txt';
      final bytes = [1, 2, 3];

      fileService.forceWindowsForTest = true;
      final result = await fileService.saveFile(fileName, bytes);
      expect(result, isA<String>());
      fileService.forceWindowsForTest = false;

      // Reset channel for teardown
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return tempDir.path;
      });
    });

    test('saveFile Android branch execution throws on missing permission',
        () async {
      fileService.forceAndroidForTest = true;
      const fileName = 'android_save.txt';
      final bytes = [10, 20, 30];

      // Mock Android Permissions
      const permissionChannel =
          MethodChannel('flutter.baseflow.com/permissions/methods');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissionChannel,
              (MethodCall methodCall) async {
        return {15: 0}; // 15=Storage, 0=Denied => Throws permission Exception
      });

      expect(
        () => fileService.saveFile(fileName, bytes),
        throwsException,
      );

      fileService.forceAndroidForTest = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissionChannel, null);
    });

    test('saveFile Web branch execution triggers web function', () async {
      fileService.forceWebForTest = true;
      const fileName = 'web_save.txt';
      final bytes = [10, 20, 30];

      // Since we can't truly mock the internal web JS downloads here,
      // we just expect the function to execute the _saveFileWeb branch without issues
      // and hit the fallback path that returns the string on desktop mocks.
      final result = await fileService.saveFile(fileName, bytes);
      expect(result, isA<String>());

      fileService.forceWebForTest = false;
    });
  });
}
