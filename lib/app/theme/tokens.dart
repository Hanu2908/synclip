import 'package:flutter/painting.dart';

/// Raw design values: the only place hex colours and font names live
/// (PLAN.md §7). Widgets read `ColorScheme` roles and these constants.
abstract final class Tokens {
  /// Synclip Tangerine, the brand seed for every generated colour role.
  static const seed = Color(0xFFFF7A1A);

  static const fontSans = 'RobotoFlex';

  /// Width axis for headlines: the brand's wide display voice.
  static const headlineWidth = 120.0;

  /// The wordmark runs at Roboto Flex's widest setting.
  static const wordmarkWidth = 151.0;

  /// Device colours for ring nodes and source chips. The full 8-colour set
  /// (PLAN.md §7.1) arrives with per-device colour picking in M1.
  static const deviceBlue = Color(0xFF2E6FC4);
  static const deviceTeal = Color(0xFF14826F);
  static const deviceViolet = Color(0xFF7E50C9);

  /// Screen gutter on compact windows.
  static const gutter = 24.0;
}
