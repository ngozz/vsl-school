import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../main.dart';
import '../services/settings_service.dart' show AppLanguage;

/// First-launch onboarding: a language step followed by three info pages,
/// shown once (re-openable from the settings sheet). Hand-rolled PageView —
/// no onboarding dependency.
///
/// The language step is first on purpose: picking a language rebuilds the
/// whole route instantly, so the following pages (and the buttons) are already
/// in the chosen language.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;

  static const _pageCount = 4;

  void _finish() {
    App.settings.setIntroSeen();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final last = _page == _pageCount - 1;
    final pages = <Widget>[
      _languageStep(l, theme),
      _introStep(
        theme,
        icon: Icons.school_outlined,
        title: l.introWelcomeTitle,
        body: l.introWelcomeBody,
      ),
      _introStep(
        theme,
        icon: Icons.wifi_off_outlined,
        title: l.introOfflineTitle,
        body: l.introOfflineBody,
      ),
      _introStep(
        theme,
        icon: Icons.volunteer_activism_outlined,
        title: l.introSourceTitle,
        body: l.introSourceBody,
      ),
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(l.onboardingSkip),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: pages,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pageCount; i++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (last) {
                      _finish();
                    } else {
                      _controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut);
                    }
                  },
                  child: Text(last ? l.onboardingStart : l.onboardingNext),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Step 0: pick the interface language. Language names are endonyms (never
  /// translated), so both options are always readable.
  Widget _languageStep(AppLocalizations l, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.translate, size: 88, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            l.languageTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            l.languageSubtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          for (final lang in AppLanguage.values) ...[
            _LanguageOption(
              label: switch (lang) {
                AppLanguage.vi => l.languageVietnamese,
                AppLanguage.en => l.languageEnglish,
              },
              selected: App.settings.language == lang,
              onTap: () async {
                await App.settings.setLanguage(lang);
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _introStep(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 88, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text(title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// One tappable language row. Deliberately plain (no Radio widget) so the
/// selection ring is cheap to draw and identical on every platform.
class _LanguageOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
