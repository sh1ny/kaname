import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/server/data/server_address.dart';

ServerTarget resolve({
  bool isWeb = false,
  bool isDebug = false,
  String define = '',
  String base = 'http://127.0.0.1:8080/app/page?x=1#frag',
}) => ServerAddress(
  isWeb: isWeb,
  isDebug: isDebug,
  define: define,
  base: Uri.parse(base),
).resolve();

void main() {
  test('web with base http://127.0.0.1:8080/ targets /api/ on that origin', () {
    final target = resolve(isWeb: true, base: 'http://127.0.0.1:8080/');
    expect(target, isA<ConfiguredServer>());
    expect(
      (target as ConfiguredServer).uri.toString(),
      'http://127.0.0.1:8080/api/',
    );
  });

  test("web target follows the base origin's host", () {
    final target = resolve(
      isWeb: true,
      base: 'https://kaname.example.org/some/route?q=1#f',
    );
    expect(
      (target as ConfiguredServer).uri.toString(),
      'https://kaname.example.org/api/',
    );
  });

  test('release web ignores the define', () {
    final target = resolve(
      isWeb: true,
      define: 'http://other.example:9999/',
      base: 'http://127.0.0.1:8080/',
    );
    expect(
      (target as ConfiguredServer).uri.toString(),
      'http://127.0.0.1:8080/api/',
    );
  });

  test('native define http://127.0.0.1:8080/ is the target', () {
    final target = resolve(define: 'http://127.0.0.1:8080/');
    expect(
      (target as ConfiguredServer).uri.toString(),
      'http://127.0.0.1:8080/',
    );
  });

  test('native without a define is NoServer', () {
    expect(resolve(), isA<NoServer>());
  });

  test('a missing trailing slash is added', () {
    final target = resolve(define: 'https://kaname.example.org/api');
    expect(
      (target as ConfiguredServer).uri.toString(),
      'https://kaname.example.org/api/',
    );
  });

  test('a define without scheme, host or http(s) is InvalidServer', () {
    for (final raw in ['localhost', 'ftp://host/', 'http://', '://x', 'a b:']) {
      final target = resolve(define: raw);
      expect(target, isA<InvalidServer>(), reason: raw);
      expect((target as InvalidServer).raw, raw);
    }
  });

  test('profile web ignores an invalid define too', () {
    expect(
      resolve(isWeb: true, define: 'localhost', base: 'http://h:1/'),
      isA<ConfiguredServer>(),
    );
  });

  test('debug web honours a non-empty define', () {
    final target = resolve(
      isWeb: true,
      isDebug: true,
      define: 'http://localhost:8080/',
      base: 'http://localhost:5000/',
    );
    expect(
      (target as ConfiguredServer).uri.toString(),
      'http://localhost:8080/',
    );
  });

  test('debug web without a define uses its own origin', () {
    final target = resolve(
      isWeb: true,
      isDebug: true,
      base: 'http://localhost:5000/',
    );
    expect(
      (target as ConfiguredServer).uri.toString(),
      'http://localhost:5000/api/',
    );
  });

  test('debug web with an invalid define is InvalidServer', () {
    expect(
      resolve(isWeb: true, isDebug: true, define: 'localhost'),
      isA<InvalidServer>(),
    );
  });
}
