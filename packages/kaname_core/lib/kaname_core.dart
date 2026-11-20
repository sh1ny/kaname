/// Pure-Dart domain code shared by the Kaname app, server and tools.
///
/// This package must not depend on or import Flutter, `dart:ui` or
/// Serverpod, so every part of Kaname can use it. Shared Flutter code lives
/// in `app_packages/` instead.
library;

export 'src/job.dart';
export 'src/realtime_bus.dart';
export 'src/sde_json.dart';
export 'src/worker_message.dart';

/// The product name shown to users.
const String productName = 'Kaname';
