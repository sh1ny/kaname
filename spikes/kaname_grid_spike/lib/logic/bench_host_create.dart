/// Picks the benchmark host for the build target with a conditional import.
///
/// `dart:js_interop` exists on web builds only, so VM builds and tests get
/// the inert host and web builds get the browser host.
library;

export 'bench_host_stub.dart'
    if (dart.library.js_interop) 'bench_host_web.dart';
