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

  testWidgets('makes the Synclip wordmark the big, centred hero', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(Brightness.light));

    final wordmark = find.text('Synclip', findRichText: true);
    expect(wordmark, findsOneWidget);
    expect(tester.getSemantics(wordmark), isSemantics(isHeader: true));

    final screen = tester.getSize(find.byType(WelcomeScreen));
    final centre = tester.getCenter(wordmark);
    expect(centre.dx, moreOrLessEquals(screen.width / 2, epsilon: 1));
    expect(
      centre.dy,
      inInclusiveRange(screen.height * .25, screen.height * .6),
    );

    final tagline = find.text('Your clipboard, on every device.');
    expect(
      tester.widget<RichText>(wordmark).text.style!.fontSize,
      greaterThan(2 * tester.widget<Text>(tagline).style!.fontSize!),
    );
    handle.dispose();
  });

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
