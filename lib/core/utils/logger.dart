import 'package:logger/logger.dart';
import 'package:nexa/core/config/app_config.dart';

/// Application logger configuration
class AppLogger {
  AppLogger._();

  static Logger? _instance;

  /// Gets the singleton logger instance
  static Logger get instance {
    _instance ??= _createLogger();
    return _instance!;
  }

  /// Creates a configured logger instance
  static Logger _createLogger() {
    final config = AppConfig.instance;

    return Logger(
      filter: _LogFilter(config),
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      level: _getLogLevel(config),
    );
  }

  /// Gets the appropriate log level based on environment
  static Level _getLogLevel(AppConfig config) {
    if (config.isDevelopment) {
      return Level.debug;
    } else if (config.isStaging) {
      return Level.info;
    } else {
      return Level.warning;
    }
  }

  /// Creates a simple logger for production
  static Logger createProductionLogger() {
    return Logger(
      printer: SimplePrinter(
        printTime: true,
      ),
      output: ConsoleOutput(),
      level: Level.warning,
    );
  }

  /// Creates a logger that writes to a file
  static Logger createFileLogger(String filePath) {
    return Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
      ),
      output: FileOutput(file: filePath),
      level: Level.debug,
    );
  }
}

/// Custom log filter based on environment
class _LogFilter extends LogFilter {
  _LogFilter(this.config);

  final AppConfig config;

  @override
  bool shouldLog(LogEvent event) {
    // In production, only log warnings and errors
    if (config.isProduction) {
      return event.level.index >= Level.warning.index;
    }

    // In staging, log info and above
    if (config.isStaging) {
      return event.level.index >= Level.info.index;
    }

    // In development, log everything
    return true;
  }
}

/// Custom file output for logger
class FileOutput extends LogOutput {
  /// Creates a [FileOutput] with a file path
  FileOutput({required this.file});

  final String file;

  @override
  void output(OutputEvent event) {
    // In a real implementation, you would write to a file here
    // For now, we'll just use console output
    event.lines.forEach(
      // ignore: avoid_print
      print,
    );
  }
}
