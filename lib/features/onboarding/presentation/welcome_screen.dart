import 'package:flutter/material.dart';
import 'package:synclip/app/theme/tokens.dart';
import 'package:synclip/shared/widgets/device_ring.dart';

/// First screen: the promise and the three ways in (PLAN.md §7.6.1).
class WelcomeScreen extends StatelessWidget {
  const new({super.key});

  static const _illustration = DeviceRing(
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
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.content_paste_rounded,
                            size: 18,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Synclip',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontVariations: const [FontVariation.width(125)],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: ExcludeSemantics(child: _illustration),
                        ),
                      ),
                    ),
                    Text(
                      'Your clipboard, on every device.',
                      style: theme.textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Copy on your laptop, paste on your phone. '
                      'End-to-end encrypted: the server only ever sees '
                      'scrambled text.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
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
