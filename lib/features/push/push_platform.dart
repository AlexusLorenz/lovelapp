/// Browser-Push (Web Push). Auf anderen Plattformen ohne Funktion, bis die
/// nativen Builds mit Firebase Cloud Messaging kommen.
library;

export 'push_platform_stub.dart'
    if (dart.library.js_interop) 'push_platform_web.dart';
