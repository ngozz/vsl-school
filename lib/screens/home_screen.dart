import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../main.dart';
import '../models/lesson.dart';
import '../services/settings_service.dart';
import '../widgets/download_banner.dart';
import '../widgets/download_dialogs.dart';
import '../widgets/onboarding.dart';
import '../config.dart' show AppConfig, CdnConfig;
import 'lesson_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _ready = false;
  String? _error;
  Subject _subject = Subject.math;
  int _grade = 1;
  List<Lesson> _lessons = const [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // Settings must be loaded before `introSeen` is read below, otherwise
      // the onboarding can re-appear on every launch.
      await Future.wait([App.lessons.load(), App.settings.load()]);
      if (!mounted) return;
      _applyFilter();
      await App.downloads.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
      // Surface a silent downloader failure instead of degrading quietly.
      if (CdnConfig.useCdn &&
          !kIsWeb &&
          (Platform.isAndroid || Platform.isIOS) &&
          !App.downloads.active) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _snack(context.l10n.cdnUnavailable);
          }
        });
      }
      // First launch: show the onboarding once (re-openable in settings).
      if (!App.settings.introSeen) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const OnboardingPage(), fullscreenDialog: true));
          App.settings.setIntroSeen();
        });
      }
      if (App.downloads.active && App.settings.checkUpdates) {
        unawaited(_startupUpdateCheck());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _ready = true;
        });
      }
    }
  }

  /// iOS: opening a not-fully-downloaded lesson blocks on the download
  /// popup (progress shows on the home screen); Android streams directly.
  Future<void> _openLesson(Lesson lesson) async {
    final dl = App.downloads;
    if (dl.active && !kIsWeb && Platform.isIOS) {
      final entries = dl.entriesForLesson(lesson.id);
      if (entries != null &&
          entries.any((e) => !dl.hasPlayableLocal(e.name))) {
        final ok =
            await DownloadDialogs.ensureLessonDownloaded(context, dl, entries);
        if (!mounted) return;
        if (!ok) return;
      }
    }
    if (!mounted) return;
    Navigator.of(context).push(
        MaterialPageRoute(builder: (ctx) => LessonScreen(lesson: lesson)));
  }

  Future<void> _deleteAllData() async {
    final dl = App.downloads;
    if (dl.downloadedCount == 0) return;
    if (!await DownloadDialogs.confirmDeleteAll(context, dl)) return;
    if (!mounted) return;
    final n = await dl.deleteAll();
    if (mounted) _snack(context.l10n.deletedVideos(n));
  }

  Future<void> _showIntro() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const OnboardingPage(), fullscreenDialog: true));
    App.settings.setIntroSeen();
  }

  /// Auto-*check* at startup (cheap manifest fetch); applying is manual.
  Future<void> _startupUpdateCheck() async {
    await App.updates.check();
    final diffs = App.updates.diffsFor(App.downloads);
    if (!mounted ||
        diffs.isEmpty ||
        App.updates.dismissedThisSession ||
        App.downloads.downloadedCount == 0) {
      return;
    }
    await DownloadDialogs.showUpdatePrompt(context, diffs);
  }

  void _applyFilter() {
    _lessons = App.lessons.byFilter(_subject, _grade);
  }

  // ── Download actions ─────────────────────────────────────────────────────

  Future<void> _downloadAllContent() async {
    final dl = App.downloads;
    if (!dl.active) return;
    final remaining = dl.remainingEntries();
    final bytes = remaining.fold(0, (a, e) => a + e.size);
    if (remaining.isEmpty) {
      _snack(context.l10n.allDownloaded);
      return;
    }
    if (!await DownloadDialogs.confirmBatch(context, remaining.length, bytes)) {
      return;
    }
    if (!mounted) return;
    if (!await DownloadDialogs.ensureNetworkOk(context, dl, bytes)) {
      if (mounted) _snack(context.l10n.downloadOnWifi);
      return;
    }
    if (!mounted) return;
    final started = dl.enqueueAll(remaining);
    _snack(context.l10n.downloadStarted(started));
  }

  Future<void> _manualUpdateCheck() async {
    await App.updates.check();
    if (!mounted) return;
    if (App.updates.lastError != null) {
      _snack(context.l10n.updateCheckFailed('${App.updates.lastError}'));
      return;
    }
    final diffs = App.updates.diffsFor(App.downloads);
    if (diffs.isEmpty) {
      _snack(context.l10n.upToDate);
      return;
    }
    await DownloadDialogs.showUpdatePrompt(context, diffs);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Settings sheet ───────────────────────────────────────────────────────

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return AnimatedBuilder(
          animation: Listenable.merge([App.settings, App.downloads, App.updates]),
          builder: (sheetContext, _) {
            final dl = App.downloads;
            final l = sheetContext.l10n;
            final optionTitle = theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600);
            final muted = theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.settingsTitle, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 16),
                      Text(l.settingsLanguage, style: optionTitle),
                      const SizedBox(height: 8),
                      SegmentedButton<AppLanguage>(
                        showSelectedIcon: false, // no width change on select
                        segments: [
                          ButtonSegment(
                            value: AppLanguage.vi,
                            label: SizedBox(
                              width: 96,
                              child: Center(child: Text(l.languageVietnamese)),
                            ),
                          ),
                          ButtonSegment(
                            value: AppLanguage.en,
                            label: SizedBox(
                              width: 96,
                              child: Center(child: Text(l.languageEnglish)),
                            ),
                          ),
                        ],
                        selected: {App.settings.language},
                        onSelectionChanged: (sel) =>
                            App.settings.setLanguage(sel.first),
                      ),
                      const SizedBox(height: 20),
                      Text(l.settingsTheme, style: optionTitle),
                      const SizedBox(height: 8),
                      SegmentedButton<ThemeChoice>(
                        showSelectedIcon: false, // no width change on select
                        segments: [
                          ButtonSegment(
                              value: ThemeChoice.dark,
                              label: SizedBox(
                                  width: 60,
                                  child: Center(child: Text(l.themeDark)))),
                          ButtonSegment(
                              value: ThemeChoice.black,
                              label: SizedBox(
                                  width: 60,
                                  child: Center(child: Text(l.themeBlack)))),
                          ButtonSegment(
                              value: ThemeChoice.light,
                              label: SizedBox(
                                  width: 60,
                                  child: Center(child: Text(l.themeLight)))),
                        ],
                        selected: {App.settings.theme},
                        onSelectionChanged: (sel) =>
                            App.settings.setTheme(sel.first),
                      ),
                      const SizedBox(height: 4),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(l.rememberSpeed, style: optionTitle),
                        subtitle: Text(l.rememberSpeedHint, style: muted),
                        value: App.settings.rememberSpeed,
                        onChanged: (v) => App.settings.setRememberSpeed(v),
                      ),
                      if (dl.active) ...[
                        const SizedBox(height: 12),
                        Text(l.settingsDownloads, style: optionTitle),
                        const SizedBox(height: 8),
                        Text(
                          l.downloadedSummary(
                            dl.downloadedLessonCount,
                            dl.catalogLessonCount,
                            dl.downloadedCount,
                            _fmtMB(dl.downloadedBytes),
                          ),
                          style: muted,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(l.checkUpdates, style: optionTitle),
                          subtitle: Text(l.checkUpdatesOff, style: muted),
                          value: App.settings.checkUpdates,
                          onChanged: (v) => App.settings.setCheckUpdates(v),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.download_for_offline_outlined,
                                  size: 18),
                              label: Text(l.downloadAll),
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                _downloadAllContent();
                              },
                            ),
                            OutlinedButton.icon(
                              icon: App.updates.checking
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.sync, size: 18),
                              label: Text(l.checkNow),
                              onPressed: App.updates.checking
                                  ? null
                                  : () {
                                      Navigator.pop(sheetContext);
                                      _manualUpdateCheck();
                                    },
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: Text(l.deleteDownloaded),
                              onPressed: dl.downloadedCount == 0
                                  ? null
                                  : () {
                                      Navigator.pop(sheetContext);
                                      _deleteAllData();
                                    },
                            ),
                          ],
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.slideshow, size: 18),
                          label: Text(l.replayIntro),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _showIntro();
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        '${l.lessonCount(App.lessons.count)}\n\n'
                        '${l.dataCredit}',
                        style: muted,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Body ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.appTitle,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
        actions: [
          IconButton(
            tooltip: context.l10n.settingsTooltip,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(context.l10n.loadError('$_error'),
                      textAlign: TextAlign.center))
              : ListenableBuilder(
                  listenable: Listenable.merge([App.downloads, App.updates]),
                  builder: (context, _) {
                    final diffLessons =
                        App.updates.diffsFor(App.downloads);
                    final staleIds = {
                      for (final d in diffLessons)
                        if (!d.isEmpty) d.lesson,
                    };
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          children: [
                            const DownloadBanner(),
                            Expanded(
                              child: CustomScrollView(
                                slivers: [
                                  SliverPadding(
                                    padding:
                                        const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                    sliver: SliverToBoxAdapter(
                                        child: _filters()),
                                  ),
                                  SliverPadding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    sliver: SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, i) {
                                          final l = _lessons[i];
                                          return _LessonTile(
                                              lesson: l,
                                              hasUpdate:
                                                  staleIds.contains(l.id),
                                              onTap: () => unawaited(
                                                  _openLesson(l)));
                                        },
                                        childCount: _lessons.length,
                                      ),
                                    ),
                                  ),
                                  const SliverPadding(
                                      padding: EdgeInsets.only(bottom: 24)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _filters() {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<Subject>(
          showSelectedIcon: false, // no width change on select
          segments: [
            ButtonSegment(
                value: Subject.math,
                label: SizedBox(
                    width: 104,
                    child: Center(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.calculate, size: 15),
                      const SizedBox(width: 5),
                      Text(l.subjectMath),
                    ])))),
            ButtonSegment(
                value: Subject.literature,
                label: SizedBox(
                    width: 104,
                    child: Center(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.menu_book, size: 15),
                      const SizedBox(width: 5),
                      Text(l.subjectLiterature),
                    ])))),
          ],
          selected: {_subject},
          onSelectionChanged: (sel) {
            setState(() {
              _subject = sel.first;
              _applyFilter();
            });
          },
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final g in AppConfig.grades)
                Padding(
                  padding: EdgeInsets.only(
                      right: (g == AppConfig.grades.last ? 0 : 8)),
                  child: ChoiceChip(
                    label: Text(context.l10n.gradeChip(g)),
                    selected: _grade == g,
                    showCheckmark: false,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                    visualDensity: const VisualDensity(
                        horizontal: -2, vertical: -2),
                    labelStyle: TextStyle(
                      fontWeight:
                          _grade == g ? FontWeight.w700 : FontWeight.w500,
                      color: _grade == g
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    ),
                    selectedColor: theme.colorScheme.primary,
                    onSelected: (_) => setState(() {
                      _grade = g;
                      _applyFilter();
                    }),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String _fmtMB(int b) {
  if (b <= 0) return '0 MB';
  final mb = b / 1048576;
  if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
  return '${mb.round()} MB';
}

class _LessonTile extends StatelessWidget {
  final Lesson lesson;
  final VoidCallback onTap;
  final bool hasUpdate;

  const _LessonTile({
    required this.lesson,
    required this.onTap,
    this.hasUpdate = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 92,
                    height: 52,
                    alignment: Alignment.center,
                    child: Image.asset(
                      'data/thumbs/${lesson.id}.webp',
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Text(
                        lesson.id.startsWith('TOAN')
                            ? context.l10n.subjectMathShort
                            : context.l10n.subjectLiteratureShort,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(lesson.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  if (hasUpdate)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Tooltip(
                        message: context.l10n.hasUpdate,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  Icon(Icons.chevron_right, color: theme.colorScheme.outline),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
