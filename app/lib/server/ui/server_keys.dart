import 'package:flutter/widgets.dart';

/// Keys that name the server controls, so tests can find them.
abstract final class ServerKeys {
  /// The status bar's server indicator.
  static const Key indicator = Key('server.indicator');

  /// The Settings → Server row that shows the server version.
  static const Key version = Key('server.version');

  /// The Settings → Server row that shows Postgres.
  static const Key postgres = Key('server.postgres');

  /// The Settings → Server row that shows Redis.
  static const Key redis = Key('server.redis');

  /// The Settings → Server "Check again" control.
  static const Key checkAgain = Key('server.checkAgain');
}
