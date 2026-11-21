/// The web client of one bundle transfer.
library;

import 'package:http/http.dart' as http;

/// Creates the client of one transfer; the browser cancels its fetch when
/// the request's abort trigger fires, so [abort] needs no handling here.
http.Client abortableBundleClient(Future<void> abort) => http.Client();
