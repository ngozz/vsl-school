import 'package:flutter/material.dart';

/// Central app configuration.
///
/// `tools/toggle_videos.ps1` flips [CdnConfig.videosBundled] together with the
/// `- data/videos/` asset line in pubspec.yaml, so they can never drift:
///
///   - videosBundled = true  → full APK (~3 GB), playback straight from
///     bundled assets, no network involved at all.
///   - videosBundled = false → small APK (~35 MB); the player resolves a
///     local downloaded copy first, then streams from [CdnConfig.baseUrl].
class CdnConfig {
  /// Master switch for streaming/downloading from the CDN. Full (bundled)
  /// builds ignore this and always play from assets.
  static const bool useCdn = false;

  /// Does this build bundle data/videos as APK assets? Kept in sync with
  /// pubspec.yaml by tools/toggle_videos.ps1.
  static const bool videosBundled = false;

  /// Base URL of the media Workers (static assets) host, no trailing slash.
  /// Serves /videos/{name}.mp4, /srt/, /thumbs/, /json mirrors.
  static const String baseUrl = 'https://vsl-school-media.ngozz.workers.dev';
}

/// Playback & theming knobs.
class AppConfig {
  /// Entries shown in the player's speed dropup. Stored user speeds outside
  /// this list are simply not offered again in the menu.
  static const List<double> playbackSpeeds = [0.25, 0.5, 0.75, 1.0, 1.5];

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
