import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';
import '../config.dart';
import '../services/download_service.dart' show VideoSource;
const _accent = Color(0xFF81C995); // active state colour (always on dark video)

/// 16:9 lesson video with custom controls, SRT captions and a speed dropup.
///
/// Give it new asset paths and it reloads itself. Captions use video_player's
/// own `closedCaptionFile` support; on/off and speed prefs live in
/// [App.settings].
class LessonVideoPlayer extends StatefulWidget {
  final String videoAsset; // e.g. data/videos/TOANL3KB01_02.mp4
  final String captionAsset; // e.g. data/srt/TOANL3KB01_02.srt (may not exist)

  const LessonVideoPlayer({
    super.key,
    required this.videoAsset,
    required this.captionAsset,
  });

  @override
  State<LessonVideoPlayer> createState() => _LessonVideoPlayerState();
}

class _LessonVideoPlayerState extends State<LessonVideoPlayer> {
  VideoPlayerController? _controller;
  Future<void>? _init;
  bool _hasCaptions = false;
  bool _isNetwork = false;

  /// New key per created surface; also bumped after fullscreen because on web
  /// the recycled platform view can end up with an empty texture.
  Key _surfaceKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(LessonVideoPlayer old) {
    super.didUpdateWidget(old);
    if (old.videoAsset != widget.videoAsset) _load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _load() {
    final old = _controller;
    _controller = null;
    // Dispose asynchronously with a guard: disposing while the previous
    // controller's initialize() is still pending can throw on Android.
    if (old != null) {
      unawaited((old.dispose()).catchError((Object e) {
        debugPrint('[VIDEO] stale player dispose: $e');
      }));
    }
    // Resolver order: downloaded file → CDN stream → bundled asset.
    final name = widget.videoAsset.split('/').last; // e.g. TOANL3KB01_02.mp4
    // DownloadService stores _downloaded keys without the .mp4 extension.
    final bare = name.endsWith('.mp4')
        ? name.substring(0, name.length - 4)
        : name;
    final src = !CdnConfig.useCdn
        ? VideoSource.asset
        : App.downloads.resolve(bare);
    _isNetwork = src == VideoSource.network;
    final c = switch (src) {
      VideoSource.asset => VideoPlayerController.asset(
          widget.videoAsset,
          closedCaptionFile: _loadCaptions(widget.captionAsset),
          // Never steal audio focus from other apps.
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        ),
      VideoSource.localFile => VideoPlayerController.file(
          App.downloads.fileFor(bare),
          closedCaptionFile: _loadCaptions(widget.captionAsset),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        ),
      VideoSource.network => VideoPlayerController.networkUrl(
          Uri.parse('${CdnConfig.baseUrl}/videos/$name'),
          closedCaptionFile: _loadCaptions(widget.captionAsset),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        ),
    };
    _controller = c;
    _surfaceKey = UniqueKey();
    _init = _start(c);
  }

  Future<ClosedCaptionFile> _loadCaptions(String asset) async {
    var text = '';
    try {
      text = await rootBundle.loadString(asset);
    } catch (_) {} // no SRT for this video → CC button is disabled
    // Only apply for the video that is still current; a superseded load may
    // resolve after a newer one and would describe the wrong video.
    if (widget.captionAsset == asset) {
      _hasCaptions = text.trim().isNotEmpty;
    }
    return SubRipCaptionFile(text);
  }

  Future<void> _start(VideoPlayerController c) async {
    try {
      await c.initialize();
      if (_controller != c) return; // superseded by a newer video
      final s = App.settings;
      final target = s.rememberSpeed ? s.speed : 1.0;
      // iOS: AVPlayer resets the rate on play() (Apple's own TV app shares
      // this quirk — see flutter/flutter#71264), so the remembered speed is
      // re-asserted once playback is actually running.
      if (target != 1.0) {
        var applied = false;
        late final VoidCallback l;
        l = () {
          if (applied) {
            c.removeListener(l);
            return;
          }
          final v = c.value;
          if (v.isPlaying && !v.isBuffering && v.position > Duration.zero) {
            applied = true;
            c.removeListener(l);
            c.setPlaybackSpeed(target);
          }
        };
        c.addListener(l);
      }
      await c.play();
      if (target != 1.0) await c.setPlaybackSpeed(target);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[VIDEO] ${widget.videoAsset}: $e');
      if (_controller == c) rethrow; // shown as an error icon
    }
  }

  void _enterFullscreen() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final wasPlaying = c.value.isPlaying;
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    Navigator.of(context)
        .push(PageRouteBuilder(
          opaque: false,
          transitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (ctx, _, _) => Scaffold(
            backgroundColor: Colors.black,
            body: _PlayerView(
              controller: c,
              hasCaptions: _hasCaptions,
              isNetwork: _isNetwork,
              isFullscreen: true,
              onFullscreen: () => Navigator.of(ctx).pop(),
            ),
          ),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
        ))
        .then((_) {
      SystemChrome.setPreferredOrientations(
          const [DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      if (!mounted) return;
      setState(() => _surfaceKey = UniqueKey()); // fresh surface (web fix)
      if (wasPlaying) c.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(
          color: Colors.black,
          child: FutureBuilder<void>(
            future: _init,
            builder: (context, snap) {
              if (snap.hasError) {
                return const Center(
                    child: Icon(Icons.error_outline,
                        size: 40, color: Colors.white54));
              }
              if (snap.connectionState != ConnectionState.done ||
                  c == null ||
                  !c.value.isInitialized) {
                return const Center(child: CircularProgressIndicator());
              }
              return _PlayerView(
                key: _surfaceKey,
                controller: c,
                hasCaptions: _hasCaptions,
                isNetwork: _isNetwork,
                isFullscreen: false,
                onFullscreen: _enterFullscreen,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Frame + captions + controls. Used inline and in the fullscreen route.
class _PlayerView extends StatefulWidget {
  final VideoPlayerController controller;
  final bool hasCaptions;
  final bool isNetwork;
  final bool isFullscreen;
  final VoidCallback onFullscreen;

  const _PlayerView({
    super.key,
    required this.controller,
    required this.hasCaptions,
    required this.isNetwork,
    required this.isFullscreen,
    required this.onFullscreen,
  });

  @override
  State<_PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<_PlayerView> {
  /// Whether the control bar is on screen; captions ride above it
  /// (YouTube-style) and drop when it fades out.
  final ValueNotifier<bool> _controlsVisible = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _controlsVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.controller.value.size;
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: size.width <= 0 ? 1920.0 : size.width,
            height: size.height <= 0 ? 1080.0 : size.height,
            child: VideoPlayer(widget.controller),
          ),
        ),
        _Captions(
          controller: widget.controller,
          isFullscreen: widget.isFullscreen,
          controlsVisible: _controlsVisible,
        ),
        _Controls(
          controller: widget.controller,
          hasCaptions: widget.hasCaptions,
          isNetwork: widget.isNetwork,
          isFullscreen: widget.isFullscreen,
          onFullscreen: widget.onFullscreen,
          controlsVisible: _controlsVisible,
        ),
      ],
    );
  }
}

class _Captions extends StatelessWidget {
  final VideoPlayerController controller;
  final bool isFullscreen;
  final ValueNotifier<bool> controlsVisible;

  const _Captions({
    required this.controller,
    required this.isFullscreen,
    required this.controlsVisible,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ListenableBuilder(
        listenable: Listenable.merge([App.settings, controller]),
        builder: (_, _) {
          final text = controller.value.caption.text;
          if (!App.settings.subtitles || text.isEmpty) {
            return const SizedBox.shrink();
          }
          return Align(
            alignment: Alignment.bottomCenter,
            child: ValueListenableBuilder<bool>(
              valueListenable: controlsVisible,
              builder: (_, controlsUp, _) {
                // Ride above the control bar while it is on screen
                // (YouTube-style), drop low when it fades out.
                final bottom =
                    controlsUp ? (isFullscreen ? 76.0 : 58.0) : (isFullscreen ? 20.0 : 14.0);
                return AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xAA000000),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isFullscreen ? 20 : 15,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// [play] [——seek——] [0:01 / 0:03] [CC] [speed] [fullscreen]
/// Tap the video to show/hide. Auto-hides while playing.
class _Controls extends StatefulWidget {
  final VideoPlayerController controller;
  final bool hasCaptions;
  final bool isNetwork; // streamed over http → seek only when fully buffered
  final bool isFullscreen;
  final VoidCallback onFullscreen; // enter, or exit when isFullscreen
  final ValueNotifier<bool> controlsVisible; // captions ride this

  const _Controls({
    required this.controller,
    required this.hasCaptions,
    this.isNetwork = false,
    required this.isFullscreen,
    required this.onFullscreen,
    required this.controlsVisible,
  });

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  Timer? _hideTimer;
  bool _visible = true;
  double? _dragMs; // non-null while scrubbing
  bool _scrubUnlocked = false; // sticky: true once the whole file is buffered

  VideoPlayerController get _c => widget.controller;

  /// Seek is locked while streaming and not yet fully buffered.
  bool get _scrubLocked => widget.isNetwork && !_scrubUnlocked;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(Duration(seconds: AppConfig.autoHideControlsSeconds), () {
      if (mounted && _c.value.isPlaying && _dragMs == null) {
        setState(() => _visible = false);
      }
    });
  }

  void _poke() {
    if (!_visible) setState(() => _visible = true);
    _scheduleHide();
  }

  Future<void> _togglePlay(bool playing, bool ended) async {
    if (ended) {
      if (_scrubLocked) return; // seek back to 0 stays locked until buffered
      await _c.seekTo(Duration.zero);
      await _c.play();
    } else {
      await (playing ? _c.pause() : _c.play());
    }
    _poke();
  }

  /// YouTube-style "dropup": the menu opens ABOVE the button, right-aligned
  /// to it. Uses the app's popup-menu theme, so it follows light/dark/black.
  Future<void> _pickSpeed(BuildContext button, double current) async {
    _hideTimer?.cancel(); // keep the bar up while the menu is open
    const itemH = 40.0;
    final box = button.findRenderObject() as RenderBox;
    final overlay = Overlay.of(button).context.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final menuH = AppConfig.playbackSpeeds.length * itemH + 16; // + menu's vertical padding
    final picked = await showMenu<double>(
      context: button,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(origin.dx, origin.dy - menuH - 4, box.size.width, menuH),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final r in AppConfig.playbackSpeeds)
          CheckedPopupMenuItem<double>(
            value: r,
            checked: r == current,
            height: itemH,
            child: Text(r == 1.0 ? '1×' : '$r×'),
          ),
      ],
    );
    if (picked != null) {
      await _c.setPlaybackSpeed(picked);
      App.settings.setSpeed(picked);
    }
    _poke();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _c,
      builder: (context, value, _) {
        final durMs = value.duration.inMilliseconds;
        final maxMs = durMs > 0 ? durMs.toDouble() : 1.0;
        final posMs = (_dragMs ?? value.position.inMilliseconds.toDouble())
            .clamp(0.0, maxMs);
        final ended = durMs > 0 &&
            !value.isPlaying &&
            value.position.inMilliseconds >= durMs - 50;
        final show = _visible || !value.isPlaying || _dragMs != null;
        // Captions ride above the bar; assigning the same value is a no-op
        // for listeners, so this is cheap on every position tick.
        widget.controlsVisible.value = show;

        // CDN streams ignore Range (200-only): the player re-downloads from
        // byte 0 to satisfy a mid-file seek. Lock the scrubber until the
        // whole small file is buffered — then seeking is free forever.
        final buffered = value.buffered;
        if (durMs > 0 &&
            buffered.isNotEmpty &&
            buffered.last.end.inMilliseconds >= durMs - 30) {
          _scrubUnlocked = true;
        }
        final scrubLocked = _scrubLocked;

        Widget bar = Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, widget.isFullscreen ? 8 : 2),
          child: Row(
            children: [
              _BarButton(
                icon: ended
                    ? Icons.replay
                    : value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                tooltip: ended ? 'Phát lại' : value.isPlaying ? 'Tạm dừng' : 'Phát',
                onPressed: (ended && scrubLocked)
                    ? null
                    : () => _togglePlay(value.isPlaying, ended),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                      elevation: 0,
                      pressedElevation: 0,
                    ),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    min: 0,
                    max: maxMs,
                    value: posMs,
                    onChangeStart: scrubLocked
                        ? null
                        : (v) => setState(() => _dragMs = v),
                    onChanged: scrubLocked
                        ? null
                        : (v) {
                            setState(() => _dragMs = v);
                            _c.seekTo(Duration(milliseconds: v.round()));
                          },
                    onChangeEnd: scrubLocked
                        ? null
                        : (_) {
                            setState(() => _dragMs = null);
                            _scheduleHide();
                          },
                  ),
                ),
              ),
              Text(
                '${_fmt(Duration(milliseconds: posMs.round()))} / ${_fmt(value.duration)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              // CC — on/off is remembered in settings (default on).
              ListenableBuilder(
                listenable: App.settings,
                builder: (_, _) {
                  final on = App.settings.subtitles;
                  return _BarButton(
                    icon: on
                        ? Icons.closed_caption
                        : Icons.closed_caption_outlined,
                    tooltip: 'Phụ đề',
                    color: on ? _accent : Colors.white,
                    onPressed: widget.hasCaptions
                        ? () {
                            App.settings.setSubtitles(!on);
                            _poke();
                          }
                        : null,
                  );
                },
              ),
              // Speed — opens the dropup. Tinted while not at normal speed.
              Builder(
                builder: (ctx) => _BarButton(
                  icon: Icons.slow_motion_video,
                  tooltip: 'Tốc độ phát',
                  color: value.playbackSpeed == 1.0 ? Colors.white : _accent,
                  onPressed: () => _pickSpeed(ctx, value.playbackSpeed),
                ),
              ),
              _BarButton(
                icon: widget.isFullscreen
                    ? Icons.fullscreen_exit
                    : Icons.fullscreen,
                tooltip: widget.isFullscreen ? 'Thu nhỏ' : 'Toàn màn hình',
                onPressed: widget.onFullscreen,
              ),
            ],
          ),
        );
        if (widget.isFullscreen) bar = SafeArea(top: false, child: bar);

        return Stack(
          fit: StackFit.expand,
          children: [
            // Tap target for the video itself (sibling of the bar, so taps on
            // the bar never reach it).
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => _visible = !_visible);
                  if (_visible) _scheduleHide();
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: !show,
                child: AnimatedOpacity(
                  opacity: show ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: .7),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14), // gradient room
                      child: bar,
                    ),
                  ),
                ),
              ),
            ),
            // Seek-lock hint: spinner only — when it vanishes, seek is
            // unlocked. Kept at the top so it never covers the subtitles.
            if (scrubLocked && show)
              Positioned(
                left: 0,
                right: 0,
                top: widget.isFullscreen ? 16 : 12,
                child: IgnorePointer(
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0x99000000),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 9, vertical: 9),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = h > 0 ? m.toString().padLeft(2, '0') : '$m';
    return '${h > 0 ? '$h:' : ''}$mm:${s.toString().padLeft(2, '0')}';
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed; // null → disabled (dimmed)

  const _BarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      iconSize: 22,
      color: color,
      disabledColor: Colors.white30,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      visualDensity: VisualDensity.compact,
    );
  }
}