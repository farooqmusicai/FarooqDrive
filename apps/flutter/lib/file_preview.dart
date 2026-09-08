import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'drive_controller.dart';
import 'models.dart';
import 'native_file_icon.dart';
import 'office_preview.dart';

class FilePreview extends StatefulWidget {
  const FilePreview({
    super.key,
    required this.controller,
    required this.item,
    required this.onOpen,
  });

  final DriveController controller;
  final DriveItem item;
  final Future<void> Function() onOpen;

  @override
  State<FilePreview> createState() => _FilePreviewState();
}

class _FilePreviewState extends State<FilePreview> {
  static const _maxImageBytes = 20 * 1024 * 1024;
  static const _maxPdfBytes = 32 * 1024 * 1024;
  static const _maxOfficeBytes = 16 * 1024 * 1024;
  static const _maxTextBytes = 2 * 1024 * 1024;
  static const _maxTextCharacters = 250000;

  final ScrollController _textScrollController = ScrollController();
  final ScrollController _officeScrollController = ScrollController();
  Uint8List? _imageBytes;
  Uint8List? _pdfBytes;
  String? _text;
  OfficePreviewData? _officePreview;
  String? _thumbnailUrl;
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
      if (_textScrollController.hasClients) _textScrollController.jumpTo(0);
      if (_officeScrollController.hasClients) _officeScrollController.jumpTo(0);
      _load();
    }
  }

  @override
  void dispose() {
    _textScrollController.dispose();
    _officeScrollController.dispose();
    super.dispose();
  }

  bool get _isImage => widget.item.mimeType.toLowerCase().startsWith('image/');
  bool get _isPdf => widget.item.mimeType.toLowerCase() == 'application/pdf' ||
      widget.item.name.toLowerCase().endsWith('.pdf');
  bool get _isMarkdown => widget.item.name.toLowerCase().endsWith('.md') ||
      widget.item.mimeType.toLowerCase().contains('markdown');
  bool get _isOffice => isStructuredOfficePreview(widget.item.name, widget.item.mimeType);

  bool get _isLegacyOffice {
    final name = widget.item.name.toLowerCase();
    return name.endsWith('.doc') || name.endsWith('.xls') || name.endsWith('.ppt');
  }

  bool get _isText {
    if (_isOffice || _isLegacyOffice || _looksLikeBinaryContainer(widget.item.name)) return false;
    final mime = widget.item.mimeType.toLowerCase().trim();
    final name = widget.item.name.toLowerCase();
    const textExtensions = <String>{
      '.md', '.txt', '.csv', '.tsv', '.log', '.ini', '.conf', '.cfg',
      '.dart', '.js', '.mjs', '.cjs', '.ts', '.tsx', '.jsx', '.css',
      '.html', '.htm', '.json', '.xml', '.yaml', '.yml', '.toml',
      '.sql', '.py', '.java', '.kt', '.kts', '.c', '.h', '.cpp', '.hpp',
      '.sh', '.ps1', '.bat', '.cmd', '.properties', '.gradle', '.gitignore',
    };
    if (mime.startsWith('text/') && mime != 'text/rtf') return true;
    if (mime == 'application/json' ||
        mime.endsWith('+json') ||
        mime == 'application/xml' ||
        mime == 'text/xml' ||
        mime.endsWith('+xml') ||
        mime.contains('yaml') ||
        mime.contains('javascript') ||
        mime.contains('typescript') ||
        mime.contains('markdown')) {
      return true;
    }
    return textExtensions.any(name.endsWith);
  }

  bool _looksLikeBinaryContainer(String fileName) {
    final name = fileName.toLowerCase();
    const binaryExtensions = <String>{
      '.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.xz', '.iso', '.epub',
      '.docx', '.xlsx', '.pptx', '.odt', '.ods', '.odp',
      '.pages', '.numbers', '.key', '.doc', '.xls', '.ppt',
      '.exe', '.dll', '.msi', '.apk', '.ipa', '.bin', '.dat',
      '.ttf', '.otf', '.woff', '.woff2',
    };
    return binaryExtensions.any(name.endsWith);
  }

  Future<void> _load() async {
    final request = ++_request;
    if (mounted) {
      setState(() {
        _imageBytes = null;
        _pdfBytes = null;
        _text = null;
        _officePreview = null;
        _thumbnailUrl = null;
        _message = null;
        _loading = !widget.item.isFolder;
      });
    }
    if (widget.item.isFolder) return;

    final size = widget.item.size;
    final loadImage = _isImage && size != null && size <= _maxImageBytes;
    final loadPdf = _isPdf && size != null && size <= _maxPdfBytes;
    final loadOffice = _isOffice && size != null && size <= _maxOfficeBytes;
    final loadText = _isText && size != null && size <= _maxTextBytes;

    if (loadImage || loadPdf || loadOffice || loadText) {
      try {
        final bytes = await widget.controller.previewBytes(widget.item);
        if (!mounted || request != _request) return;
        if (loadImage) {
          setState(() {
            _imageBytes = bytes;
            _loading = false;
          });
          return;
        }
        if (loadPdf) {
          setState(() {
            _pdfBytes = bytes;
            _loading = false;
          });
          return;
        }
        if (loadOffice) {
          final office = parseStructuredOfficePreview(
            bytes,
            widget.item.name,
            widget.item.mimeType,
          );
          if (office != null && !office.isEmpty) {
            setState(() {
              _officePreview = office;
              _message = 'Content preview. Double-click for full Microsoft/Google formatting and editing.';
              _loading = false;
            });
            return;
          }
        }
        if (loadText) {
          var value = utf8.decode(bytes, allowMalformed: true);
          if (_hasTooManyBinaryControls(value)) {
            throw const FormatException('Binary content was not shown as text.');
          }
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
          return;
        }
      } catch (_) {
        // Never expose raw package/binary bytes. Try a provider-rendered thumbnail next.
      }
    }

    try {
      final thumbnail = await widget.controller.previewThumbnailUrl(widget.item);
      if (!mounted || request != _request) return;
      setState(() {
        _thumbnailUrl = thumbnail;
        _loading = false;
        if (_isPdf && size != null && size > _maxPdfBytes) {
          _message = 'PDF preview is limited to 32 MB; a provider preview is shown when available.';
        } else if (_isOffice && size != null && size > _maxOfficeBytes) {
          _message = 'Office content preview is limited to 16 MB; a provider preview is shown when available.';
        } else if (_isLegacyOffice) {
          _message = 'Older binary Office formats are not decoded as text. Double-click for the full provider view.';
        } else if (_isText && size != null && size > _maxTextBytes) {
          _message = 'Text preview is limited to 2 MB so selecting a large file stays fast.';
        } else if (_isImage && size != null && size > _maxImageBytes) {
          _message = 'This image is larger than 20 MB; the provider preview is shown when available.';
        } else if (thumbnail == null) {
          _message = 'A safe in-app content preview is not available for this file type. Double-click to open it.';
        }
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _message = 'A safe in-app content preview is not available for this file type. Double-click to open it.';
      });
    }
  }

  bool _hasTooManyBinaryControls(String value) {
    if (value.isEmpty) return false;
    final sample = value.length > 8192 ? value.substring(0, 8192) : value;
    var controls = 0;
    for (final rune in sample.runes) {
      if (rune == 9 || rune == 10 || rune == 13) continue;
      if (rune < 32) controls++;
    }
    return controls > sample.length ~/ 100;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                NativeFileIcon(fileName: item.name, isFolder: item.isFolder, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(item.accountEmail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Open in browser',
                  onPressed: () => widget.onOpen(),
                  icon: const Icon(Icons.open_in_new),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _previewBody(),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(_message!, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 8),
            _details(),
            const SizedBox(height: 6),
            Text(
              'Single-click selects and previews. Double-click opens in your browser.',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewBody() {
    final theme = Theme.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_pdfBytes != null) {
      return PdfViewer.data(
        _pdfBytes!,
        sourceName: widget.item.name,
      );
    }
    if (_imageBytes != null) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 5,
        child: Center(
          child: Image.memory(_imageBytes!, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _fallbackPreview()),
        ),
      );
    }
    if (_officePreview != null) return _officeBody(_officePreview!);
    if (_text != null) {
      return Scrollbar(
        controller: _textScrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _textScrollController,
          primary: false,
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            _text!,
            style: TextStyle(
              fontFamily: _isMarkdown ? null : 'Consolas',
              fontSize: _isMarkdown ? 13.5 : 12.5,
              height: 1.4,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      );
    }
    if (_thumbnailUrl != null && _thumbnailUrl!.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Image.network(
          _thumbnailUrl!,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _fallbackPreview(),
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return _fallbackPreview(color: theme.colorScheme.onSurfaceVariant);
  }

  Widget _officeBody(OfficePreviewData preview) {
    final theme = Theme.of(context);
    final spreadsheet = preview.kind.toLowerCase().contains('spreadsheet') ||
        preview.kind.toLowerCase().contains('excel');
    return Scrollbar(
      controller: _officeScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _officeScrollController,
        primary: false,
        padding: const EdgeInsets.all(12),
        child: SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(preview.kind,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  )),
              const SizedBox(height: 10),
              for (final section in preview.sections) ...[
                Text(section.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                if (section.lines.isEmpty)
                  Text('(No readable text in this section)',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant))
                else
                  for (final line in section.lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        line,
                        style: TextStyle(
                          fontFamily: spreadsheet ? 'Consolas' : null,
                          fontSize: spreadsheet ? 12 : 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                const Divider(height: 22),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackPreview({Color? color}) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NativeFileIcon(fileName: widget.item.name, isFolder: widget.item.isFolder, size: 64),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'No safe in-app preview is available for this format. Double-click to open the provider view in your browser.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: color ?? theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _details() {
    final theme = Theme.of(context);
    final item = widget.item;
    final fileSize = item.size == null ? 'Not reported' : _formatBytes(item.size!);
    final modified = item.modifiedTime == null ? 'Not reported' : item.modifiedTime!.toLocal().toString();
    return DefaultTextStyle(
      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Type: ${item.mimeType}'),
          Text('Size: $fileSize'),
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
