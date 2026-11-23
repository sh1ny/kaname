import 'dart:convert';
import 'dart:io';

import 'package:kaname_esi/kaname_esi.dart';
import 'package:test/test.dart';

import 'fixture_transport.dart';

/// The pinned snapshot, relative to the package root `dart test` runs in.
const String _snapshot = 'spec/openapi.json';

/// The methods of the pinned snapshot's path items.
const List<String> _methods = ['get', 'post', 'put', 'delete'];

/// One operation as the snapshot states it, read independently of the
/// generator.
typedef SnapshotOperation = ({String method, String template});

/// Each operation of the pinned snapshot, read with `dart:convert`, for the
/// generated coverage test (`test/generated/operations_test.dart`).
final class OperationCoverage {
  OperationCoverage._(this._operations);

  /// Reads the snapshot's operations.
  factory OperationCoverage.load() {
    final document = jsonDecode(File(_snapshot).readAsStringSync());
    if (document case {'paths': final Map<String, Object?> paths}) {
      return OperationCoverage._({
        for (final MapEntry(key: template, value: item) in paths.entries)
          if (item case final Map<String, Object?> item)
            for (final method in _methods)
              if (item[method] case {'operationId': final String id})
                id: (method: method.toUpperCase(), template: template),
      });
    }
    throw StateError('$_snapshot holds no paths object');
  }

  final Map<String, SnapshotOperation> _operations;

  /// Every operation of the snapshot, by operation id.
  Map<String, SnapshotOperation> get operations =>
      Map.unmodifiable(_operations);

  /// Every operation id of the snapshot.
  Iterable<String> get operationIds => _operations.keys;

  /// Calls [call] on a client whose transport records requests, and
  /// expects one request: the snapshot's method for [operationId] and its
  /// path template with each `{name}` replaced by the encoded value of
  /// [pathArguments].
  Future<void> expectRequest(
    String operationId,
    Future<EsiResult<Object?>> Function(EsiClient client) call,
    Map<String, Object> pathArguments,
  ) async {
    final operation = _operations[operationId];
    if (operation == null) fail('$operationId is not in $_snapshot');
    final transport = FixtureTransport.respond(204);
    final result = await call(EsiClient(transport));
    if (result case EsiInvalidRequest(:final parameter, :final reason)) {
      fail('$operationId refused its placeholder $parameter: $reason');
    }
    final path = operation.template.replaceAllMapped(
      RegExp(r'\{([^}]+)\}'),
      (match) => switch (pathArguments[match[1]!]) {
        final Object value => Uri.encodeComponent('$value'),
        null => fail('$operationId has no argument for ${match[0]}'),
      },
    );
    expect(transport.requests, hasLength(1));
    final request = transport.requests.single;
    expect(request.operationId, operationId);
    expect(request.method.wire, operation.method);
    expect(request.target.path, path);
  }
}
