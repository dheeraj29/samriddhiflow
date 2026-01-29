import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/utils/network_utils.dart';

void main() {
  const MethodChannel channel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'check') {
        return ['wifi']; // Default List<String>
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('isOffline returns false when connectivity is wifi', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'check') {
        return ['wifi'];
      }
      return null;
    });

    final isOffline = await NetworkUtils.isOffline();
    expect(isOffline, false);
  });

  test('isOffline returns false when connectivity is mobile', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'check') {
        return ['mobile'];
      }
      return null;
    });

    final isOffline = await NetworkUtils.isOffline();
    expect(isOffline, false);
  });

  test('isOffline returns true when connectivity is none', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'check') {
        return ['none'];
      }
      return null;
    });

    final isOffline = await NetworkUtils.isOffline();
    expect(isOffline, true);
  });

  test('isOffline returns false (Fail Open) on exception', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      throw Exception('Mock Error');
    });

    final isOffline = await NetworkUtils.isOffline();
    expect(isOffline,
        false); // Fail Safe matches logic (line 37 catches, fallback usually returns false or based on web)
  });
}
