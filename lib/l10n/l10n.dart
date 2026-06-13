import 'package:flutter/widgets.dart';

import 'gen/app_localizations.dart';

export 'gen/app_localizations.dart';

/// Ergonomic access to the generated localizations: `context.l10n.someKey`
/// instead of `AppLocalizations.of(context).someKey`. The single sanctioned
/// way screens read user-facing strings.
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
