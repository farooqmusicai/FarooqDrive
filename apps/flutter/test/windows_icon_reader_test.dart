import 'dart:io';
import 'dart:ffi';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:win32/win32.dart';
import 'package:farooqdrive/windows_icon_reader.dart';

void main() {
  test('native icon reader returns valid images and releases GDI objects', () {
    final getGuiResources = DynamicLibrary.open('user32.dll').lookupFunction<
        Uint32 Function(IntPtr, Uint32), int Function(int, int)>('GetGuiResources');
    const extensions = ['', '.txt', '.pdf', '.docx', '.xlsx', '.png', '.unknown_extension'];
    // Warm up the shell's shared icon cache before measuring owned handles.
    for (final extension in extensions) {
      readWindowsTypeIcon(extension, isFolder: false);
    }
    final before = getGuiResources(GetCurrentProcess(), 0);
    for (var i = 0; i < 100; i++) {
      final bytes = readWindowsTypeIcon(extensions[i % extensions.length], isFolder: i % 8 == 0);
      expect(bytes, isNotNull);
      final decoded = image.decodePng(bytes!);
      expect(decoded, isNotNull);
      expect(decoded!.width, inInclusiveRange(1, 512));
      expect(decoded.height, inInclusiveRange(1, 512));
    }
    final after = getGuiResources(GetCurrentProcess(), 0);
    expect(after - before, lessThan(10));
  }, skip: !Platform.isWindows);
}
