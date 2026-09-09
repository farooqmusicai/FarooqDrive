import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as image;
import 'package:win32/win32.dart';

/// Reads the registered Windows type icon without opening a file or loading
/// a thumbnail handler. All native allocations and GDI handles are scoped.
Uint8List? readWindowsTypeIcon(String extension, {required bool isFolder}) {
  final comStatus = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  final name = (isFolder ? 'folder' : 'sample$extension').toNativeUtf16();
  final fileInfo = calloc<SHFILEINFO>();
  final iconInfo = calloc<ICONINFO>();
  final bitmap = calloc<BITMAP>();
  final info = calloc<BITMAPINFO>();
  Pointer<Uint8>? pixels;
  var dc = 0;
  try {
    final result = SHGetFileInfo(
        name,
        isFolder
            ? FILE_ATTRIBUTE_DIRECTORY
            : FILE_ATTRIBUTE_NORMAL,
        fileInfo,
        sizeOf<SHFILEINFO>(),
        SHGFI_ICON | SHGFI_LARGEICON | SHGFI_USEFILEATTRIBUTES);
    if (result == 0 || fileInfo.ref.hIcon == 0) return null;
    if (GetIconInfo(fileInfo.ref.hIcon, iconInfo) == 0 ||
        iconInfo.ref.hbmColor == 0) { return null; }
    if (GetObject(iconInfo.ref.hbmColor, sizeOf<BITMAP>(), bitmap) == 0) {
      return null;
    }
    final width = bitmap.ref.bmWidth;
    final height = bitmap.ref.bmHeight.abs();
    if (width <= 0 || height <= 0 || width > 512 || height > 512) return null;
    // Force 32-bit BI_RGB: no palette or bit masks can overrun BITMAPINFO.
    // biSizeImage may legitimately be zero in a queried bitmap, so compute
    // the exact DWORD-aligned allocation instead of trusting that field.
    final size = width * height * 4;
    info.ref.bmiHeader
      ..biSize = sizeOf<BITMAPINFOHEADER>()
      ..biWidth = width
      ..biHeight = -height
      ..biPlanes = 1
      ..biBitCount = 32
      ..biCompression = BI_RGB
      ..biSizeImage = size;
    pixels = calloc<Uint8>(size);
    dc = GetDC(0);
    if (dc == 0) return null;
    if (GetDIBits(dc, iconInfo.ref.hbmColor, 0, height, pixels, info,
            DIB_RGB_COLORS) !=
        height) { return null; }
    final copy = Uint8List.fromList(pixels.asTypedList(size));
    final decoded = image.Image.fromBytes(
        width: width,
        height: height,
        bytes: copy.buffer,
        order: image.ChannelOrder.bgra);
    return Uint8List.fromList(image.encodePng(decoded));
  } finally {
    if (dc != 0) ReleaseDC(0, dc);
    if (pixels != null) calloc.free(pixels);
    if (iconInfo.ref.hbmColor != 0) DeleteObject(iconInfo.ref.hbmColor);
    if (iconInfo.ref.hbmMask != 0) DeleteObject(iconInfo.ref.hbmMask);
    if (fileInfo.ref.hIcon != 0) DestroyIcon(fileInfo.ref.hIcon);
    calloc.free(info);
    calloc.free(bitmap);
    calloc.free(iconInfo);
    calloc.free(fileInfo);
    calloc.free(name);
    if (comStatus >= 0) CoUninitialize();
  }
}
