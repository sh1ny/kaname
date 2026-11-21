/// The `package:http` client of one bundle transfer, picked by conditional
/// import (design D4, contract C26).
///
/// Native platforms get an `IOClient` whose abort also ends connection
/// setup (name lookup, TCP connect and the TLS handshake); the web gets the
/// browser client, whose fetch the request's abort trigger cancels.
library;

export 'bundle_http_client_io.dart'
    if (dart.library.js_interop) 'bundle_http_client_web.dart';
