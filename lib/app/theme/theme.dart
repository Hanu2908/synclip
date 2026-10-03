import 'package:flutter/material.dart';
import 'package:synclip/app/theme/tokens.dart';

/// Material 3 theme generated from the brand seed (PLAN.md §7.1–7.2).
ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Tokens.seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  final base = ThemeData(colorScheme: scheme, fontFamily: Tokens.fontSans);
  final text = base.textTheme;

  TextStyle? wide(TextStyle? style) => style?.copyWith(
    fontWeight: FontWeight.w700,
    fontVariations: const [FontVariation.width(Tokens.headlineWidth)],
  );

  return base.copyWith(
    textTheme: text.copyWith(
      displaySmall: wide(text.displaySmall),
      headlineLarge: wide(text.headlineLarge),
      headlineMedium: wide(text.headlineMedium),
      headlineSmall: wide(text.headlineSmall),
    ),
  );
}
