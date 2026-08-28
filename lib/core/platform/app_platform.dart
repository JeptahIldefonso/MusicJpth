import 'package:flutter/foundation.dart';

/// Platform capability checks, kept out of widgets per `CLAUDE.md` §07.
abstract final class AppPlatform {
  const AppPlatform._();

  /// Whether this target is Android — the only supported platform that gates
  /// reading the user's files behind a runtime permission.
  static bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// Whether this target uses desktop chrome.
  ///
  /// Desktop gets a sidebar, mobile gets bottom tabs — see `DESIGN.md`
  /// (Navigation). Deliberately platform-based rather than width-based: a
  /// narrowed Windows window must not fall back to mobile bottom tabs.
  static bool get isDesktop => switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux => true,
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.fuchsia => false,
  };
}
