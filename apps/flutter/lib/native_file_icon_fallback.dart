import 'package:flutter/material.dart';

class NativeFileIcon extends StatelessWidget {
  const NativeFileIcon({
    super.key,
    required this.fileName,
    required this.isFolder,
    this.size = 22,
  });

  final String fileName;
  final bool isFolder;
  final double size;

  @override
  Widget build(BuildContext context) => Icon(
        isFolder ? Icons.folder : Icons.insert_drive_file,
        size: size,
        color: isFolder ? const Color(0xffffb21c) : const Color(0xff6d829b),
      );
}
