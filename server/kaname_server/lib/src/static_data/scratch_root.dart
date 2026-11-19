/// Where the imports of one database keep their temporary files.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'postgres_connection_settings.dart';

/// The scratch root for the database [settings] name.
///
/// The static-data lock is per database, so the directory that an import
/// sweeps for a killed import's leftovers must be per database too:
/// `<base>/kaname_sde_import/<hash>`, where `base` defaults to the system
/// temporary directory and `hash` is 16 hex digits (FNV-1a, 64 bit) of the
/// database's identity, which is `socket|<path>|<database>` for a Unix
/// socket and `tcp|<host>|<port>|<database>` otherwise. The user, the
/// password and the TLS flag are not part of it, so a credential never
/// reaches a path. The same settings always give the same directory.
Directory sdeScratchRootFor(
  PostgresConnectionSettings settings, {
  Directory? base,
}) {
  final identity = settings.isUnixSocket
      ? 'socket|${settings.host}|${settings.database}'
      : 'tcp|${settings.host}|${settings.port}|${settings.database}';
  return Directory(
    p.join(
      (base ?? Directory.systemTemp).path,
      'kaname_sde_import',
      _fnv1a64Hex(identity),
    ),
  );
}

String _fnv1a64Hex(String text) {
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = (BigInt.one << 64) - BigInt.one;
  for (final unit in text.codeUnits) {
    hash = ((hash ^ BigInt.from(unit)) * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
