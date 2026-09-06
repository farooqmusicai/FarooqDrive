export 'microsoft_auth_stub.dart'
    if (dart.library.js_interop) 'microsoft_auth_web.dart'
    if (dart.library.io) 'microsoft_auth_desktop.dart';
