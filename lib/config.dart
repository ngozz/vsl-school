import 'package:flutter/material.dart';

/// Central app configuration.
///
/// `tools/toggle_videos.ps1` flips [CdnConfig.useCdn] together with the
/// `- data/videos/` asset line in pubspec.yaml, so the two can never drift.
/// One flag decides everything:
///
///   - useCdn = false → FULL build: data/videos is bundled as APK assets,
///     producing a **very large** APK (~3 GB). Playback loads straight from
///     assets — fully offline, no network involved.
///   - useCdn = true → SMALL build (~50 MB): data/videos is *not* bundled;
///     videos stream from [baseUrl] and downloaded local copies win over
///     the network.
class CdnConfig {
  /// true = SMALL (CDN) build — videos stream/download from the Workers host.
  /// false = FULL build — data/videos bundled as APK assets (~3 GB APK).
  /// Flipped together with the pubspec assets line by tools/toggle_videos.ps1.
  static const bool useCdn = true;

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
