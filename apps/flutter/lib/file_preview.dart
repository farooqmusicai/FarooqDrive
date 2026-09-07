import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'drive_controller.dart';
import 'models.dart';
import 'native_file_icon.dart';

class FilePreview extends StatefulWidget {
  const FilePreview({
    super.key,
    required this.controller,
    required this.item,
    required this.onOpen,
  });

  final DriveController controller;
  final DriveItem item;
  final VoidCallback onOpen;

  @override
  State<FilePreview> createState() => _FilePreviewState();
}

class _FilePreviewState extends State<FilePreview> {
  static const _maxImageBytes = 20 * 1024 * 1024;
  static const _maxTextBytes = 2 * 1024 * 1024;
  static const _maxTextCharacters = 250000;

  Uint8List? _imageBytes;
  String? _text;
  String? _message;
  bool _loading = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FilePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.accountId != widget.item.accountId) {
      _load();
    }
  }

  bool get _isImage => widget.item.mimeType.startsWith('image/');

  bool get _isText {
    final mime = widget.item.mimeType.toLowerCase();
    final name = widget.item.name.toLowerCase();
    return mime.startsWith('text/') ||
        mime.contains('json') ||
        mime.contains('xml') ||
        mime.contains('yaml') ||
        mime.contains('javascript') ||
        mime.contains('typescript') ||
        name.endsWith('.md') ||
        name.endsWith('.txt') ||
        name.endsWith('.csv') ||
        name.endsWith('.log') ||
        name.endsWith('.ini') ||
        name.endsWith('.conf') ||
        name.endsWith('.dart') ||
        name.endsWith('.js') ||
        name.endsWith('.ts') ||
        name.endsWith('.css') ||
        name.endsWith('.html') ||
        name.endsWith('.htm') ||
        name.endsWith('.json') ||
        name.endsWith('.xml') ||
        name.endsWith('.yaml') ||
        name.endsWith('.yml');
  }

  Future<void> _load() async {
    final request = ++_request;
    if (mounted) {
      setState(() {
        _imageBytes = null;
        _text = null;
        _message = null;
        _loading = false;
      });
    }

    if (widget.item.isFolder) return;

    final size = widget.item.size;
    final shouldLoadImage = _isImage && size != null && size <= _maxImageBytes;
    final shouldLoadText = _isText && size != null && size <= _maxTextBytes;

    if (!shouldLoadImage && !shouldLoadText) {
      if (_isText && size != null && size > _maxTextBytes) {
        if (mounted && request == _request) {
          setState(() => _message =
              'Text preview is limited to 2 MB so selecting a large file stays fast.');
        }
      } else if (_isImage && size != null && size > _maxImageBytes) {
        if (mounted && request == _request) {
          setState(() => _message =
              'This image is larger than 20 MB. Showing the Drive thumbnail when available.');
        }
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final bytes = await widget.controller.previewBytes(widget.item);
      if (!mounted || request != _request) return;
      if (shouldLoadImage) {
        setState(() {
          _imageBytes = bytes;
          _loading = false;
        });
      } else {
        var value = utf8.decode(bytes, allowMalformed: true);
        var truncated = false;
        if (value.length > _maxTextCharacters) {
          value = value.substring(0, _maxTextCharacters);
          truncated = true;
        }
        setState(() {
          _text = value;
          _message = truncated
              ? 'Preview shortened to the first 250,000 characters.'
              : null;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _message = 'A full in-app preview is not available for this file type.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return ColoredBox(
      color: const Color(0xfff8fafc),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                NativeFileIcon(
                  fileName: item.name,
                  isFolder: item.isFolder,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        item.accountEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xff64748b),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Open in browser',
                  onPressed: widget.onOpen,
                  icon: const Icon(Icons.open_in_new),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xffdce3ed)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _previewBody(),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(
                _message!,
                style: const TextStyle(fontSize: 11, color: Color(0xff64748b)),
              ),
            ],
            const SizedBox(height: 8),
            _details(),
            const SizedBox(height: 6),
            const Text(
              'Single-click selects and previews. Double-click opens in your browser.',
              style: TextStyle(fontSize: 11, color: Color(0xff64748b)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_imageBytes != null) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 5,
        child: Center(
          child: Image.memory(
            _imageBytes!,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _fallbackPreview(),
          ),
        ),
      );
    }
    if (_text != null) {
      return Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            _text!,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      );
    }
    final thumbnail = widget.item.thumbnailLink;
    if (thumbnail != null && thumbnail.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Image.network(
          thumbnail,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _fallbackPreview(),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return _fallbackPreview();
  }

  Widget _fallbackPreview() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NativeFileIcon(
              fileName: widget.item.name,
              isFolder: widget.item.isFolder,
              size: 64,
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'No in-app visual preview is available. Double-click the file to open its Google Drive view in the browser.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xff64748b)),
              ),
            ),
          ],
        ),
      );

  Widget _details() {
    final item = widget.item;
    final size = item.size == null ? 'Not reported' : _formatBytes(item.size!);
    final modified = item.modifiedTime == null
        ? 'Not reported'
        : item.modifiedTime!.toLocal().toString();
    return DefaultTextStyle(
      style: const TextStyle(fontSize: 11, color: Color(0xff475569)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Type: ${item.mimeType}'),
          Text('Size: $size'),
          Text('Location: ${item.location}'),
          Text('Modified: $modified'),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1)} ${units[unit]}';
  }
}
