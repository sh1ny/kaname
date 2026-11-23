import 'dart:convert';
import 'dart:io';

import 'package:kaname_esi/kaname_esi.dart';

import 'fixture_transport.dart';

/// Where the exchange files live, relative to the package root
/// `dart test` runs in.
const String exchangesDirectory = 'test/exchanges';

/// The three exchange sets (design D6).
const List<String> exchangeSets = ['conforming', 'negative', 'forward'];

/// One Kaname-written exchange: the operation it answers, the constructs
/// it covers and the response the transport gives back. It holds no data
/// copied from ESI (C7).
final class Exchange {
  Exchange._({
    required this.name,
    required this.operation,
    required this.constructs,
    required this.response,
  });

  /// Reads `test/exchanges/<name>.json`, where [name] is
  /// `<set>/<file stem>`.
  factory Exchange.load(String name) {
    final path = '$exchangesDirectory/$name.json';
    final document = jsonDecode(File(path).readAsStringSync());
    if (document case {
      'operation': final String operation,
      'constructs': final List<Object?> constructs,
      'response':
          {'status': final int status} && final Map<String, Object?> response,
    }) {
      final headers = switch (response['headers']) {
        null => const <String, String>{},
        final Map<String, Object?> map => {
          for (final MapEntry(:key, :value) in map.entries) key: '$value',
        },
        final other => throw FormatException('$path: headers is $other'),
      };
      final body = switch (response) {
        {'text': final String text} => utf8.encode(text),
        {'body': final Object? json} => utf8.encode(jsonEncode(json)),
        _ => null,
      };
      return Exchange._(
        name: name,
        operation: operation,
        constructs: [for (final c in constructs) '$c'],
        response: EsiResponse(status: status, headers: headers, body: body),
      );
    }
    throw FormatException('$path is not an exchange file');
  }

  /// Every exchange file, by name, sorted.
  static List<String> all() => [
    for (final set in exchangeSets)
      for (final entity in Directory('$exchangesDirectory/$set').listSync())
        if (entity is File && entity.path.endsWith('.json'))
          '$set/${entity.uri.pathSegments.last.replaceFirst('.json', '')}',
  ]..sort();

  /// `<set>/<file stem>`.
  final String name;

  /// The operation id the exchange answers.
  final String operation;

  /// The constructs of the contract coverage list it covers.
  final List<String> constructs;

  /// What the transport answers.
  final EsiResponse response;

  /// A transport answering every request with [response].
  FixtureTransport transport() => FixtureTransport(response);
}
