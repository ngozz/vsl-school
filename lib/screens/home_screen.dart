import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/lesson.dart';
import '../services/settings_service.dart';
import '../widgets/download_dialogs.dart';
import '../config.dart' show AppConfig;
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
      await App.lessons.load();
      if (!mounted) return;
      _applyFilter();
      await App.downloads.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
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

  /// Auto-*check* at startup (cheap manifest fetch); applying is manual.
  Future<void> _startupUpdateCheck() async {
    await App.updates.check();
    final diffs = [
      for (final d in App.updates.diffsFor(App.downloads))
        if (!d.isEmpty) d,
    ];
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
      _snack('Toàn bộ nội dung đã được tải về máy.');
      return;
    }
    if (!await DownloadDialogs.confirmBatch(context, remaining.length, bytes)) {
      return;
    }
    if (!mounted) return;
    final wifi = await dl.onWifi();
    if (!mounted) return;
    if (!wifi && !(await DownloadDialogs.confirmMobileData(context, bytes))) {
      _snack('Sẽ tải khi có Wi-Fi (mở lại màn hình này).');
      return;
    }
    if (!mounted) return;
    final started = dl.enqueueAll(remaining);
    _snack('Đã bắt đầu tải $started video…');
  }

  Future<void> _manualUpdateCheck() async {
    await App.updates.check();
    if (App.updates.lastError != null) {
      _snack('Không thể kiểm tra: ${App.updates.lastError}');
      return;
    }
    final diffs = [
      for (final d in App.updates.diffsFor(App.downloads))
        if (!d.isEmpty) d,
    ];
    if (!mounted) return;
    if (diffs.isEmpty) {
      _snack('Nội dung đã là bản mới nhất.');
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
                      Text('Cài đặt', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 16),
                      Text('Giao diện', style: optionTitle),
                      const SizedBox(height: 8),
                      SegmentedButton<ThemeChoice>(
                        showSelectedIcon: false, // no width change on select
                        segments: const [
                          ButtonSegment(
                              value: ThemeChoice.dark,
                              label: SizedBox(
                                  width: 52,
                                  child: Center(child: Text('Tối')))),
                          ButtonSegment(
                              value: ThemeChoice.black,
                              label: SizedBox(
                                  width: 52,
                                  child: Center(child: Text('Đen')))),
                          ButtonSegment(
                              value: ThemeChoice.light,
                              label: SizedBox(
                                  width: 52,
                                  child: Center(child: Text('Sáng')))),
                        ],
                        selected: {App.settings.theme},
                        onSelectionChanged: (sel) =>
                            App.settings.setTheme(sel.first),
                      ),
                      const SizedBox(height: 4),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text('Ghi nhớ tốc độ phát', style: optionTitle),
                        subtitle: Text(
                          'Áp dụng tốc độ đã chọn cho video kế tiếp',
                          style: muted,
                        ),
                        value: App.settings.rememberSpeed,
                        onChanged: (v) => App.settings.setRememberSpeed(v),
                      ),
                      if (dl.active) ...[
                        const SizedBox(height: 12),
                        Text('Tải xuống & cập nhật', style: optionTitle),
                        const SizedBox(height: 8),
                        Text(
                          'Đã tải: ${dl.downloadedLessonCount}/${dl.catalogLessonCount} bài '
                          '(${dl.downloadedCount} video, ${_fmtMB(dl.downloadedBytes)})',
                          style: muted,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text('Kiểm tra cập nhật khi mở ứng dụng',
                              style: optionTitle),
                          subtitle: Text(
                            'Tắt = app hoàn toàn ngoại tuyến sau khi đã tải',
                            style: muted,
                          ),
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
                              label: const Text('Tải toàn bộ nội dung'),
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
                              label: const Text('Kiểm tra cập nhật'),
                              onPressed: App.updates.checking
                                  ? null
                                  : () {
                                      Navigator.pop(sheetContext);
                                      _manualUpdateCheck();
                                    },
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Số bài học: ${App.lessons.count}\n\n'
                        'Nội dung bài học từ “App Khiem Thinh” (qipedc.moet.gov.vn)',
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('VSL School',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22)),
        actions: [
          IconButton(
            tooltip: 'Cài đặt',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text('Lỗi tải dữ liệu:\n$_error',
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
                        child: CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              sliver: SliverToBoxAdapter(child: _filters()),
                            ),
                            SliverPadding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) {
                                    final l = _lessons[i];
                                    return _LessonTile(
                                        lesson: l,
                                        hasUpdate: staleIds.contains(l.id),
                                        onTap: () =>
                                            Navigator.of(context).push(
                                                MaterialPageRoute(
                                                    builder: (ctx) =>
                                                        LessonScreen(
                                                            lesson: l))));
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
                    );
                  },
                ),
    );
  }

  Widget _filters() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<Subject>(
          showSelectedIcon: false, // no width change on select
          segments: const [
            ButtonSegment(
                value: Subject.math,
                label: SizedBox(
                    width: 104,
                    child: Center(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.calculate, size: 15),
                      SizedBox(width: 5),
                      Text('Toán'),
                    ])))),
            ButtonSegment(
                value: Subject.literature,
                label: SizedBox(
                    width: 104,
                    child: Center(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.menu_book, size: 15),
                      SizedBox(width: 5),
                      Text('Tiếng Việt'),
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
                    label: Text('Lớp $g'),
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
                        lesson.id.startsWith('TOAN') ? 'Số' : 'TV',
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
                        message: 'Có bản cập nhật',
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
