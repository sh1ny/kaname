import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/command_runner.dart';
import 'package:kaname_tools/kaname_tools.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/in_memory_file_system.dart';

/// A raw response: status code, lower-cased headers and body text.
typedef RawResponse = ({int status, Map<String, String> headers, String body});

/// Sends [requestLine] over a bare socket, so nothing normalises the path.
Future<RawResponse> rawGet(HttpServer server, String target) async {
  final socket = await Socket.connect(
    InternetAddress.loopbackIPv4,
    server.port,
  );
  socket.write('GET $target HTTP/1.0\r\nHost: localhost\r\n\r\n');
  await socket.flush();
  final bytes = BytesBuilder();
  await socket.forEach(bytes.add);
  socket.destroy();
  final text = latin1.decode(bytes.takeBytes());
  final split = text.indexOf('\r\n\r\n');
  final head = text.substring(0, split).split('\r\n');
  final status = int.parse(head.first.split(' ')[1]);
  final headers = <String, String>{
    for (final line in head.skip(1))
      line.substring(0, line.indexOf(':')).toLowerCase(): line
          .substring(line.indexOf(':') + 1)
          .trim(),
  };
  return (status: status, headers: headers, body: text.substring(split + 4));
}

void main() {
  late Directory sandbox;
  late Directory root;
  final servers = <HttpServer>[];

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('kaname_serve_test');
    root = Directory(p.join(sandbox.path, 'root'))..createSync();
    File(p.join(root.path, 'index.html')).writeAsStringSync('<h1>home</h1>');
    File(p.join(root.path, 'main.dart.mjs')).writeAsStringSync('export {};');
    File(p.join(root.path, 'app.js')).writeAsStringSync('1;');
    File(p.join(root.path, 'engine.wasm'))
        .writeAsBytesSync([0, 0x61, 0x73, 0x6d]);
    File(p.join(root.path, 'data.json')).writeAsStringSync('{}');
    File(p.join(root.path, 'style.css')).writeAsStringSync('a{}');
    File(p.join(root.path, 'logo.png')).writeAsBytesSync([1]);
    File(p.join(root.path, 'font.ttf')).writeAsBytesSync([1]);
    File(p.join(root.path, 'font.otf')).writeAsBytesSync([1]);
    File(p.join(root.path, 'icon.svg')).writeAsStringSync('<svg/>');
    File(p.join(root.path, 'favicon.ico')).writeAsBytesSync([1]);
    File(p.join(root.path, 'blob.xyz')).writeAsBytesSync([1]);
    Directory(p.join(root.path, 'sub')).createSync();
    File(p.join(sandbox.path, 'secret.txt')).writeAsStringSync('TOP-SECRET');
  });

  tearDown(() async {
    for (final server in servers) {
      await server.close(force: true);
    }
    servers.clear();
    sandbox.deleteSync(recursive: true);
  });

  Future<HttpServer> start({bool isolation = true}) async {
    final server = await bindStaticServer(
      root: root.path,
      port: 0,
      isolation: isolation,
    );
    servers.add(server);
    return server;
  }

  Future<
    ({int status, ContentType? type, Map<String, String> headers, String body})
  >
  fetch(HttpServer server, String path, {String method = 'GET'}) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(
        method,
        Uri.parse('http://127.0.0.1:${server.port}$path'),
      );
      final response = await request.close();
      final headers = <String, String>{};
      response.headers.forEach(
        (name, values) => headers[name] = values.join(','),
      );
      final body = await utf8.decodeStream(response);
      return (
        status: response.statusCode,
        type: response.headers.contentType,
        headers: headers,
        body: body,
      );
    } finally {
      client.close(force: true);
    }
  }

  test('serves files with their content types', () async {
    final server = await start();
    const expected = {
      '/engine.wasm': 'application/wasm',
      '/main.dart.mjs': 'text/javascript',
      '/app.js': 'text/javascript',
      '/index.html': 'text/html',
      '/': 'text/html',
      '/data.json': 'application/json',
      '/style.css': 'text/css',
      '/logo.png': 'image/png',
      '/font.ttf': 'font/ttf',
      '/font.otf': 'font/otf',
      '/icon.svg': 'image/svg+xml',
      '/favicon.ico': 'image/x-icon',
      '/blob.xyz': 'application/octet-stream',
    };
    for (final MapEntry(:key, :value) in expected.entries) {
      final got = await fetch(server, key);
      expect(got.status, 200, reason: key);
      expect(got.type?.mimeType, value, reason: key);
    }
    expect((await fetch(server, '/')).body, '<h1>home</h1>');
    final head = await fetch(server, '/app.js', method: 'HEAD');
    expect(head.status, 200);
    expect(head.body, isEmpty);
    expect((await fetch(server, '/app.js', method: 'POST')).status, 405);
  });

  test('isolation headers follow the flag', () async {
    final isolated = await start();
    final on = await fetch(isolated, '/index.html');
    expect(on.headers['cross-origin-opener-policy'], 'same-origin');
    expect(on.headers['cross-origin-embedder-policy'], 'require-corp');

    final open = await start(isolation: false);
    final off = await fetch(open, '/index.html');
    expect(off.headers, isNot(contains('cross-origin-opener-policy')));
    expect(off.headers, isNot(contains('cross-origin-embedder-policy')));
  });

  test('non-files and font fallback answer 404', () async {
    final server = await start();
    for (final path in [
      '/missing',
      '/font-fallback/x',
      '/font-fallback/roboto/v30/x.woff2',
      '/sub',
      '/sub/',
      '/sub/index.html',
    ]) {
      final got = await fetch(server, path);
      expect(got.status, 404, reason: path);
      expect(got.body, isNot(contains('home')), reason: path);
    }
  });

  test('a file that cannot be read answers 404, not a hang', () async {
    // Stands in for a file removed between the existence check and the
    // read: it exists, but opening it fails.
    final locked = File(p.join(root.path, 'locked.js'))
      ..writeAsStringSync('1;');
    Process.runSync('chmod', ['000', locked.path]);
    addTearDown(() => Process.runSync('chmod', ['644', locked.path]));
    final server = await start();
    final got = await fetch(
      server,
      '/locked.js',
    ).timeout(const Duration(seconds: 5));
    expect(got.status, 404);
    expect(got.body, 'Not Found');
  }, testOn: 'posix');

  test('paths outside the root are refused', () async {
    final server = await start();
    for (final target in [
      '/../secret.txt',
      '/%2e%2e/secret.txt',
      '/%2E%2E/secret.txt',
      '/sub/../../secret.txt',
      '/..%2Fsecret.txt',
      '/%2e%2e%2fsecret.txt',
      '/..%5Csecret.txt',
      '/%2Fetc/passwd',
      '//etc/passwd',
    ]) {
      final got = await rawGet(server, target);
      expect(got.status, anyOf(400, 403, 404), reason: target);
      expect(got.body, isNot(contains('TOP-SECRET')), reason: target);
    }
    Link(p.join(root.path, 'escape.txt'))
        .createSync(p.join(sandbox.path, 'secret.txt'));
    final link = await rawGet(server, '/escape.txt');
    expect(link.status, 403);
    expect(link.body, isNot(contains('TOP-SECRET')));
  });

  group('binds loopback and reports bind failure', () {
    Future<
      ({
        Future<int?> done,
        Completer<void> stop,
        StringBuffer out,
        StringBuffer err,
      })
    >
    launch(List<String> args) async {
      final out = StringBuffer();
      final err = StringBuffer();
      final stop = Completer<void>();
      final runner = CommandRunner<int>('kaname_tools', 'test')
        ..addCommand(
          ServeCommand(
            CliOutput(out: out, err: err),
            stop: stop.future,
          ),
        );
      final done = runner.run(['serve', ...args]);
      return (done: done, stop: stop, out: out, err: err);
    }

    test('listens on loopback by default', () async {
      final run = await launch([root.path, '--port', '0']);
      final url = RegExp(r'http://([\d.]+):(\d+)/');
      for (var i = 0; i < 100 && !url.hasMatch(run.out.toString()); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final match = url.firstMatch(run.out.toString());
      expect(match, isNotNull, reason: 'out: ${run.out} err: ${run.err}');
      expect(InternetAddress(match!.group(1)!).isLoopback, isTrue);
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(match.group(0)!));
      final response = await request.close();
      expect(response.statusCode, 200);
      await response.drain<void>();
      client.close(force: true);
      run.stop.complete();
      expect(await run.done, 0);
    });

    test('a port already in use exits 1 with a message', () async {
      final taken = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(taken.close);
      final run = await launch([root.path, '--port', '${taken.port}']);
      expect(await run.done, 1);
      expect(run.err.toString(), contains('${taken.port}'));
    });

    test('a host that cannot be bound exits 1 with a message', () async {
      final run = await launch([
        root.path,
        '--port',
        '0',
        '--host',
        '203.0.113.1',
      ]);
      expect(await run.done, 1);
      expect(run.err.toString(), isNotEmpty);
    });

    test('is registered with the command runner', () {
      final runner = buildRunner(
        InMemoryFileSystem(),
        CliOutput(out: StringBuffer(), err: StringBuffer()),
      );
      expect(runner.commands, contains('serve'));
    });
  });
}
