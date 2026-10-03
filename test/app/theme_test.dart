import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synclip/app/theme/theme.dart';
import 'package:synclip/app/theme/tokens.dart';

void main() {
  for (final brightness in Brightness.values) {
    test('$brightness theme comes from the brand seed', () {
      final theme = buildTheme(brightness);

      expect(theme.colorScheme.brightness, brightness);
      expect(theme.useMaterial3, isTrue);
      expect(theme.textTheme.bodyLarge?.fontFamily, Tokens.fontSans);
      expect(
        theme.textTheme.headlineLarge?.fontVariations,
        contains(const FontVariation.width(Tokens.headlineWidth)),
      );
    });
  }

  test('light and dark schemes differ (dark is designed, not inverted)', () {
    expect(
      buildTheme(Brightness.light).colorScheme.surface,
      isNot(buildTheme(Brightness.dark).colorScheme.surface),
    );
  });
}
