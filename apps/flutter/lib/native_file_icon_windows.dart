import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'windows_icon_reader.dart';

class NativeFileIcon extends StatefulWidget {
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
  State<NativeFileIcon> createState() => _NativeFileIconState();
}

class _NativeFileIconState extends State<NativeFileIcon> {
  static final Map<String, Future<Uint8List?>> _cache = {};
  late Future<Uint8List?> _icon;

  @override
  void initState() {
    super.initState();
    _icon = _load();
  }

  @override
  void didUpdateWidget(covariant NativeFileIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileName != widget.fileName ||
        oldWidget.isFolder != widget.isFolder) {
      _icon = _load();
    }
  }

  Future<Uint8List?> _load() {
    final extension = widget.isFolder
        ? '<folder>'
        : widget.fileName.contains('.')
            ? widget.fileName.split('.').last.toLowerCase()
            : '<file>';
    return _cache.putIfAbsent(extension, () async {
      try {
        final suffix = extension.startsWith('<') ? '' : '.$extension';
        return readWindowsTypeIcon(suffix, isFolder: widget.isFolder);
      } catch (_) {
        return null;
      }
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
        future: _icon,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes != null && bytes.isNotEmpty) {
            return Image.memory(
              bytes,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _fallback(),
            );
          }
          return _fallback();
        },
      );

  Widget _fallback() => Icon(
        widget.isFolder ? Icons.folder : Icons.insert_drive_file,
        size: widget.size,
        color: widget.isFolder
            ? const Color(0xffffb21c)
            : const Color(0xff6d829b),
      );
}
