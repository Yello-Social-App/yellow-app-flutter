import 'package:logger/logger.dart';

import '../config/app_config.dart';

/// Single shared logger. Filters itself down to warnings+ in release builds
/// (see [AppConfig.isProd]), so debug/verbose logging never ships to users
/// by accident.
final Logger appLogger = Logger(
  filter: _ReleaseAwareFilter(),
  printer: PrettyPrinter(
    methodCount: 1,
    errorMethodCount: 8,
    lineLength: 100,
    colors: true,
    printEmojis: true,
  ),
);

class _ReleaseAwareFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (!AppConfig.isProd) return true;
    return event.level.index >= Level.warning.index;
  }
}
