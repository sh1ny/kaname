import 'dart:io';

import 'package:kaname_tools/kaname_tools.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The self-host stack's Compose file, relative to the repository root.
const _composeFile = 'deploy/compose.yaml';

/// The Caddy configuration, relative to the repository root.
const _caddyfile = 'deploy/Caddyfile';

/// The environment variables that hold the stack's secrets.
const _secrets = {
  'POSTGRES_PASSWORD',
  'REDIS_PASSWORD',
  'SERVERPOD_SERVICE_SECRET',
};

const _optionalServer = {
  'KANAME_ORG_TREE': '',
  'KANAME_ESI_SSO_CLIENT_ID': '',
  'KANAME_ESI_SSO_CLIENT_SECRET': '',
  'KANAME_ESI_SSO_REDIRECT_URI': '',
  'KANAME_ESI_SSO_ALLOW_LOCAL_HTTP': 'false',
  'KANAME_ESI_SSO_ADMIN_CHARACTERS': '',
  'KANAME_ESI_SCOPE_POLICY': '',
  'KANAME_ESI_VAULT_KEY': '',
};

String _optionalReference(String name, String fallback) =>
    '\${$name:-$fallback}';

/// One entry of a service's `depends_on`.
typedef _Dependency = ({String service, String condition});

/// The parts of a Compose service the stack's rules look at, read from the
/// parsed YAML with every field checked.
final class _Service {
  _Service({
    required this.name,
    required this.dependsOn,
    required this.hasHealthcheck,
    required this.ports,
    required this.volumes,
    required this.platform,
    required this.image,
    required this.command,
  });

  /// Reads [name] from [raw], failing the test on a field of the wrong shape.
  factory _Service.parse(String name, Object? raw) {
    if (raw is! YamlMap) fail('service $name is not a mapping');
    return _Service(
      name: name,
      dependsOn: _dependencies(name, raw['depends_on']),
      hasHealthcheck: raw['healthcheck'] is YamlMap,
      ports: _strings(name, 'ports', raw['ports']),
      volumes: _strings(name, 'volumes', raw['volumes']),
      platform: raw['platform'] is String ? raw['platform'] as String : null,
      image: raw['image'] is String ? raw['image'] as String : null,
      command: raw['command'] == null
          ? const []
          : _strings(name, 'command', raw['command']),
    );
  }

  final String name;
  final List<_Dependency> dependsOn;
  final bool hasHealthcheck;
  final List<String> ports;
  final List<String> volumes;
  final String? platform;
  final String? image;
  final List<String> command;

  /// The condition under which this service waits for [service], if it does.
  String? conditionOn(String service) {
    for (final dependency in dependsOn) {
      if (dependency.service == service) return dependency.condition;
    }
    return null;
  }
}

/// `depends_on` in its long form: a mapping from service to a condition.
List<_Dependency> _dependencies(String service, Object? raw) => switch (raw) {
  null => const [],
  YamlMap() => [
    for (final MapEntry(:key, :value) in raw.entries)
      (
        service: key as String,
        condition: switch (value) {
          YamlMap() when value['condition'] is String =>
            value['condition'] as String,
          _ => fail('$service: depends_on $key has no condition'),
        },
      ),
  ],
  _ => fail('$service: depends_on must use the long form (with conditions)'),
};

/// A list of strings, or an empty list when the field is absent.
List<String> _strings(String service, String field, Object? raw) =>
    switch (raw) {
      null => const [],
      YamlList() => [
        for (final item in raw)
          item is String ? item : fail('$service: $field entry is not text'),
      ],
      _ => fail('$service: $field is not a list'),
    };

/// The repository root, or fails the test.
String _root() {
  final root = RealFileSystem.locate(Directory.current.path)?.root;
  if (root == null) fail('no workspace root above the test cwd');
  return root;
}

/// The raw text of [_composeFile], or fails the test.
String _composeText() {
  final file = File(p.join(_root(), _composeFile));
  if (!file.existsSync()) fail('$_composeFile does not exist');
  return file.readAsStringSync();
}

/// The parsed Compose document.
YamlMap _compose() {
  final document = loadYaml(_composeText());
  if (document is! YamlMap) fail('$_composeFile is not a mapping');
  return document;
}

/// Every service of the Compose file by name.
Map<String, _Service> _services() {
  final raw = _compose()['services'];
  if (raw is! YamlMap) fail('$_composeFile has no services mapping');
  return {
    for (final MapEntry(:key, :value) in raw.entries)
      key as String: _Service.parse(key, value),
  };
}

/// The names of the top-level named volumes.
Set<String> _namedVolumes() {
  final raw = _compose()['volumes'];
  if (raw is! YamlMap) fail('$_composeFile declares no named volumes');
  return {for (final key in raw.keys) key as String};
}

/// An IPv4 address as a 32-bit number, or fails the test.
int _ipv4(String text, String what) {
  final parts = text.split('.');
  if (parts.length != 4) fail('$what is not an IPv4 address: $text');
  var value = 0;
  for (final part in parts) {
    final octet = int.tryParse(part);
    if (octet == null || octet < 0 || octet > 255) {
      fail('$what is not an IPv4 address: $text');
    }
    value = value << 8 | octet;
  }
  return value;
}

/// An IPv4 CIDR range as its first and last address, or fails the test.
({int first, int last}) _range(String text, String what) {
  final slash = text.indexOf('/');
  if (slash < 0) fail('$what is not a CIDR range: $text');
  final prefix = int.tryParse(text.substring(slash + 1));
  if (prefix == null || prefix < 0 || prefix > 32) {
    fail('$what has no valid prefix: $text');
  }
  final size = 1 << (32 - prefix);
  final first =
      _ipv4(text.substring(0, slash), what) & ~(size - 1) & 0xffffffff;
  return (first: first, last: first + size - 1);
}

/// Reads the field at [path] under [root] as text, or fails the test.
String _text(Object? root, List<Object> path) {
  Object? node = root;
  for (final key in path) {
    node = switch ((node, key)) {
      (final YamlMap map, final String name) => map[name],
      (final YamlList list, final int index) when index < list.length =>
        list[index],
      _ => null,
    };
  }
  if (node is! String) fail('$_composeFile: ${path.join('.')} is not text');
  return node;
}

void main() {
  group('deploy/compose.yaml', () {
    test('holds four services and a migrate step with named volumes', () {
      final services = _services();
      expect(services.keys, {
        'postgres',
        'redis',
        'server',
        'caddy',
        'migrate',
      });

      final volumes = _namedVolumes();
      expect(volumes, containsAll(['pgdata', 'redisdata']));
      for (final (service, volume) in [
        ('postgres', 'pgdata'),
        ('redis', 'redisdata'),
      ]) {
        expect(
          services[service]!.volumes.any((v) => v.startsWith('$volume:')),
          isTrue,
          reason: '$service stores its data in the named volume $volume',
        );
      }
    });

    test('server and migrate run the same linux/amd64 image in production '
        'mode', () {
      final services = _services();
      final server = services['server']!;
      final migrate = services['migrate']!;
      for (final service in [server, migrate]) {
        expect(service.platform, 'linux/amd64', reason: service.name);
        expect(service.image, isNotNull, reason: '${service.name} image');
        expect(service.command, containsAllInOrder(['--mode', 'production']));
      }
      expect(migrate.image, server.image);
      expect(
        migrate.command,
        containsAll(['--role', 'maintenance', '--apply-migrations']),
      );
      expect(server.command, isNot(contains('--apply-migrations')));
    });

    test('migrate depends on postgres and redis healthy and both have '
        'healthchecks', () {
      final services = _services();
      final migrate = services['migrate']!;
      expect(migrate.conditionOn('postgres'), 'service_healthy');
      expect(migrate.conditionOn('redis'), 'service_healthy');
      expect(services['postgres']!.hasHealthcheck, isTrue);
      expect(services['redis']!.hasHealthcheck, isTrue);
    });

    test('server depends on migrate completed successfully', () {
      final server = _services()['server']!;
      expect(server.conditionOn('migrate'), 'service_completed_successfully');
    });

    test('only caddy publishes a port, bound to 127.0.0.1', () {
      final services = _services();
      for (final service in services.values) {
        if (service.name != 'caddy') {
          expect(
            service.ports,
            isEmpty,
            reason: '${service.name} must not publish a port',
          );
        }
      }
      final ports = services['caddy']!.ports;
      expect(ports, isNotEmpty);
      for (final port in ports) {
        expect(
          port,
          startsWith('127.0.0.1:'),
          reason: 'caddy publishes on the loopback address only: $port',
        );
      }
    });

    test('every required secret uses the required-variable form', () {
      // `$$` escapes a literal dollar in Compose, so it is not a variable.
      final text = _composeText().replaceAll(r'$$', '');
      final references = RegExp(r'\$(\{[^}]*\}|\w+)').allMatches(text).toList();
      expect(references, isNotEmpty);
      final required = RegExp(r'^\$\{([A-Z][A-Z0-9_]*):\?[^}]+\}$');
      final used = <String>{};
      for (final reference in references) {
        final variable = reference.group(0)!;
        if (_optionalServer.entries.any(
          (item) => variable == _optionalReference(item.key, item.value),
        )) {
          continue;
        }
        final match = required.firstMatch(variable);
        expect(
          match,
          isNotNull,
          reason:
              '$variable must be ${r'${NAME:?message}'}, so a '
              'missing value stops Compose',
        );
        used.add(match!.group(1)!);
      }
      expect(used, containsAll(_secrets));
    });

    test('optional settings reach only the running server', () {
      final services = _compose()['services'] as YamlMap;
      for (final MapEntry(key: name, value: raw) in services.entries) {
        final service = raw as YamlMap;
        final environment = service['environment'] as YamlMap?;
        expect(environment?['SERVERPOD_PASSWORD_adminKey'], isNull);
        for (final MapEntry(:key, :value) in _optionalServer.entries) {
          expect(
            environment?[key],
            name == 'server' ? _optionalReference(key, value) : null,
            reason: '$name environment',
          );
        }
      }
      expect(_composeText(), isNot(contains('KANAME_ADMIN_KEY')));
    });

    test('the secrets reach the server through SERVERPOD_PASSWORD_*', () {
      final text = _composeText();
      for (final (key, variable) in [
        ('SERVERPOD_PASSWORD_database', 'POSTGRES_PASSWORD'),
        ('SERVERPOD_PASSWORD_redis', 'REDIS_PASSWORD'),
        ('SERVERPOD_PASSWORD_serviceSecret', 'SERVERPOD_SERVICE_SECRET'),
      ]) {
        expect(
          RegExp('$key:\\s*\\\$\\{$variable:\\?').hasMatch(text),
          isTrue,
          reason: '$key is read from $variable',
        );
      }
    });
    // Scenario: Configuration check (self-host-stack → The stack's server
    // trusts only Caddy as proxy). C4.
    test("pinned subnet, dynamic range, Caddy's fixed address outside it, and "
        "trusted proxies equal to Caddy's address", () {
      final compose = _compose();
      final ipam = ['networks', 'default', 'ipam', 'config', 0];
      final subnet = _range(_text(compose, [...ipam, 'subnet']), 'subnet');
      final pool = _range(_text(compose, [...ipam, 'ip_range']), 'ip_range');
      final gateway = _ipv4(_text(compose, [...ipam, 'gateway']), 'gateway');
      final caddyText = _text(compose, [
        'services',
        'caddy',
        'networks',
        'default',
        'ipv4_address',
      ]);
      final caddy = _ipv4(caddyText, "Caddy's address");

      bool inside(int address, ({int first, int last}) range) =>
          address >= range.first && address <= range.last;

      expect(pool.first, greaterThanOrEqualTo(subnet.first));
      expect(
        pool.last,
        lessThanOrEqualTo(subnet.last),
        reason: 'the dynamic range lies inside the subnet',
      );
      expect(inside(caddy, subnet), isTrue, reason: 'Caddy is in the subnet');
      expect(
        inside(caddy, pool),
        isFalse,
        reason: "no container can be given Caddy's address",
      );
      expect(caddy, isNot(subnet.first), reason: 'not the network address');
      expect(caddy, isNot(subnet.last), reason: 'not the broadcast address');
      expect(caddy, isNot(gateway), reason: "not the gateway's address");
      expect(inside(gateway, subnet), isTrue);

      expect(
        _text(compose, [
          'services',
          'server',
          'environment',
          'KANAME_TRUSTED_PROXIES',
        ]),
        caddyText,
        reason: 'the server trusts exactly Caddy, never the subnet',
      );
      // Every other service joins the network without a fixed address.
      final services = compose['services'] as YamlMap;
      for (final MapEntry(key: name, value: raw) in services.entries) {
        if (name == 'caddy') continue;
        expect(
          (raw as YamlMap)['networks'],
          isNull,
          reason: '$name takes a dynamic address on the default network',
        );
      }
    });
  });

  group('deploy/Caddyfile', () {
    String text() {
      final file = File(p.join(_root(), _caddyfile));
      if (!file.existsSync()) fail('$_caddyfile does not exist');
      return file.readAsStringSync();
    }

    /// The Caddyfile without its comments.
    String code() => text()
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('#'))
        .join('\n');

    test('closes stalled client writes with an idle timeout that leaves the '
        'announcement WebSockets alone', () {
      final servers = RegExp(r'servers\s*\{\s*timeouts\s*\{([^}]*)\}')
          .firstMatch(code());
      expect(servers, isNotNull, reason: 'a global servers { timeouts { } }');
      final timeouts = servers!.group(1)!;

      final idle = RegExp(r'write_idle\s+(\d+)(s|m)\b').firstMatch(timeouts);
      expect(
        idle,
        isNotNull,
        reason:
            'write_idle sets how long a stalled '
            'write may last',
      );
      final seconds =
          int.parse(idle!.group(1)!) * (idle.group(2) == 'm' ? 60 : 1);
      // Within the bundle route's 2-minute deadline, so the proxy frees the
      // bytes a stalled client pins no later than the route frees its place.
      expect(seconds, inInclusiveRange(1, 120));
      // A hard limit on the whole response (`write`), or a limit on idle
      // connections shorter than the announcement stream's 30 minutes, would
      // cut the WebSockets or slow downloads.
      expect(
        RegExp(r'^\s*write\s', multiLine: true).hasMatch(timeouts),
        isFalse,
        reason: 'no hard write limit',
      );
    });

    test('still proxies /api/ to the server with the prefix removed', () {
      expect(
        RegExp(r'handle_path\s+/api/\*\s*\{\s*reverse_proxy\s+server:8080\s*\}')
            .hasMatch(code()),
        isTrue,
      );
    });

    // The generated client opens its WebSocket at <origin>/v1/websocket
    // whatever path the app configures, so the web app's streams need this
    // route; without it they get the single-page-app fallback (round 21).
    test("the generated client's WebSocket path reaches the server", () {
      final caddy = code();
      final route = RegExp(
        r'handle\s+/v1/websocket\s*\{\s*reverse_proxy\s+server:8080\s*\}',
      ).firstMatch(caddy);
      expect(route, isNotNull, reason: '/v1/websocket must reach the server');
      final fallback = caddy.indexOf('try_files');
      expect(fallback, greaterThan(-1));
      expect(
        route!.start,
        lessThan(caddy.lastIndexOf('handle {', fallback)),
        reason: 'the route must come before the single-page-app fallback',
      );
    });
  });
}
