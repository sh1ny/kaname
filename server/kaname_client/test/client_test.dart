import 'package:kaname_client/kaname_client.dart';
import 'package:test/test.dart';

void main() {
  test('the generated client is created for a host without calling it', () {
    final client = Client('http://localhost:8080/');

    expect(client.host, 'http://localhost:8080/');
    client.close();
  });
}
