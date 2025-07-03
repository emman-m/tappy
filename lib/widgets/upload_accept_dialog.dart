import 'package:flutter/material.dart';

Future<bool> showUploadAcceptDialog(
  BuildContext context,
  String fileName,
  int? fileSize,
) async {
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

Future<bool> showUploadAcceptDialogBatch(
  BuildContext context,
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
