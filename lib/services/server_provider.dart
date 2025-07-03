import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../models/log_entry.dart';
import '../utils/logger.dart';

class ServerProvider extends ChangeNotifier {
  String? serverUrl;
  final List<LogEntry> logs = [];
  bool isRunning = false;
  List<String> sharedFileNames = [];
  bool isLoading = false;
  Map<String, double> uploadProgress = {}; // fileName -> percent (0.0-1.0)
  final List<String> receivedFiles = [];

  BuildContext? context;

  void setContext(BuildContext ctx) {
    context = ctx;
  }

  Future<void> setupListener() async {
    final service = FlutterBackgroundService();

    service.on('log').listen((event) {
      if (event != null && context != null) {
        final message = event['message'] as String?;
        final typeIndex = event['type'] as int?;
        if (message != null) {
          logs.add(
            LogEntry(message: message, type: LogType.values[typeIndex ?? 0]),
          );
          notifyListeners();
          if (typeIndex != null &&
              LogType.values[typeIndex] == LogType.upload) {
            _showSnackbar('File received!', color: Colors.green);
            final fileName = uploadProgress.keys.isNotEmpty
                ? uploadProgress.keys.first
                : null;
            if (fileName != null) {
              uploadProgress.remove(fileName);
              receivedFiles.add(fileName);
              notifyListeners();
            }
          }
        }
      }
    });

    service.on('uploadProgress').listen((event) {
      if (event != null) {
        final fileName = event['fileName'] as String?;
        final received = event['received'] as int?;
        final total = event['total'] as int?;
        if (fileName != null &&
            received != null &&
            total != null &&
            total > 0) {
          uploadProgress[fileName] = received / total;
        } else if (fileName != null &&
            received != null &&
            (total == null || total == 0)) {
          uploadProgress[fileName] = -1.0;
        }
        notifyListeners();
      }
    });

    service.on('uploadRequest').listen((event) async {
      if (event != null && context != null) {
        final files = event['files'] as List?;
        if (files != null && files.isNotEmpty) {
          final fileList = files
              .map((f) => Map<String, dynamic>.from(f))
              .toList();
          final accept = await showUploadAcceptDialogBatch(context!, fileList);
          service.invoke('uploadResponse', {'files': files, 'accept': accept});
        } else {
          final fileName = event['fileName'] as String?;
          final fileSize = event['fileSize'] as int?;
          if (fileName != null) {
            final accept = await showUploadAcceptDialog(
              context!,
              fileName,
              fileSize,
            );
            service.invoke('uploadResponse', {
              'fileName': fileName,
              'accept': accept,
            });
          }
        }
      }
    });

    service.on('sharedFilesUpdate').listen((event) {
      if (event != null && event['fileNames'] is List) {
        sharedFileNames = List<String>.from(event['fileNames']);
        notifyListeners();
      }
    });

    final running = await service.isRunning();
    isRunning = running;
    notifyListeners();
    if (running) updateServerUrl();
  }

  Future<void> startServer() async {
    isLoading = true;
    notifyListeners();
    try {
      final service = FlutterBackgroundService();
      var running = await service.isRunning();
      if (running) {
        service.invoke('stopSelf');
      } else {
        try {
          await service.startService();
        } catch (e) {
          _showSnackbar(
            'Failed to start server: ${e.toString()}',
            color: Colors.redAccent,
          );
          logs.add(
            LogEntry(
              message: 'Failed to start server: $e',
              type: LogType.error,
            ),
          );
        }
      }
      isRunning = !running;
      notifyListeners();
      if (!running) {
        updateServerUrl();
      } else {
        serverUrl = null;
      }
    } catch (e) {
      _showSnackbar(
        'Unexpected error: ${e.toString()}',
        color: Colors.redAccent,
      );
      logs.add(LogEntry(message: 'Unexpected error: $e', type: LogType.error));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectAndShareFiles() async {
    isLoading = true;
    notifyListeners();
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
    } catch (e) {
      _showSnackbar(
        'Failed to pick/share files: ${e.toString()}',
        color: Colors.redAccent,
      );
      logs.add(
        LogEntry(
          message: 'Failed to pick/share files: $e',
          type: LogType.error,
        ),
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void clearSharedFiles() {
    final service = FlutterBackgroundService();
    service.invoke('clearSharedFiles');
    _showSnackbar('Stopped sharing all files.', color: Colors.blue);
  }

  Future<void> updateServerUrl() async {
    final ip = await _getLocalIp();
    serverUrl = 'http://$ip:7625';
    notifyListeners();
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

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.request();
      if (status.isDenied && context != null) {
        logs.add(
          LogEntry(message: 'Storage permission denied.', type: LogType.error),
        );
        _showSnackbar('Storage permission denied.', color: Colors.redAccent);
        notifyListeners();
      }
    }
    if (await Permission.notification.isDenied) {
      // ... handle notification permission ...
    }
  }

  void _showSnackbar(String message, {Color? color}) {
    if (context == null) return;
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    );
    ScaffoldMessenger.of(context!).showSnackBar(snackBar);
  }

  Future<bool> showAccessRequestDialog() async {
    print(
      '[Tappy] showAccessRequestDialog called. context: '
      '[33m[1m[4m$context[0m',
    );
    if (context == null) return false;
    return await showDialog<bool>(
          context: context!,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Access Request'),
            content: const Text(
              'A device is requesting access to upload/download files. Allow access?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Deny'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Allow'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

// Import these from widgets/upload_accept_dialog.dart
Future<bool> showUploadAcceptDialog(
  BuildContext context,
  String fileName,
  int? fileSize,
) async => throw UnimplementedError();
Future<bool> showUploadAcceptDialogBatch(
  BuildContext context,
  List<Map<String, dynamic>> files,
) async => throw UnimplementedError();
