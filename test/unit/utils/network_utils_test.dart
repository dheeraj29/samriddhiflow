import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:samriddhi_flow/utils/network_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');

  group('NetworkUtils', () {
    test('isOffline returns true when no connectivity', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'check') {
          return ['none'];
        }
        return null;
      });

      final result = await NetworkUtils.isOffline();
      expect(result, true);
    });

    test('isOffline returns false when wifi connected', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'check') {
          return ['wifi'];
        }
        return null;
      });

      final result = await NetworkUtils.isOffline();
      expect(result, false);
    });

    test('isOffline returns false when mobile connected', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'check') {
          return ['mobile'];
        }
        return null;
      });

      final result = await NetworkUtils.isOffline();
      expect(result, false);
    });

    test(
        'isOffline handles MissingPluginException by failing open (returning false)',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw MissingPluginException();
      });

      final result = await NetworkUtils.isOffline();
      expect(result, false);
    });

    test('hasActualInternet returns true on non-web platforms', () async {
      final result = await NetworkUtils.hasActualInternet();
      expect(result, true);
    });
    test('isOffline uses mockIsOffline when provided', () async {
      NetworkUtils.mockIsOffline = () async => true;
      final result = await NetworkUtils.isOffline();
      expect(result, true);
      NetworkUtils.mockIsOffline = null; // cleanup
    });

    test('isOffline returns fallback false on unexpected exception', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw Exception("Random error");
      });
      final result = await NetworkUtils.isOffline();
      expect(result, false);
    });

    test(
        'isOffline with forceWebForTest triggers _handleWebFallback on MissingPluginException',
        () async {
      NetworkUtils.forceWebForTest = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw MissingPluginException('No implementation found');
      });

      // _handleWebFallback sees "MissingPluginException" → calls checkWebOnline()
      // Stub returns true → !true = false (online)
      final result = await NetworkUtils.isOffline();
      expect(result, false);

      NetworkUtils.forceWebForTest = false;
    });

    test(
        'isOffline with forceWebForTest triggers _handleWebFallback else branch on random error',
        () async {
      NetworkUtils.forceWebForTest = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw Exception('Some random network error');
      });

      // _handleWebFallback sees non-MissingPlugin error → logs and returns false
      final result = await NetworkUtils.isOffline();
      expect(result, false);

      NetworkUtils.forceWebForTest = false;
    });

    test('hasActualInternet with forceWebForTest hits web reachability path',
        () async {
      NetworkUtils.forceWebForTest = true;

      // Stub checkActualWebReachability returns true
      final result = await NetworkUtils.hasActualInternet();
      expect(result, true);

      NetworkUtils.forceWebForTest = false;
    });
  });
}
