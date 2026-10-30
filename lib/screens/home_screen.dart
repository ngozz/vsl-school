import 'package:flutter/material.dart';

import '../main.dart';
import '../models/lesson.dart';
import '../services/settings_service.dart' show ThemeChoice;
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
      setState(() => _ready = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _ready = true;
        });
      }
    }
  }

  void _applyFilter() {
    _lessons = App.lessons.byFilter(_subject, _grade);
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return AnimatedBuilder(
          animation: App.settings,
          builder: (sheetContext, _) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CÃ i Ä‘áº·t', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Text('Giao diá»‡n', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeChoice>(
                    segments: const [
                      ButtonSegment(value: ThemeChoice.dark, label: Text('Tá»‘i')),
                      ButtonSegment(
                          value: ThemeChoice.black, label: Text('Äen')),
                      ButtonSegment(
                          value: ThemeChoice.light, label: Text('SÃ¡ng')),
                    ],
                    selected: {App.settings.theme},
                    onSelectionChanged: (sel) =>
                        App.settings.setTheme(sel.first),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Ghi nhá»› tá»‘c Ä‘á»™ phÃ¡t'),
                    subtitle: Text(
                      'Ãp dá»¥ng tá»‘c Ä‘á»™ Ä‘Ã£ chá»n cho video káº¿ tiáº¿p',
                      style: theme.textTheme.bodySmall,
                    ),
                    value: App.settings.rememberSpeed,
                    onChanged: (v) => App.settings.setRememberSpeed(v),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sá»‘ bÃ i há»c: ${App.lessons.count}\n\n'
                    'Ná»™i dung bÃ i há»c tá»« â€œApp Khiem Thinhâ€ (qipedc.moet.gov.vn) '
                    'â€” dÃ¹ng lÃ m cÃ¡ nhÃ¢n.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

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
            tooltip: 'CÃ i Ä‘áº·t',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text('Lá»—i táº£i dá»¯ liá»‡u:\n$_error',
                      textAlign: TextAlign.center))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          sliver: SliverToBoxAdapter(child: _filters()),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final l = _lessons[i];
                                return _LessonTile(
                                    lesson: l,
                                    onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (ctx) =>
                                                LessonScreen(lesson: l))));
                              },
                              childCount: _lessons.length,
                            ),
                          ),
                        ),
                        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _filters() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<Subject>(
          segments: const [
            ButtonSegment(
                value: Subject.math, label: Text('ToÃ¡n'), icon: Icon(Icons.calculate)),
            ButtonSegment(
                value: Subject.literature,
                label: Text('Tiáº¿ng Viá»‡t'),
                icon: Icon(Icons.menu_book)),
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
                  padding: EdgeInsets.only(right: (g == AppConfig.grades.last ? 0 : 8)),
                  child: ChoiceChip(
                    label: Text('Lá»›p $g'),
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

class _LessonTile extends StatelessWidget {
  final Lesson lesson;
  final VoidCallback onTap;

  const _LessonTile({required this.lesson, required this.onTap});

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
                        lesson.id.startsWith('TOAN') ? 'Sá»‘' : 'TV',
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
