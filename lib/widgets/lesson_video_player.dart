import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';
import '../config.dart';
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
    // Small (CDN) build: stream over https; full build: bundled asset.
    final c = CdnConfig.videosBundled
        ? VideoPlayerController.asset(
            widget.videoAsset,
            closedCaptionFile: _loadCaptions(widget.captionAsset),
            // Never steal audio focus from other apps.
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          )
        : VideoPlayerController.networkUrl(
            Uri.parse(
                '${CdnConfig.baseUrl}/videos/${widget.videoAsset.split('/').last}'),
            closedCaptionFile: _loadCaptions(widget.captionAsset),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
    _controller = c;
    _surfaceKey = UniqueKey();
    _init = _start(c);
  }

  Future<ClosedCaptionFile> _loadCaptions(String asset) async {
    var text = '';
    try {
      text = await rootBundle.loadString(asset);
    } catch (_) {} // no SRT for this video â†’ CC button is disabled
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
      await c.setPlaybackSpeed(s.rememberSpeed ? s.speed : 1.0);
      await c.play();
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
class _PlayerView extends StatelessWidget {
  final VideoPlayerController controller;
  final bool hasCaptions;
  final bool isFullscreen;
  final VoidCallback onFullscreen;

  const _PlayerView({
    super.key,
    required this.controller,
    required this.hasCaptions,
    required this.isFullscreen,
    required this.onFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: size.width <= 0 ? 1920.0 : size.width,
            height: size.height <= 0 ? 1080.0 : size.height,
            child: VideoPlayer(controller),
          ),
        ),
        _Captions(controller: controller, isFullscreen: isFullscreen),
        _Controls(
          controller: controller,
          hasCaptions: hasCaptions,
          isFullscreen: isFullscreen,
          onFullscreen: onFullscreen,
        ),
      ],
    );
  }
}

class _Captions extends StatelessWidget {
  final VideoPlayerController controller;
  final bool isFullscreen;
  const _Captions({required this.controller, required this.isFullscreen});

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
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, isFullscreen ? 64 : 48),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xAA000000),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            ),
          );
        },
      ),
    );
  }
}

/// [play] [â€”â€”seekâ€”â€”] [0:01 / 0:03] [CC] [speed] [fullscreen]
/// Tap the video to show/hide. Auto-hides while playing.
class _Controls extends StatefulWidget {
  final VideoPlayerController controller;
  final bool hasCaptions;
  final bool isFullscreen;
  final VoidCallback onFullscreen; // enter, or exit when isFullscreen

  const _Controls({
    required this.controller,
    required this.hasCaptions,
    required this.isFullscreen,
    required this.onFullscreen,
  });

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  Timer? _hideTimer;
  bool _visible = true;
  double? _dragMs; // non-null while scrubbing

  VideoPlayerController get _c => widget.controller;

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
            child: Text(r == 1.0 ? 'Chuáº©n' : '$rÃ—'),
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
                tooltip: ended ? 'PhÃ¡t láº¡i' : value.isPlaying ? 'Táº¡m dá»«ng' : 'PhÃ¡t',
                onPressed: () => _togglePlay(value.isPlaying, ended),
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
                    onChangeStart: (v) => setState(() => _dragMs = v),
                    onChanged: (v) {
                      setState(() => _dragMs = v);
                      _c.seekTo(Duration(milliseconds: v.round()));
                    },
                    onChangeEnd: (_) {
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
              // CC â€” on/off is remembered in settings (default on).
              ListenableBuilder(
                listenable: App.settings,
                builder: (_, _) {
                  final on = App.settings.subtitles;
                  return _BarButton(
                    icon: on
                        ? Icons.closed_caption
                        : Icons.closed_caption_outlined,
                    tooltip: 'Phá»¥ Ä‘á»',
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
              // Speed â€” opens the dropup. Tinted while not at normal speed.
              Builder(
                builder: (ctx) => _BarButton(
                  icon: Icons.slow_motion_video,
                  tooltip: 'Tá»‘c Ä‘á»™ phÃ¡t',
                  color: value.playbackSpeed == 1.0 ? Colors.white : _accent,
                  onPressed: () => _pickSpeed(ctx, value.playbackSpeed),
                ),
              ),
              _BarButton(
                icon: widget.isFullscreen
                    ? Icons.fullscreen_exit
                    : Icons.fullscreen,
                tooltip: widget.isFullscreen ? 'Thu nhá»' : 'ToÃ n mÃ n hÃ¬nh',
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
  final VoidCallback? onPressed; // null â†’ disabled (dimmed)

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