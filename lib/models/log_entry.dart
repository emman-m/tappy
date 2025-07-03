enum LogType { info, upload, download, error }

class LogEntry {
  final String message;
  final LogType type;
  final DateTime timestamp;

  LogEntry({
    required this.message,
    this.type = LogType.info,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'type': type.index,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  static LogEntry fromMap(Map<String, dynamic> map) {
    return LogEntry(
      message: map['message'] ?? '',
      type: LogType.values[map['type'] ?? 0],
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}
