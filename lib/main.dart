import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'models/log_entry.dart';
import 'services/server_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:android_intent_plus/android_intent.dart';
import 'screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'services/server_provider.dart';
import 'utils/logger.dart';
import 'screens/log_screen.dart';

const notificationChannelId = 'tappy_server_channel';
const notificationId = 888;

Future<void> main() async {
  setupLogging();
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ServerProvider())],
      child: const MyApp(),
    ),
  );
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          notificationChannelId,
          'Tappy Server',
          description: 'File server running in background',
          importance: Importance.low,
        ),
      );

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: notificationChannelId,
      initialNotificationTitle: 'Tappy Server',
      initialNotificationContent: 'Initializing...',
      foregroundServiceNotificationId: notificationId,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopSelf').listen((event) {
    service.stopSelf();
  });

  final server = LocalServer(service: service);

  service.on('setSharableFile').listen((event) {
    if (event != null) {
      final path = event['path'] as String?;
      server.setSharableFiles(path != null ? [path] : []);
      service.invoke('sharedFilesUpdate', {
        'fileNames': path != null ? [p.basename(path)] : [],
      });
    }
  });

  service.on('setSharableFiles').listen((event) {
    if (event != null && event['paths'] is List) {
      final paths = List<String>.from(event['paths']);
      server.setSharableFiles(paths);
      final names = paths.map(p.basename).toList();
      service.invoke('sharedFilesUpdate', {'fileNames': names});
    }
  });

  service.on('clearSharedFiles').listen((event) {
    server.clearSharedFiles();
    service.invoke('sharedFilesUpdate', {'fileNames': []});
  });

  await server.start();

  if (service is AndroidServiceInstance) {
    if (await service.isForegroundService()) {
      flutterLocalNotificationsPlugin.show(
        notificationId,
        'Tappy Server is Running',
        'Tap to open app',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            notificationChannelId,
            'Tappy Server',
            icon: 'ic_bg_service_small',
            ongoing: true,
          ),
        ),
      );
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tappy File Server',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

Future<void> scanFile(String filePath) async {
  if (Platform.isAndroid) {
    final intent = AndroidIntent(
      action: 'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
      data: Uri.file(filePath).toString(),
    );
    await intent.sendBroadcast();
  }
}

class _HomePageState extends State<HomePage> {
  String? _serverUrl;
  bool _isRunning = false;
  List<String> _sharedFileNames = [];
  bool _isLoading = false;
  Map<String, double> _uploadProgress = {}; // fileName -> percent (0.0-1.0)
  // List of files received from PC in this session
  final List<String> _receivedFiles = [];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _ambiguate(
      WidgetsBinding.instance,
    )?.addPostFrameCallback((_) => _setupListener());
  }

  Future<void> _setupListener() async {
    final service = FlutterBackgroundService();

    // Listen for accessRequest events from the background service
    service.on('accessRequest').listen((event) async {
      print('[Tappy] accessRequest event received in HomePage');
      final provider = Provider.of<ServerProvider>(context, listen: false);
      final approved = await provider.showAccessRequestDialog();
      print('[Tappy] User approval result: $approved');
      service.invoke('accessRequestResponse', {'approved': approved});
    });

    // Listen for log events
    service.on('log').listen((event) {
      if (event != null && mounted) {
        final message = event['message'] as String?;
        final typeIndex = event['type'] as int?;
        if (message != null) {
          final provider = Provider.of<ServerProvider>(context, listen: false);
          provider.logs.add(
            LogEntry(message: message, type: LogType.values[typeIndex ?? 0]),
          );
          provider.notifyListeners();
          // Show snackbar if it's an upload event
          if (typeIndex != null &&
              LogType.values[typeIndex] == LogType.upload) {
            _showSnackbar('File received!', color: Colors.green);
            // Remove progress bar for this file
            final fileName = _uploadProgress.keys.isNotEmpty
                ? _uploadProgress.keys.first
                : null;
            if (fileName != null) {
              setState(() => _uploadProgress.remove(fileName));
              // Add to received files list
              setState(() => _receivedFiles.add(fileName));
            }
          }
        }
      }
    });

    // Listen for upload progress events
    service.on('uploadProgress').listen((event) {
      if (event != null && mounted) {
        final fileName = event['fileName'] as String?;
        final received = event['received'] as int?;
        final total = event['total'] as int?;
        if (fileName != null &&
            received != null &&
            total != null &&
            total > 0) {
          setState(() {
            _uploadProgress[fileName] = received / total;
          });
        } else if (fileName != null &&
            received != null &&
            (total == null || total == 0)) {
          // If total is not available, just show indeterminate
          setState(() {
            _uploadProgress[fileName] = -1.0;
          });
        }
      }
    });

    // Listen for upload request events (require user acceptance)
    service.on('uploadRequest').listen((event) async {
      if (event != null && mounted) {
        // Multi-file support
        final files = event['files'] as List?;
        if (files != null && files.isNotEmpty) {
          final fileList = files
              .map((f) => Map<String, dynamic>.from(f))
              .toList();
          final accept = await _showUploadAcceptDialogBatch(fileList);
          service.invoke('uploadResponse', {'files': files, 'accept': accept});
        } else {
          // Fallback to single file
          final fileName = event['fileName'] as String?;
          final fileSize = event['fileSize'] as int?;
          if (fileName != null) {
            final accept = await _showUploadAcceptDialog(fileName, fileSize);
            service.invoke('uploadResponse', {
              'fileName': fileName,
              'accept': accept,
            });
          }
        }
      }
    });

    // Listen for shared file updates
    service.on('sharedFilesUpdate').listen((event) {
      if (event != null && event['fileNames'] is List && mounted) {
        setState(() {
          _sharedFileNames = List<String>.from(event['fileNames']);
        });
      }
    });

    // Check initial state
    final isRunning = await service.isRunning();
    if (mounted) setState(() => _isRunning = isRunning);
    if (isRunning) _updateServerUrl();
  }

  Future<bool> _showUploadAcceptDialog(String fileName, int? fileSize) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Incoming File'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File: $fileName'),
                if (fileSize != null && fileSize > 0)
                  Text(
                    'Size: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB',
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Reject'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Accept'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showUploadAcceptDialogBatch(
    List<Map<String, dynamic>> files,
  ) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Incoming Files'),
            content: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...files.map(
                    (f) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(
                        '${f['fileName']}' +
                            (f['fileSize'] != null && f['fileSize'] > 0
                                ? ' (${(f['fileSize'] / (1024 * 1024)).toStringAsFixed(2)} MB)'
                                : ''),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Reject All'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Accept All'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _startServer() async {
    setState(() => _isLoading = true);
    try {
      final service = FlutterBackgroundService();
      var isRunning = await service.isRunning();
      if (isRunning) {
        service.invoke('stopSelf');
      } else {
        await service.startService();
      }

      if (mounted) {
        setState(() => _isRunning = !isRunning);
        if (!isRunning)
          _updateServerUrl();
        else
          _serverUrl = null;
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, {Color? color}) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _selectAndShareFiles() async {
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result != null) {
        final paths = result.paths.whereType<String>().toList();
        if (paths.isNotEmpty) {
          final service = FlutterBackgroundService();
          service.invoke('setSharableFiles', {'paths': paths});
          _showSnackbar('Files shared!', color: Colors.green);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearSharedFiles() {
    final service = FlutterBackgroundService();
    service.invoke('clearSharedFiles');
    _showSnackbar('Stopped sharing all files.', color: Colors.blue);
  }

  Future<void> _updateServerUrl() async {
    final ip = await _getLocalIp();
    if (mounted) {
      setState(() => _serverUrl = 'http://$ip:7625');
    }
  }

  Future<String> _getLocalIp() async {
    for (var interface in await NetworkInterface.list()) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          return addr.address;
        }
      }
    }
    return 'localhost';
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.request();
      if (status.isDenied && mounted) {
        final provider = Provider.of<ServerProvider>(context, listen: false);
        provider.logs.add(
          LogEntry(message: 'Storage permission denied.', type: LogType.error),
        );
        provider.notifyListeners();
        _showSnackbar('Storage permission denied.', color: Colors.redAccent);
      }
    }

    if (await Permission.notification.isDenied) {
      // ... existing code ...
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      final provider = Provider.of<ServerProvider>(
                        context,
                        listen: false,
                      );
                      provider.logs.clear();
                      provider.notifyListeners();
                      Navigator.of(context).pop();
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
              _buildServerHubCard(theme),
              const SizedBox(height: 16),
              _buildFileSharingCard(),
              const SizedBox(height: 16),
              if (_uploadProgress.isNotEmpty)
                ..._uploadProgress.entries.map(
                  (entry) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Receiving: ${entry.key}'),
                      entry.value >= 0
                          ? LinearProgressIndicator(value: entry.value)
                          : const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              if (_receivedFiles.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Files received this session:',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                ..._receivedFiles.map(
                  (f) => ListTile(
                    leading: const Icon(Icons.file_download),
                    title: Text(f, overflow: TextOverflow.ellipsis),
                    dense: true,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Card _buildServerHubCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: _isRunning
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _isRunning ? Icons.cloud_done : Icons.cloud_off,
                  size: 32,
                  color: _isRunning
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isRunning ? 'Server is Running' : 'Server is Offline',
                        style: theme.textTheme.titleLarge,
                      ),
                      if (_isRunning && _serverUrl != null)
                        GestureDetector(
                          onTap: () => _showQrDialog(_serverUrl!),
                          child: Text(
                            _serverUrl!,
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _startServer,
                      icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
                      label: Text(_isRunning ? 'Stop Server' : 'Start Server'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSharingCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('File Sharing', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _isRunning ? _selectAndShareFiles : null,
                    icon: const Icon(Icons.share),
                    label: const Text('Share Files'),
                  ),
            const SizedBox(height: 16),
            if (_sharedFileNames.isNotEmpty) ...[
              Text(
                'Sharing ${_sharedFileNames.length} file(s):',
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
                  itemCount: _sharedFileNames.length,
                  itemBuilder: (context, index) {
                    final fileName = _sharedFileNames[index];
                    return ListTile(
                      leading: const Icon(Icons.insert_drive_file),
                      title: Text(fileName, overflow: TextOverflow.ellipsis),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _clearSharedFiles,
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

  void _showQrDialog(String url) {
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

  T? _ambiguate<T>(T? value) => value;
}
