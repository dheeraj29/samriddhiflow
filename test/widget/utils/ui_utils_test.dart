import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/services/auth_service.dart';
import 'package:samriddhi_flow/utils/ui_utils.dart';

class MockAuthService extends Mock implements AuthService {}

class MockLogoutRequestedNotifier extends LogoutRequestedNotifier {
  bool _state = false;

  @override
  bool build() => _state;

  @override
  set value(bool v) {
    _state = v;
    state = v;
  }
}

void main() {
  late MockAuthService mockAuthService;
  late MockLogoutRequestedNotifier mockLogoutNotifier;

  setUp(() {
    mockAuthService = MockAuthService();
    mockLogoutNotifier = MockLogoutRequestedNotifier();

    // Register fallback for ref
    registerFallbackValue(ProviderContainer());
  });

  Widget createWidgetUnderTest(Widget child) {
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuthService),
        logoutRequestedProvider.overrideWith(() => mockLogoutNotifier),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('UIUtils Tests', () {
    testWidgets('handleLogout shows dialog and cancels', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(createWidgetUnderTest(
        Consumer(builder: (context, ref, _) {
          return ElevatedButton(
            key: key,
            onPressed: () {
              UIUtils.handleLogout(context, ref);
            },
            child: const Text('Confirm Logout'),
          );
        }),
      ));

      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();

      expect(find.text('Logout'), findsWidgets); // Title and Button
      expect(find.text('Are you sure you want to logout?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Are you sure you want to logout?'), findsNothing);
      verifyNever(() => mockAuthService.signOut(any()));
    });

    testWidgets('handleLogout shows dialog and confirms', (tester) async {
      when(() => mockAuthService.signOut(any())).thenAnswer((_) async {});

      final key = GlobalKey();
      await tester.pumpWidget(createWidgetUnderTest(
        Consumer(builder: (context, ref, _) {
          return ElevatedButton(
            key: key,
            onPressed: () {
              UIUtils.handleLogout(context, ref);
            },
            child: const Text('Confirm Logout'),
          );
        }),
      ));

      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();

      // Find the logout button in the dialog (red one)
      final logoutBtn = find.widgetWithText(ElevatedButton, 'Logout');
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      verify(() => mockAuthService.signOut(any())).called(1);
    });

    testWidgets('buildSectionHeader renders correctly', (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: UIUtils.buildSectionHeader('Test Header', showDivider: true),
      ));

      expect(find.text('Test Header'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('buildSectionHeader functionality without divider',
        (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: UIUtils.buildSectionHeader('Test Header', showDivider: false),
      ));

      expect(find.text('Test Header'), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('showCommonAboutDialog logic', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              key: key,
              onPressed: () => UIUtils.showCommonAboutDialog(context, '1.0.0'),
              child: const Text('About'),
            );
          }),
        ),
      ));

      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle(); // Animation

      expect(find.text('Samriddhi Flow'), findsOneWidget);
      expect(find.text('1.0.0'), findsOneWidget);
      expect(find.text('Personal Finance Management made simple and secure.'),
          findsOneWidget);
    });
  });
}
