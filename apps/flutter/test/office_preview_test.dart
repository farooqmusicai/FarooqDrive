import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farooqdrive/office_preview.dart';

Uint8List _zip(Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile.string(entry.key, entry.value));
  }
  final encoded = ZipEncoder().encode(archive);
  return Uint8List.fromList(encoded);
}

void main() {
  test('DOCX parser shows document text instead of package XML', () {
    final bytes = _zip({
      'word/document.xml': '''
        <w:document xmlns:w="urn:w"><w:body>
          <w:p><w:r><w:t>Hindi Names</w:t></w:r></w:p>
          <w:p><w:r><w:t>Ravi (Surya)</w:t></w:r><w:r><w:t> — Sun</w:t></w:r></w:p>
        </w:body></w:document>
      ''',
    });
    final preview = parseStructuredOfficePreview(
      bytes,
      'Hindi Names.docx',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    expect(preview, isNotNull);
    expect(preview!.kind, contains('Word'));
    expect(preview.sections.single.lines, contains('Hindi Names'));
    expect(preview.sections.single.lines.join('\n'), contains('Ravi (Surya) — Sun'));
    expect(preview.sections.single.lines.join('\n'), isNot(contains('[Content_Types].xml')));
  });

  test('XLSX parser resolves shared strings and cell values', () {
    final bytes = _zip({
      'xl/workbook.xml': '''
        <workbook xmlns:r="urn:r"><sheets>
          <sheet name="Accounts" r:id="rId1"/>
        </sheets></workbook>
      ''',
      'xl/_rels/workbook.xml.rels': '''
        <Relationships><Relationship Id="rId1" Target="worksheets/sheet1.xml"/></Relationships>
      ''',
      'xl/sharedStrings.xml': '''
        <sst><si><t>Account Details</t></si><si><t>PKR</t></si></sst>
      ''',
      'xl/worksheets/sheet1.xml': '''
        <worksheet><sheetData>
          <row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row>
          <row r="2"><c r="A2"><v>4708616.62</v></c></row>
        </sheetData></worksheet>
      ''',
    });
    final preview = parseStructuredOfficePreview(
      bytes,
      'Tahira-TAX Details-2026.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    expect(preview, isNotNull);
    expect(preview!.kind, contains('Excel'));
    expect(preview.sections.single.title, 'Accounts');
    final text = preview.sections.single.lines.join('\n');
    expect(text, contains('A1: Account Details'));
    expect(text, contains('B1: PKR'));
    expect(text, contains('A2: 4708616.62'));
  });

  test('PPTX parser returns ordered slide text', () {
    final bytes = _zip({
      'ppt/slides/slide2.xml': '<p:sld xmlns:p="urn:p" xmlns:a="urn:a"><a:t>Second</a:t></p:sld>',
      'ppt/slides/slide1.xml': '<p:sld xmlns:p="urn:p" xmlns:a="urn:a"><a:t>First</a:t></p:sld>',
    });
    final preview = parseStructuredOfficePreview(
      bytes,
      'demo.pptx',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    );
    expect(preview, isNotNull);
    expect(preview!.sections.map((section) => section.lines.single).toList(), ['First', 'Second']);
  });

  test('structured Office classifier covers OOXML and OpenDocument', () {
    expect(isStructuredOfficePreview('a.docx', 'application/octet-stream'), isTrue);
    expect(isStructuredOfficePreview('a.xlsx', 'application/octet-stream'), isTrue);
    expect(isStructuredOfficePreview('a.pptx', 'application/octet-stream'), isTrue);
    expect(isStructuredOfficePreview('a.odt', 'application/octet-stream'), isTrue);
    expect(isStructuredOfficePreview('a.txt', 'text/plain'), isFalse);
  });
}
