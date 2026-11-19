import 'package:kaname_server/src/static_data/postgres_connection_settings.dart';
import 'package:kaname_server/src/static_data/postgres_settings_resolver.dart';
import 'package:serverpod/serverpod.dart';

/// The settings of the database a `withServerpod` group runs on.
///
/// The group's server applies the committed migrations to its own ephemeral
/// database before the tests run, so a connection opened with these settings
/// sees the real schema. It is the production resolver
/// ([resolveWorkerPostgresSettings]) applied to the test run mode's embedded
/// Postgres.
///
/// Use it with `rollbackDatabase: RollbackDatabase.disabled`: a second
/// connection sees only what the group's session has committed.
Future<PostgresConnectionSettings> migratedDatabaseSettings(Session session) =>
    resolveWorkerPostgresSettings(session);
