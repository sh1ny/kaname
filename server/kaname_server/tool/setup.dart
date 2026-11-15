import 'dart:io';
import 'dart:math';

import 'package:yaml/yaml.dart';

/// The ignored secrets file, relative to the server package.
const passwordsPath = 'config/passwords.yaml';

/// The ignored environment file for `docker-compose.yaml`, relative to the
/// server package.
const envPath = '.env';

/// The variable in [envPath] that holds the development Redis password.
const _redisVariable = 'KANAME_REDIS_PASSWORD';

/// The length of every generated password.
const _passwordLength = 32;

const _alphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/// Reads and writes the files [runSetup] manages, by path relative to the
/// server package.
abstract interface class SetupFiles {
  /// The contents of the file at [path], or `null` when it does not exist.
  String? read(String path);

  /// Writes [content] to the file at [path], creating its directory and
  /// replacing any earlier contents.
  void write(String path, String content);
}

/// Reports a setup failure that the person running the task must fix.
final class SetupException implements Exception {
  /// Creates an exception that carries [message].
  const SetupException(this.message);

  /// What went wrong and how to fix it.
  final String message;

  @override
  String toString() => message;
}

/// What [runSetup] did with the secrets file.
enum SetupOutcome {
  /// There was no `passwords.yaml`, so setup generated one.
  created,

  /// A `passwords.yaml` existed, so setup left it unchanged.
  kept,
}

/// Creates `config/passwords.yaml` in [files] when it is missing, then
/// derives the development Redis `.env` from it, and returns which happened
/// to the secrets file.
///
/// Passwords are drawn from [random]; production use passes
/// [Random.secure]. An existing secrets file is never rewritten. The `.env`
/// file is rewritten on every call, so the secrets file stays the only
/// source.
///
/// Throws a [SetupException] when the secrets file does not give development
/// and test the same Redis password, because both use the one development
/// Redis container.
SetupOutcome runSetup(SetupFiles files, Random random) {
  var text = files.read(passwordsPath);
  final SetupOutcome outcome;
  if (text == null) {
    text = _newPasswordsFile(random);
    files.write(passwordsPath, text);
    outcome = SetupOutcome.created;
  } else {
    outcome = SetupOutcome.kept;
  }
  files.write(envPath, '$_redisVariable=${_sharedRedisPassword(text)}\n');
  return outcome;
}

/// The text of a new secrets file with fresh passwords drawn from [random].
///
/// One Redis password is `shared` by every mode that reads it; the database
/// password and service secret differ per mode.
String _newPasswordsFile(Random random) {
  String password() => _quote(
    String.fromCharCodes(
      Iterable.generate(
        _passwordLength,
        (_) => _alphabet.codeUnitAt(random.nextInt(_alphabet.length)),
      ),
    ),
  );
  final buffer = StringBuffer()
    ..writeln('# Created by `mise run server:setup`. Ignored by git: never')
    ..writeln('# commit it. Development and test share one Redis password,')
    ..writeln('# because both use the one development Redis container.')
    ..writeln('shared:')
    ..writeln('  redis: ${password()}');
  for (final mode in const ['development', 'test']) {
    buffer
      ..writeln('$mode:')
      ..writeln('  database: ${password()}')
      ..writeln('  serviceSecret: ${password()}');
  }
  return buffer.toString();
}

/// [value] as a double-quoted YAML scalar.
String _quote(String value) => '"$value"';

/// The Redis password that development and test share, read from the secrets
/// file [text].
///
/// A mode section overrides `shared`, as Serverpod resolves it. Throws a
/// [SetupException] when the file is not a map, has no Redis password, or
/// gives development and test different ones.
String _sharedRedisPassword(String text) {
  final YamlMap passwords;
  try {
    passwords = switch (loadYaml(text)) {
      final YamlMap map => map,
      _ => throw const SetupException('$passwordsPath is not a YAML map.'),
    };
  } on YamlException catch (error) {
    throw SetupException('$passwordsPath is not valid YAML: ${error.message}');
  }

  String? redisOf(String section) => switch (passwords[section]) {
    {'redis': final Object redis} => '$redis',
    _ => null,
  };

  final shared = redisOf('shared');
  final development = redisOf('development') ?? shared;
  final test = redisOf('test') ?? shared;
  return switch ((development, test)) {
    (final dev?, final tst?) when dev == tst => dev,
    (final _?, final _?) => throw const SetupException(
      '$passwordsPath gives development and test different Redis passwords. '
      'They share one Redis container: keep one `redis` under `shared`.',
    ),
    _ => throw const SetupException(
      '$passwordsPath has no Redis password for development and test. Add '
      '`redis` under `shared`, or delete the file to generate a new one.',
    ),
  };
}

/// A [SetupFiles] on the real file system, rooted at [root].
final class _DiskFiles implements SetupFiles {
  _DiskFiles(this.root);

  final Directory root;

  File _file(String path) => File.fromUri(root.uri.resolve(path));

  @override
  String? read(String path) {
    final file = _file(path);
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  @override
  void write(String path, String content) => _file(path)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(content);
}

/// Runs the server's development setup in the current directory, which must
/// be the server package.
///
/// `config/passwords.yaml` is the only source of development and test
/// secrets; development and test share one Redis password, and the
/// development Redis `.env` is derived from it (D11).
///
/// Exits non-zero, printing the reason to stderr, when the secrets file is
/// unusable.
void main() {
  try {
    final outcome = runSetup(_DiskFiles(Directory.current), Random.secure());
    stdout.writeln(switch (outcome) {
      SetupOutcome.created => 'Created $passwordsPath and wrote $envPath.',
      SetupOutcome.kept => 'Kept $passwordsPath and rewrote $envPath.',
    });
  } on SetupException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}
