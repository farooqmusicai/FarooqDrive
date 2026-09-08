import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class OfficePreviewSection {
  const OfficePreviewSection({required this.title, required this.lines});
  final String title;
  final List<String> lines;
}

class OfficePreviewData {
  const OfficePreviewData({required this.kind, required this.sections});
  final String kind;
  final List<OfficePreviewSection> sections;

  bool get isEmpty => sections.every((section) => section.lines.isEmpty);
}

bool isStructuredOfficePreview(String fileName, String mimeType) {
  final name = fileName.toLowerCase();
  final mime = mimeType.toLowerCase();
  return name.endsWith('.docx') ||
      name.endsWith('.xlsx') ||
      name.endsWith('.pptx') ||
      name.endsWith('.odt') ||
      name.endsWith('.ods') ||
      name.endsWith('.odp') ||
      mime.contains('wordprocessingml') ||
      mime.contains('spreadsheetml') ||
      mime.contains('presentationml') ||
      mime.contains('opendocument.text') ||
      mime.contains('opendocument.spreadsheet') ||
      mime.contains('opendocument.presentation');
}

OfficePreviewData? parseStructuredOfficePreview(
  Uint8List bytes,
  String fileName,
  String mimeType,
) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final name = fileName.toLowerCase();
  final mime = mimeType.toLowerCase();

  if (name.endsWith('.docx') || mime.contains('wordprocessingml')) {
    return _parseDocx(archive);
  }
  if (name.endsWith('.xlsx') || mime.contains('spreadsheetml')) {
    return _parseXlsx(archive);
  }
  if (name.endsWith('.pptx') || mime.contains('presentationml')) {
    return _parsePptx(archive);
  }
  if (name.endsWith('.odt') || mime.contains('opendocument.text')) {
    return _parseOdt(archive);
  }
  if (name.endsWith('.ods') || mime.contains('opendocument.spreadsheet')) {
    return _parseOds(archive);
  }
  if (name.endsWith('.odp') || mime.contains('opendocument.presentation')) {
    return _parseOdp(archive);
  }
  return null;
}

OfficePreviewData _parseDocx(Archive archive) {
  final xml = _xmlEntry(archive, 'word/document.xml');
  if (xml == null) return const OfficePreviewData(kind: 'Word document', sections: []);
  final document = XmlDocument.parse(xml);
  final lines = <String>[];
  for (final paragraph in _elements(document, 'p')) {
    final text = _textNodes(paragraph).join();
    final clean = _cleanLine(text);
    if (clean.isNotEmpty) lines.add(clean);
  }
  return OfficePreviewData(
    kind: 'Word document',
    sections: [OfficePreviewSection(title: 'Document', lines: lines)],
  );
}

OfficePreviewData _parseXlsx(Archive archive) {
  final sharedStrings = <String>[];
  final sharedXml = _xmlEntry(archive, 'xl/sharedStrings.xml');
  if (sharedXml != null) {
    final document = XmlDocument.parse(sharedXml);
    for (final item in _elements(document, 'si')) {
      sharedStrings.add(_textNodes(item).join());
    }
  }

  final relationships = <String, String>{};
  final relXml = _xmlEntry(archive, 'xl/_rels/workbook.xml.rels');
  if (relXml != null) {
    final document = XmlDocument.parse(relXml);
    for (final relationship in _elements(document, 'Relationship')) {
      final id = relationship.getAttribute('Id');
      final target = relationship.getAttribute('Target');
      if (id != null && target != null) relationships[id] = _zipJoin('xl', target);
    }
  }

  final sheets = <(String, String)>[];
  final workbookXml = _xmlEntry(archive, 'xl/workbook.xml');
  if (workbookXml != null) {
    final document = XmlDocument.parse(workbookXml);
    for (final sheet in _elements(document, 'sheet')) {
      final title = sheet.getAttribute('name') ?? 'Sheet ${sheets.length + 1}';
      final relationId = sheet.attributes
          .where((attribute) => attribute.name.local == 'id')
          .map((attribute) => attribute.value)
          .firstOrNull;
      final path = relationId == null ? null : relationships[relationId];
      if (path != null) sheets.add((title, path));
    }
  }

  if (sheets.isEmpty) {
    final worksheetPaths = archive
        .where((entry) => entry.isFile && entry.name.startsWith('xl/worksheets/') && entry.name.endsWith('.xml'))
        .map((entry) => entry.name)
        .toList()
      ..sort(_naturalPathCompare);
    for (var index = 0; index < worksheetPaths.length; index++) {
      sheets.add(('Sheet ${index + 1}', worksheetPaths[index]));
    }
  }

  final sections = <OfficePreviewSection>[];
  for (final sheet in sheets.take(40)) {
    final xml = _xmlEntry(archive, sheet.$2);
    if (xml == null) continue;
    final document = XmlDocument.parse(xml);
    final lines = <String>[];
    for (final row in _elements(document, 'row').take(1000)) {
      final cells = <String>[];
      for (final cell in row.childElements.where((element) => element.name.local == 'c')) {
        final reference = cell.getAttribute('r') ?? '';
        final type = cell.getAttribute('t') ?? '';
        String value = '';
        final inline = cell.descendants.whereType<XmlElement>().where((element) => element.name.local == 'is').firstOrNull;
        if (inline != null) {
          value = _textNodes(inline).join();
        } else {
          final valueElement = cell.childElements.where((element) => element.name.local == 'v').firstOrNull;
          value = valueElement?.innerText ?? '';
          if (type == 's') {
            final index = int.tryParse(value);
            if (index != null && index >= 0 && index < sharedStrings.length) value = sharedStrings[index];
          } else if (type == 'b') {
            value = value == '1' ? 'TRUE' : 'FALSE';
          }
        }
        value = _cleanLine(value);
        if (value.isNotEmpty) cells.add(reference.isEmpty ? value : '$reference: $value');
      }
      if (cells.isNotEmpty) lines.add(cells.join('   |   '));
    }
    sections.add(OfficePreviewSection(title: sheet.$1, lines: lines));
  }
  return OfficePreviewData(kind: 'Excel workbook', sections: sections);
}

OfficePreviewData _parsePptx(Archive archive) {
  final slidePaths = archive
      .where((entry) => entry.isFile && RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(entry.name))
      .map((entry) => entry.name)
      .toList()
    ..sort(_naturalPathCompare);
  final sections = <OfficePreviewSection>[];
  for (var index = 0; index < slidePaths.length && index < 200; index++) {
    final xml = _xmlEntry(archive, slidePaths[index]);
    if (xml == null) continue;
    final document = XmlDocument.parse(xml);
    final lines = _elements(document, 't')
        .map((element) => _cleanLine(element.innerText))
        .where((value) => value.isNotEmpty)
        .toList();
    sections.add(OfficePreviewSection(title: 'Slide ${index + 1}', lines: lines));
  }
  return OfficePreviewData(kind: 'PowerPoint presentation', sections: sections);
}

OfficePreviewData _parseOdt(Archive archive) {
  final xml = _xmlEntry(archive, 'content.xml');
  if (xml == null) return const OfficePreviewData(kind: 'OpenDocument text', sections: []);
  final document = XmlDocument.parse(xml);
  final lines = <String>[];
  for (final element in document.descendants.whereType<XmlElement>()) {
    if (element.name.local != 'p' && element.name.local != 'h') continue;
    final text = _cleanLine(element.innerText);
    if (text.isNotEmpty) lines.add(text);
  }
  return OfficePreviewData(
    kind: 'OpenDocument text',
    sections: [OfficePreviewSection(title: 'Document', lines: lines)],
  );
}

OfficePreviewData _parseOds(Archive archive) {
  final xml = _xmlEntry(archive, 'content.xml');
  if (xml == null) return const OfficePreviewData(kind: 'OpenDocument spreadsheet', sections: []);
  final document = XmlDocument.parse(xml);
  final sections = <OfficePreviewSection>[];
  for (final table in _elements(document, 'table').take(40)) {
    final title = table.attributes
            .where((attribute) => attribute.name.local == 'name')
            .map((attribute) => attribute.value)
            .firstOrNull ??
        'Sheet ${sections.length + 1}';
    final lines = <String>[];
    for (final row in table.descendants.whereType<XmlElement>().where((element) => element.name.local == 'table-row').take(1000)) {
      final cells = <String>[];
      for (final cell in row.childElements.where((element) => element.name.local == 'table-cell')) {
        final value = _cleanLine(cell.innerText);
        if (value.isNotEmpty) cells.add(value);
      }
      if (cells.isNotEmpty) lines.add(cells.join('   |   '));
    }
    sections.add(OfficePreviewSection(title: title, lines: lines));
  }
  return OfficePreviewData(kind: 'OpenDocument spreadsheet', sections: sections);
}

OfficePreviewData _parseOdp(Archive archive) {
  final xml = _xmlEntry(archive, 'content.xml');
  if (xml == null) return const OfficePreviewData(kind: 'OpenDocument presentation', sections: []);
  final document = XmlDocument.parse(xml);
  final sections = <OfficePreviewSection>[];
  for (final page in document.descendants.whereType<XmlElement>().where((element) => element.name.local == 'page').take(200)) {
    final lines = page.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'p' || element.name.local == 'h')
        .map((element) => _cleanLine(element.innerText))
        .where((value) => value.isNotEmpty)
        .toList();
    sections.add(OfficePreviewSection(title: 'Slide ${sections.length + 1}', lines: lines));
  }
  return OfficePreviewData(kind: 'OpenDocument presentation', sections: sections);
}

String? _xmlEntry(Archive archive, String path) {
  for (final entry in archive) {
    if (!entry.isFile || entry.name != path) continue;
    final bytes = entry.readBytes();
    if (bytes == null) return null;
    return utf8.decode(bytes, allowMalformed: true);
  }
  return null;
}

Iterable<XmlElement> _elements(XmlNode node, String localName) =>
    node.descendants.whereType<XmlElement>().where((element) => element.name.local == localName);

List<String> _textNodes(XmlNode node) => node.descendants
    .whereType<XmlElement>()
    .where((element) => element.name.local == 't')
    .map((element) => element.innerText)
    .toList();

String _cleanLine(String input) => input.replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '')
    .replaceAll(RegExp(r'[ \t]+'), ' ')
    .trim();

String _zipJoin(String base, String target) {
  final segments = <String>[];
  for (final segment in '$base/$target'.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (segments.isNotEmpty) segments.removeLast();
    } else {
      segments.add(segment);
    }
  }
  return segments.join('/');
}

int _naturalPathCompare(String a, String b) {
  final numberA = int.tryParse(RegExp(r'(\d+)(?=\.xml$)').firstMatch(a)?.group(1) ?? '');
  final numberB = int.tryParse(RegExp(r'(\d+)(?=\.xml$)').firstMatch(b)?.group(1) ?? '');
  if (numberA != null && numberB != null) return numberA.compareTo(numberB);
  return a.compareTo(b);
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
