import 'package:kaname_core/kaname_core.dart';
import 'package:test/test.dart';

/// A minimal concrete message used to exercise the codec.
final class PingMessage extends WorkerMessage {
  PingMessage(this.note);

  factory PingMessage.fromJson(Map<String, Object?> json) {
    return switch (json['note']) {
      final String note => PingMessage(note),
      _ => throw const FormatException('note must be a string'),
    };
  }

  static const String messageType = 'ping';

  final String note;

  @override
  String get type => messageType;

  @override
  int get version => 2;

  @override
  Map<String, Object?> payloadToJson() => {'note': note};
}

WorkerMessageCodec newCodec() => WorkerMessageCodec()
  ..register(
    type: PingMessage.messageType,
    version: 2,
    decoder: PingMessage.fromJson,
  );

void main() {
  group('WorkerMessageCodec', () {
    test('known message round-trips through a plain map', () {
      final codec = newCodec();
      final encoded = codec.encode(PingMessage('hi'));
      expect(encoded, {'type': 'ping', 'version': 2, 'note': 'hi'});
      expect(
        codec.decode(encoded),
        isA<PingMessage>().having((m) => m.note, 'note', 'hi'),
      );
    });

    test('unknown type or version is rejected with typed error', () {
      final codec = newCodec();
      expect(
        () => codec.decode({'type': 'nope', 'version': 1}),
        throwsA(
          isA<UnknownWorkerMessageType>().having((e) => e.type, 'type', 'nope'),
        ),
      );
      expect(
        () => codec.decode({'type': 'ping', 'version': 3, 'note': 'x'}),
        throwsA(
          isA<UnsupportedWorkerMessageVersion>()
              .having((e) => e.type, 'type', 'ping')
              .having((e) => e.version, 'version', 3),
        ),
      );
      expect(
        () => codec.decode({'type': 'ping', 'note': 'x'}),
        throwsA(isA<MalformedWorkerMessage>()),
      );
      expect(
        () => codec.decode({'type': 'ping', 'version': 2, 'note': 5}),
        throwsA(isA<MalformedWorkerMessage>()),
      );
    });
  });
}
