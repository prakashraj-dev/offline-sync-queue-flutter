import 'package:logger/logger.dart';

/// Centralised structured logger with emoji-prefixed categories.
///
/// Usage:
///   AppLogger.info('[QUEUE] Added action=addNote id=UUID, queue size=3');
///   AppLogger.error('[SYNC] ✗ Failed after retry for ID=UUID — marked failed');
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 100,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: Level.trace,
  );

  static void info(String message) => _logger.i(message);
  static void debug(String message) => _logger.d(message);
  static void warning(String message) => _logger.w(message);
  static void error(String message, [Object? error, StackTrace? stack]) =>
      _logger.e(message, error: error, stackTrace: stack);
  static void trace(String message) => _logger.t(message);
}
