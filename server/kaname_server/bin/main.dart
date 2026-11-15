import 'package:kaname_server/server.dart';

/// Starts the server; [args] are the Serverpod command-line arguments.
///
/// Stack migrations run only in the one-shot maintenance step
/// (`--role maintenance --apply-migrations`), because the monolith's
/// `--apply-migrations` keeps serving after a failed migration outside
/// development. The maintenance step exits 1 when the database does not match
/// the committed migrations, so the stack never starts the servers on it.
Future<void> main(List<String> args) => run(args);
