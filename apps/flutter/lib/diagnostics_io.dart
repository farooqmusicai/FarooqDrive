import 'dart:io';

void writeDiagnostic(String message, StackTrace? stack) {
  try {
    final localData = Platform.environment['LOCALAPPDATA'];
    if (localData == null || localData.isEmpty) return;
    final directory = Directory(
      '$localData${Platform.pathSeparator}FarooqDrive',
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
