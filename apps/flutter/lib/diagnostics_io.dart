import 'dart:io';
import 'app_storage_windows.dart';

void writeDiagnostic(String message, StackTrace? stack) {
  try {
    final directory = Directory(
      AppStorage.root,
    )..createSync(recursive: true);
    final log = File(
      '${directory.path}${Platform.pathSeparator}farooqdrive-crash.log',
    );
    log.writeAsStringSync(
      '[${DateTime.now().toUtc().toIso8601String()}] $message\n'
      '${stack ?? ''}\n\n',
      mode: FileMode.append,
      flush: true,
    );
  } catch (_) {
    // Diagnostics must never interfere with application startup.
  }
}
