import 'package:flutter/material.dart';

class FileProgressBar extends StatelessWidget {
  final String fileName;
  final double progress; // 0.0-1.0, or -1.0 for indeterminate
  const FileProgressBar({
    Key? key,
    required this.fileName,
    required this.progress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Receiving: $fileName'),
        progress >= 0
            ? LinearProgressIndicator(value: progress)
            : const LinearProgressIndicator(),
        const SizedBox(height: 8),
      ],
    );
  }
}
