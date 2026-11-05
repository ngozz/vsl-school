import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;

/// Central app configuration.
///
/// The build flavor decides where media comes from. Flavors are declared in
/// pubspec.yaml (`default-flavor: lite`) and mirrored by Android product
/// flavors, iOS build configurations and Xcode schemes:
///
///   - `lite` (default, and the only variant for web): data/videos is *not*
///     bundled. Videos stream from [baseUrl], and downloaded local copies
///     win over the network.
///   - `full`: data/videos is bundled as APK/IPA assets, producing a
///     **very large** build (~3 GB). Playback loads straight from assets —
///     fully offline, no network involved.
class CdnConfig {
  /// true = lite (CDN) build — videos stream/download from the Workers host.
  /// false = full build — data/videos bundled as assets.
  static const bool useCdn = appFlavor != 'full';

  /// Base URL of the media Workers (static assets) host, no trailing slash.
  /// Serves /videos/{name}.mp4, /srt/, /thumbs/, /json mirrors.
  static const String baseUrl = 'https://vsl-school-media.ngozz.workers.dev';
}

/// Playback & theming knobs.
class AppConfig {
  /// Entries shown in the player's speed dropup. Stored user speeds outside
  /// this list are simply not offered again in the menu.
  static const List<double> playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5];

  /// Seconds without interaction before the controls fade out.
  static const int autoHideControlsSeconds = 3;

  /// Material You seed for all three themes.
  static const Color seedColor = Color(0xFF4CAF50);

  /// School grades shown as filter chips.
  static const List<int> grades = [1, 2, 3, 4, 5];

  /// Captions default (first run / when nothing stored).
  static const bool defaultSubtitles = true;

  /// Default for the "check for content updates at startup" user toggle.
  static const bool checkUpdatesAtStart = true;
}
