import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import '../models/log_entry.dart';
import '../main.dart' show scanFile;
import '../utils/logger.dart';

class LocalServer {
  HttpServer? _server;
  final int port;
  final ServiceInstance? service;
  List<String> _sharableFilePaths = [];

  // Security settings
  static const allowedExtensions = [
    '.txt',
    '.jpg',
    '.jpeg',
    '.png',
    '.pdf',
    '.zip',
    '.doc',
    '.docx',
    '.xls',
    '.xlsx',
    '.ppt',
    '.pptx',
    '.mp3',
    '.mp4',
    '.csv',
    '.json',
    '.xml',
    '.gif',
    '.bmp',
    '.webp',
    '.apk',
    '.exe',
    '.tar',
    '.gz',
    '.7z',
    '.rar',
  ];
  static const maxFileSize = 2 * 1024 * 1024 * 1024; // 2 GB

  // Auth token management
  final Map<String, DateTime> _activeTokens = {};
  static const tokenDuration = Duration(minutes: 30);
  String _generateToken() {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  void _cleanupExpiredTokens() {
    final now = DateTime.now();
    _activeTokens.removeWhere((token, expiry) => expiry.isBefore(now));
  }

  bool _isTokenValid(String? token) {
    _cleanupExpiredTokens();
    if (token == null) return false;
    final expiry = _activeTokens[token];
    return expiry != null && expiry.isAfter(DateTime.now());
  }

  LocalServer({this.port = 7625, this.service});

  void onLog(String message, [LogType type = LogType.info]) {
    switch (type) {
      case LogType.error:
        logger.severe(message);
        break;
      case LogType.upload:
      case LogType.download:
        logger.info(message);
        break;
      case LogType.info:
      default:
        logger.fine(message);
        break;
    }
    service?.invoke('log', {'message': message, 'type': type.index});
  }

  void setSharableFiles(List<String> paths) {
    _sharableFilePaths = paths;
    if (paths.isNotEmpty) {
      final fileNames = paths.map((p) => p.split('/').last).join(', ');
      onLog('Now sharing: $fileNames', LogType.download);
    } else {
      onLog('Sharing stopped.');
    }
  }

  void clearSharedFiles() {
    _sharableFilePaths = [];
    onLog('Sharing stopped.');
  }

  Future<String> _prepareWebDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final webDir = Directory(p.join(tempDir.path, 'web'));

    if (await webDir.exists()) {
      await webDir.delete(recursive: true);
    }
    await webDir.create();

    // Extract upload.html
    final uploadData = await rootBundle.load('assets/web/upload.html');
    final uploadFile = File(p.join(webDir.path, 'upload.html'));
    await uploadFile.writeAsBytes(uploadData.buffer.asUint8List());

    // Extract request_access.html
    final accessData = await rootBundle.load('assets/web/request_access.html');
    final accessFile = File(p.join(webDir.path, 'request_access.html'));
    await accessFile.writeAsBytes(accessData.buffer.asUint8List());

    onLog('Web assets extracted to: ${webDir.path}');
    return webDir.path;
  }

  Future<void> start() async {
    try {
      final webAssetsPath = await _prepareWebDirectory();

      final staticHandler = createStaticHandler(
        webAssetsPath,
        defaultDocument: 'upload.html',
      );

      final cascade = Cascade()
          .add(staticHandler)
          .add(_requestAccessHandler)
          .add(_uploadHandler)
          .add(_downloadHandler)
          .add(_apiHandler);

      _server = await shelf_io.serve(
        logRequests(
          logger: (msg, isError) {
            onLog(msg, isError ? LogType.error : LogType.info);
          },
        ).addHandler(cascade.handler),
        InternetAddress.anyIPv4,
        port,
      );
      onLog('Server running on port $port');
    } catch (e, s) {
      onLog('Error during server startup: $e\n$s', LogType.error);
      rethrow;
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Handler get _requestAccessHandler => (Request request) async {
    if (request.method == 'POST' && request.url.path == 'request-access') {
      // Optionally, parse client info
      final body = await request.readAsString();
      // You could parse and log client info here if desired
      // Show dialog to user for approval
      final approved = await _showAccessRequestDialog();
      if (!approved) {
        return Response.forbidden('Access denied by user.');
      }
      final token = _generateToken();
      _activeTokens[token] = DateTime.now().add(tokenDuration);
      return Response.ok(
        '{"token": "$token"}',
        headers: {'Content-Type': 'application/json'},
      );
    }
    return Response.notFound('Not Found');
  };

  Future<bool> _showAccessRequestDialog() async {
    return true;
    if (service == null) return true;
    print('[Tappy] Server: Waiting for accessRequestResponse from UI...');
    final completer = Completer<bool>();
    StreamSubscription? sub;
    sub = service?.on('accessRequestResponse').listen((event) {
      print('[Tappy] Server: Received accessRequestResponse: $event');
      if (event != null && event is Map && event.containsKey('approved')) {
        completer.complete(event['approved'] == true);
        sub?.cancel();
      }
    });
    service?.invoke('accessRequest', {});
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        print('[Tappy] Server: Access request timed out.');
        return false;
      },
    );
  }

  Handler get _uploadHandler => (Request request) async {
    if (request.method == 'POST' && request.url.path == 'upload') {
      // Auth check
      final token =
          request.headers['x-auth-token'] ??
          request.url.queryParameters['token'];
      if (!_isTokenValid(token)) {
        return Response.forbidden('Missing or invalid authentication token.');
      }
      return _handleUpload(request);
    }
    return Response.notFound('Not Found');
  };

  Handler get _downloadHandler => (Request request) async {
    if (request.method == 'GET' && request.url.path == 'download') {
      // Auth check
      final token =
          request.headers['x-auth-token'] ??
          request.url.queryParameters['token'];
      if (!_isTokenValid(token)) {
        return Response.forbidden('Missing or invalid authentication token.');
      }
      final fileName = request.url.queryParameters['file'];
      if (fileName == null) {
        return Response.badRequest(body: 'Missing file name parameter.');
      }

      final matchingPath = _sharableFilePaths.firstWhere(
        (path) => p.basename(path) == fileName,
        orElse: () => '',
      );

      if (matchingPath.isEmpty) {
        return Response.notFound('File not shared or not found: $fileName');
      }

      final file = File(matchingPath);
      if (!await file.exists()) {
        return Response.notFound('File not found at path: $matchingPath');
      }

      final stream = file.openRead();
      final size = await file.length();
      final headers = {
        'Content-Type': 'application/octet-stream',
        'Content-Length': size.toString(),
        'Content-Disposition':
            'attachment; filename="${p.basename(matchingPath)}"',
      };

      return Response.ok(stream, headers: headers);
    }
    return Response.notFound('Not Found');
  };

  Handler get _apiHandler => (Request request) async {
    if (request.method == 'GET' && request.url.path == 'api/shared-file') {
      final filesJson = _sharableFilePaths
          .map((path) => {'fileName': p.basename(path)})
          .toList();
      final jsonString =
          '[${filesJson.map((f) => '{"fileName": "${f['fileName']}"}').join(',')}]';
      return Response.ok(
        jsonString,
        headers: {'Content-Type': 'application/json'},
      );
    }
    return Response.notFound('Not Found');
  };

  Future<Response> _handleUpload(Request request) async {
    try {
      final contentType = request.headers['content-type'];
      if (contentType == null || !contentType.contains('multipart/form-data')) {
        return Response.badRequest(body: 'Expected multipart/form-data');
      }

      final boundary = request.headers['content-type']!
          .split(';')
          .firstWhere((s) => s.trim().startsWith('boundary='))
          .split('=')[1];
      final parts = request.read().cast<List<int>>().transform(
        MimeMultipartTransformer(boundary),
      );

      final files = <Map<String, dynamic>>[];
      // First pass: collect file info only (names, sizes)
      final partHeaders = <Map<String, String>>[];
      final partStreams = <Stream<List<int>>>[];
      await for (final part in parts) {
        partHeaders.add(part.headers);
        partStreams.add(part);
      }
      for (var i = 0; i < partHeaders.length; i++) {
        final contentDisposition = partHeaders[i]['content-disposition'];
        final filename = RegExp(
          r'filename="([^"]*)"',
        ).firstMatch(contentDisposition!)?.group(1);
        final totalBytes = int.tryParse(
          RegExp(
                r'filename="[^"]*";\s*size=(\d+)',
              ).firstMatch(contentDisposition)?.group(1) ??
              '',
        );
        if (filename != null && filename.isNotEmpty) {
          // Security: sanitize file name
          String safeName = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
          safeName = safeName.replaceAll('..', '_');
          final ext = p.extension(safeName).toLowerCase();
          if (!allowedExtensions.contains(ext)) {
            return Response.forbidden('File type not allowed: $ext');
          }
          if (totalBytes != null && totalBytes > maxFileSize) {
            return Response.forbidden('File too large (max 2GB)');
          }
          files.add({'fileName': safeName, 'fileSize': totalBytes});
        }
      }
      // Ask the app for permission to accept all files
      final accept = await _requestUploadPermissionBatch(files);
      if (!accept) {
        return Response.forbidden('Upload rejected by user.');
      }
      // Save all files (streaming)
      const publicDownloadsPath = '/storage/emulated/0/Download';
      final publicDownloads = Directory(publicDownloadsPath);
      if (!await publicDownloads.exists()) {
        try {
          await publicDownloads.create(recursive: true);
        } catch (e) {
          onLog('Error creating Download directory: $e', LogType.error);
          return Response.internalServerError(
            body: 'Could not create Download directory.',
          );
        }
      }
      for (var i = 0; i < files.length; i++) {
        String filename = files[i]['fileName'] as String;
        final totalBytes = files[i]['fileSize'] as int?;
        // Prevent overwriting: if file exists, append (1), (2), etc.
        String filePath = p.join(publicDownloads.path, filename);
        int copyNum = 1;
        while (await File(filePath).exists()) {
          final nameWithoutExt = p.basenameWithoutExtension(filename);
          final ext = p.extension(filename);
          filename = '$nameWithoutExt($copyNum)$ext';
          filePath = p.join(publicDownloads.path, filename);
          copyNum++;
        }
        final file = File(filePath);
        final sink = file.openWrite();
        int received = 0;
        await for (final chunk in partStreams[i]) {
          sink.add(chunk);
          received += chunk.length;
          if (received > maxFileSize) {
            await sink.close();
            await file.delete();
            return Response.forbidden('File too large (max 2GB)');
          }
          service?.invoke('uploadProgress', {
            'fileName': filename,
            'received': received,
            'total': totalBytes,
          });
        }
        await sink.close();
        await scanFile(filePath);
        onLog('File saved: $filePath', LogType.upload);
      }
      return Response.ok(
        '{"success": true, "message": "File(s) uploaded successfully!"}',
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, s) {
      onLog('Upload error: $e\n$s', LogType.error);
      return Response.internalServerError(
        body: '{"success": false, "message": "Upload error: $e"}',
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Helper to request upload permission for multiple files
  Future<bool> _requestUploadPermissionBatch(
    List<Map<String, dynamic>> files,
  ) async {
    if (service == null) return true;
    final completer = Completer<bool>();
    StreamSubscription? sub;
    sub = service?.on('uploadResponse').listen((event) {
      if (event is Map) {
        final map = event as Map<String, dynamic>;
        final acceptResp = map['accept'];
        if (map['files'] != null) {
          completer.complete(acceptResp == true);
          sub?.cancel();
        }
      }
    });
    service?.invoke('uploadRequest', {'files': files});
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => false,
    );
  }

  Handler get downloadHandler => _downloadHandler;

  List<String> get sharableFilePaths => _sharableFilePaths;
}
