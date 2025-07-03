import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:qr_flutter/qr_flutter.dart';
import '../models/log_entry.dart';
import '../services/server_service.dart';
import 'log_screen.dart';
import '../widgets/file_progress_bar.dart';
import '../widgets/received_file_list.dart';
import '../widgets/upload_accept_dialog.dart';
import 'package:provider/provider.dart';
import '../services/server_provider.dart';
import '../utils/logger.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ServerProvider>(context, listen: false);
    provider.setContext(context);
    provider.requestPermissions();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => provider.setupListener(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Provider.of<ServerProvider>(context, listen: false).setContext(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ServerProvider>(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tappy File Server'),
        backgroundColor: theme.colorScheme.surfaceContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'View Logs',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => LogScreen(
                    onClear: () {
                      provider.logs.clear();
                      Navigator.of(context).pop();
                      provider.notifyListeners();
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildServerHubCard(theme, provider),
              const SizedBox(height: 16),
              _buildFileSharingCard(provider),
              const SizedBox(height: 16),
              ...provider.uploadProgress.entries.map(
                (entry) =>
                    FileProgressBar(fileName: entry.key, progress: entry.value),
              ),
              ReceivedFileList(files: provider.receivedFiles),
            ],
          ),
        ),
      ),
    );
  }

  Card _buildServerHubCard(ThemeData theme, ServerProvider provider) {
    return Card(
      elevation: 0,
      color: provider.isRunning
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  provider.isRunning ? Icons.cloud_done : Icons.cloud_off,
                  size: 32,
                  color: provider.isRunning
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.isRunning
                            ? 'Server is Running'
                            : 'Server is Offline',
                        style: theme.textTheme.titleLarge,
                      ),
                      if (provider.isRunning && provider.serverUrl != null)
                        GestureDetector(
                          onTap: () =>
                              _showQrDialog(context, provider.serverUrl!),
                          child: Text(
                            provider.serverUrl!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              decoration: TextDecoration.underline,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        )
                      else
                        Text(
                          'Tap the button to start the server',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: provider.startServer,
                      icon: Icon(
                        provider.isRunning ? Icons.stop : Icons.play_arrow,
                      ),
                      label: Text(
                        provider.isRunning ? 'Stop Server' : 'Start Server',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSharingCard(ServerProvider provider) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('File Sharing', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: provider.isRunning
                        ? provider.selectAndShareFiles
                        : null,
                    icon: const Icon(Icons.share),
                    label: const Text('Share Files'),
                  ),
            const SizedBox(height: 16),
            if (provider.sharedFileNames.isNotEmpty) ...[
              Text(
                'Sharing ${provider.sharedFileNames.length} file(s):',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Container(
                height: 120, // Constrain height
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: provider.sharedFileNames.length,
                  itemBuilder: (context, index) {
                    final fileName = provider.sharedFileNames[index];
                    return ListTile(
                      leading: const Icon(Icons.insert_drive_file),
                      title: Text(fileName, overflow: TextOverflow.ellipsis),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: provider.clearSharedFiles,
                icon: const Icon(Icons.clear_all),
                label: const Text('Stop Sharing All'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                ),
              ),
            ] else
              const Center(child: Text('No files are currently being shared.')),
          ],
        ),
      ),
    );
  }

  void _showQrDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan QR Code'),
        content: SizedBox(
          width: 250,
          height: 250,
          child: Center(
            child: QrImageView(
              data: url,
              version: QrVersions.auto,
              size: 200.0,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
