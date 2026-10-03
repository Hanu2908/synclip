import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:synclip/app/theme/tokens.dart';
import 'package:synclip/shared/widgets/device_ring.dart';

/// First screen: the brand as the hero, then the three ways in
/// (PLAN.md §7.6.1).
class WelcomeScreen extends StatelessWidget {
  const new({super.key});

  static const _illustration = DeviceRing(
    size: 150,
    self: RingNode(
      name: 'this device',
      icon: Icons.smartphone_rounded,
      color: Tokens.seed,
    ),
    others: [
      RingNode(
        name: 'laptop',
        icon: Icons.laptop_rounded,
        color: Tokens.deviceBlue,
      ),
      RingNode(
        name: 'desktop',
        icon: Icons.desktop_windows_rounded,
        color: Tokens.deviceTeal,
      ),
      RingNode(
        name: 'browser',
        icon: Icons.language_rounded,
        color: Tokens.deviceViolet,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const tall = Size.fromHeight(56);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Tokens.gutter,
              24,
              Tokens.gutter,
              16,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: viewport.maxHeight - 40),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const ExcludeSemantics(child: _illustration),
                          const SizedBox(height: 28),
                          Semantics(
                            header: true,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(text: 'Syn'),
                                  TextSpan(
                                    text: 'clip',
                                    style: TextStyle(color: scheme.primary),
                                  ),
                                ],
                              ),
                              // A logotype: sized by the screen, not by
                              // the text-size setting (WCAG 1.4.4 exempt).
                              textScaler: TextScaler.noScaling,
                              style: theme.textTheme.displayLarge?.copyWith(
                                fontSize: math.min(
                                  112,
                                  (viewport.maxWidth - 2 * Tokens.gutter) / 4.4,
                                ),
                                height: 1,
                                letterSpacing: -2,
                                fontWeight: FontWeight.w900,
                                fontVariations: const [
                                  FontVariation.width(Tokens.wordmarkWidth),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Your clipboard, on every device.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Copy on your laptop, paste on your phone. '
                            'End-to-end encrypted: the server only ever '
                            'sees scrambled text.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    // ponytail: buttons are inert until the create/join/sign-in flows land in M1/M6.
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: tall),
                      onPressed: () {},
                      child: const Text('Create a Quick Room'),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(minimumSize: tall),
                      onPressed: () {},
                      child: const Text('Join with code or QR'),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () {},
                      child: const Text('Sign in for My Devices'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
