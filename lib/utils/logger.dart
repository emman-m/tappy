import 'package:logging/logging.dart';

final Logger logger = Logger('Tappy');

void setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // You can customize this format or write to a file if needed
    // ignore: avoid_print
    print(
      '[${record.level.name}] ${record.time}: ${record.loggerName}: ${record.message}',
    );
  });
}
