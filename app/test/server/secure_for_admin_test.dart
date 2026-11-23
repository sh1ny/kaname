import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/server/data/secure_for_admin.dart';

void main() {
  test('isSecureForAdmin accepts https and loopback http and refuses plain '
      'http to another host', () {
    for (final url in [
      'https://corp.example/kaname/',
      'http://localhost:8080/',
      'http://127.0.0.1:8080/',
      'http://[::1]:8080/',
    ]) {
      expect(isSecureForAdmin(Uri.parse(url)), isTrue, reason: url);
    }
    for (final url in [
      'http://corp.example/',
      'http://localhost.corp.example/',
      'http://127.0.0.2/',
      'http://localhost@corp.example/',
      'https:relative-path',
      'file://localhost/workspace',
    ]) {
      expect(isSecureForAdmin(Uri.parse(url)), isFalse, reason: url);
    }
  });
}
