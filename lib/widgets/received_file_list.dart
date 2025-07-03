import 'package:flutter/material.dart';

class ReceivedFileList extends StatelessWidget {
  final List<String> files;
  const ReceivedFileList({Key? key, required this.files}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Files received this session:',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        ...files.map(
          (f) => ListTile(
            leading: const Icon(Icons.file_download),
            title: Text(f, overflow: TextOverflow.ellipsis),
            dense: true,
          ),
        ),
      ],
    );
  }
}
