import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'cli.dart';

/// The address `serve` binds when `--host` is not given.
const String defaultServeHost = '127.0.0.1';

/// The port `serve` binds when `--port` is not given.
const int defaultServePort = 8080;

/// How long `serve` keeps an idle connection open.
const Duration serveIdleTimeout = Duration(seconds: 30);

final Map<String, ContentType> _contentTypes = {
  '.html': ContentType('text', 'html', charset: 'utf-8'),
  '.mjs': ContentType('text', 'javascript', charset: 'utf-8'),
  '.js': ContentType('text', 'javascript', charset: 'utf-8'),
  '.css': ContentType('text', 'css', charset: 'utf-8'),
  '.json': ContentType('application', 'json', charset: 'utf-8'),
  '.svg': ContentType('image', 'svg+xml', charset: 'utf-8'),
  '.wasm': ContentType('application', 'wasm'),
  '.png': ContentType('image', 'png'),
  '.ico': ContentType('image', 'x-icon'),
  '.ttf': ContentType('font', 'ttf'),
  '.otf': ContentType('font', 'otf'),
};

final ContentType _octetStream = ContentType('application', 'octet-stream');

/// Binds a static file server that serves [root] on [host] and [port].
///
/// Pass port `0` to let the system pick one; the bound port is
/// [HttpServer.port]. With [isolation] set, every response carries
/// `Cross-Origin-Opener-Policy: same-origin` and
/// `Cross-Origin-Embedder-Policy: require-corp`.
///
/// Only `GET` and `HEAD` are answered. `/` serves `index.html`; any other path
/// that is not a file, directories included, gets a plain 404 with no
/// fallback page. A path that has a `..` or an encoded separator segment, or a
/// symbolic link that resolves outside [root], gets a 403.
///
/// Throws a [SocketException] when the address cannot be bound. The caller
/// closes the returned server.
Future<HttpServer> bindStaticServer({
  required String root,
  String host = defaultServeHost,
  int port = defaultServePort,
  bool isolation = true,
}) async {
  final resolvedRoot = Directory(root).resolveSymbolicLinksSync();
  final server = await HttpServer.bind(host, port);
  server.idleTimeout = serveIdleTimeout;
  server.listen((request) {
    unawaited(
      _respond(request, resolvedRoot, isolation: isolation).catchError((
        Object _,
      ) {
        // The client went away mid-response; nothing is left to answer.
      }),
    );
  });
  return server;
}

Future<void> _respond(
  HttpRequest request,
  String root, {
  required bool isolation,
}) async {
  final response = request.response;
  if (isolation) {
    response.headers
      ..set('Cross-Origin-Opener-Policy', 'same-origin')
      ..set('Cross-Origin-Embedder-Policy', 'require-corp');
  }
  final method = request.method;
  if (method != 'GET' && method != 'HEAD') {
    response.headers.set(HttpHeaders.allowHeader, 'GET, HEAD');
    return _plain(response, HttpStatus.methodNotAllowed, 'Method Not Allowed');
  }
  final File file;
  switch (_resolve(request.uri, root)) {
    case null:
      return _plain(response, HttpStatus.forbidden, 'Forbidden');
    case final File found when found.existsSync():
      file = found;
    case _:
      return _plain(response, HttpStatus.notFound, 'Not Found');
  }
  final String real;
  try {
    real = file.resolveSymbolicLinksSync();
  } on FileSystemException {
    return _plain(response, HttpStatus.notFound, 'Not Found');
  }
  if (!p.isWithin(root, real)) {
    return _plain(response, HttpStatus.forbidden, 'Forbidden');
  }
  response
    ..statusCode = HttpStatus.ok
    ..headers.contentType =
        _contentTypes[p.extension(real).toLowerCase()] ?? _octetStream
    ..contentLength = file.lengthSync();
  if (method == 'HEAD') return response.close();
  await response.addStream(file.openRead());
  await response.close();
}

/// The file [uri] names under [root] (it may not exist), or `null` when the
/// path could leave [root].
File? _resolve(Uri uri, String root) {
  if (uri.path == '/') return File(p.join(root, 'index.html'));
  final segments = uri.pathSegments;
  final escapes = segments.any(
    (s) =>
        s == '..' || s.contains('/') || s.contains(r'\') || s.contains('\x00'),
  );
  if (escapes) return null;
  return File(p.joinAll([root, ...segments.where((s) => s != '.')]));
}

Future<void> _plain(HttpResponse response, int status, String body) {
  response
    ..statusCode = status
    ..headers.contentType = ContentType.text
    ..write(body);
  return response.close();
}

/// The `serve` command: serve a directory over HTTP for local development.
///
/// `serve` is a development server: it binds to loopback by default and must
/// never be used in the deployed stack.
final class ServeCommand extends Command<int> {
  /// Creates the command, writing to [_output].
  ///
  /// The server runs until [stop] completes; production leaves it `null` and
  /// the server runs until the process gets SIGINT.
  ServeCommand(this._output, {this._stop}) {
    argParser
      ..addOption(
        'port',
        defaultsTo: '$defaultServePort',
        help: 'The port to listen on; 0 picks a free one.',
      )
      ..addOption(
        'host',
        defaultsTo: defaultServeHost,
        help:
            'The address to bind. Pass a LAN address explicitly to expose '
            'the server beyond this machine.',
      )
      ..addFlag(
        'isolation',
        defaultsTo: true,
        help:
            'Send Cross-Origin-Opener-Policy and Cross-Origin-Embedder-Policy '
            'headers (use --no-isolation to leave them out).',
      );
  }

  final CliOutput _output;
  final Future<void>? _stop;

  @override
  String get name => 'serve';

  @override
  String get description =>
      'Serve a directory over HTTP for local development, with the headers '
      'the web build needs.';

  @override
  String get invocation =>
      '${runner!.executableName} serve <dir> [--port 8080] '
      '[--host 127.0.0.1] [--no-isolation]';

  /// Serves the directory until stopped, and returns the exit status.
  ///
  /// `serve` answers every path that is not a file, and `/font-fallback/*` in
  /// particular, with a plain 404, mirroring `deploy/Caddyfile`. A later
  /// `index.html` fallback must still answer `/font-fallback/*` with 404.
  ///
  /// Writes the address to listen on to standard output once bound. Returns
  /// [exitCheckFailed] with a message on standard error when the directory is
  /// missing or the address cannot be bound, and [exitSuccess] after a clean
  /// stop.
  @override
  Future<int> run() async {
    final results = argResults!;
    final [directory] = results.rest.length == 1
        ? results.rest
        : usageException('Pass exactly one directory to serve.');
    final portText = results.option('port')!;
    final port = switch (int.tryParse(portText)) {
      final int n when n >= 0 && n <= 65535 => n,
      _ => usageException('--port must be a number from 0 to 65535.'),
    };
    final host = results.option('host')!;
    if (!Directory(directory).existsSync()) {
      _output.err.writeln('$directory is not a directory');
      return exitCheckFailed;
    }
    final HttpServer server;
    try {
      server = await bindStaticServer(
        root: directory,
        host: host,
        port: port,
        isolation: results.flag('isolation'),
      );
    } on SocketException catch (e) {
      _output.err.writeln('Cannot listen on $host:$port: ${e.message}');
      return exitCheckFailed;
    }
    final shown = server.address.type == InternetAddressType.IPv6
        ? '[${server.address.address}]'
        : server.address.address;
    _output.out.writeln('Serving $directory at http://$shown:${server.port}/');
    await (_stop ?? ProcessSignal.sigint.watch().first);
    await server.close(force: true);
    return exitSuccess;
  }
}
