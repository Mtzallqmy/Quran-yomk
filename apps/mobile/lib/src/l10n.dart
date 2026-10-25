import 'package:flutter/widgets.dart';
import 'package:tarteel/l10n/app_localizations.dart';

export 'package:tarteel/l10n/app_localizations.dart';

extension TarteelLocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Compatibility facade for older call sites while the application migrates
/// completely to Flutter's generated AppLocalizations.
class TarteelStrings {
  const TarteelStrings._(this._delegate);
  final AppLocalizations _delegate;

  static TarteelStrings of(BuildContext context) =>
      TarteelStrings._(AppLocalizations.of(context));

  String get appName => _delegate.appName;
  String get home => _delegate.home;
  String get radio => _delegate.radio;
  String get reciters => _delegate.reciters;
  String get library => _delegate.library;
  String get favorites => _delegate.favorites;
  String get settings => _delegate.settings;
  String get search => _delegate.search;
  String get live => _delegate.live;
  String get retry => _delegate.retry;
  String get noData => _delegate.noData;
  String get offline => _delegate.offlineMessage;
  String get about => _delegate.about;
  String get privacy => _delegate.privacyPolicy;
  String get terms => _delegate.terms;
  String get support => _delegate.support;
}
