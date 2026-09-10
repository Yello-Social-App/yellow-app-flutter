// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get securityBlockedTitle => 'This device failed a security check';

  @override
  String get securityBlockedBody =>
      'yello can\'t run on a rooted or jailbroken device — this protects your account and messages.';
}
