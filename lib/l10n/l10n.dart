import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// `context.l10n.someKey` — one import for both the generated strings and the
/// lookup extension.
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
