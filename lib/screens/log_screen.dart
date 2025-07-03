import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/log_entry.dart';
import '../services/server_provider.dart';
import '../utils/logger.dart';

class LogScreen extends StatelessWidget {
  final VoidCallback onClear;
  const LogScreen({Key? key, required this.onClear}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: onClear,
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: Consumer<ServerProvider>(
        builder: (context, provider, child) {
          final logs = provider.logs;
          return logs.isEmpty
              ? const Center(child: Text('No logs yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  reverse: true,
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[logs.length - 1 - index];
                    IconData iconData;
                    Color iconColor;
                    switch (log.type) {
                      case LogType.upload:
                        iconData = Icons.file_upload;
                        iconColor = Colors.green;
                        break;
                      case LogType.download:
                        iconData = Icons.file_download;
                        iconColor = Colors.blue;
                        break;
                      case LogType.error:
                        iconData = Icons.error_outline;
                        iconColor = theme.colorScheme.error;
                        break;
                      case LogType.info:
                      default:
                        iconData = Icons.info_outline;
                        iconColor = theme.colorScheme.onSurfaceVariant;
                        break;
                    }
                    return ListTile(
                      leading: Icon(iconData, color: iconColor),
                      title: Text(
                        log.message,
                        style: theme.textTheme.bodySmall,
                      ),
                      dense: true,
                    );
                  },
                );
        },
      ),
    );
  }
}
