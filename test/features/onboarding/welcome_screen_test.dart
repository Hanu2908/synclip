import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synclip/app/theme/theme.dart';
import 'package:synclip/features/onboarding/presentation/welcome_screen.dart';

Widget _app(Brightness brightness, {double textScale = 1}) => MaterialApp(
  theme: buildTheme(brightness),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: const WelcomeScreen(),
  ),
);

void main() {
  for (final brightness in Brightness.values) {
    group('WelcomeScreen ($brightness)', () {
      testWidgets('shows the promise and the three ways in', (tester) async {
        await tester.pumpWidget(_app(brightness));

        expect(find.text('Your clipboard, on every device.'), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, 'Create a Quick Room'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(FilledButton, 'Join with code or QR'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(TextButton, 'Sign in for My Devices'),
          findsOneWidget,
        );
      });

      testWidgets('meets tap-target, label and contrast guidelines', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(brightness));

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    });
  }

  testWidgets('survives 200% text on a small phone without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(Brightness.light, textScale: 2));

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Sign in for My Devices'), 200);
    expect(find.text('Sign in for My Devices'), findsOneWidget);
  });
}
