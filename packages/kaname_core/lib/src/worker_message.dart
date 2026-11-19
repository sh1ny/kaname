/// Versioned messages that cross isolate boundaries.
///
/// A message is encoded as a plain `Map<String, Object?>` holding only
/// values an isolate port can send (strings, numbers, booleans, `null`,
/// lists and maps of these), with a `type` and a `version` entry next to the
/// payload. The receiving side decodes it through a [WorkerMessageCodec],
/// which rejects what it does not know with a [WorkerMessageException]
/// instead of guessing.
library;

/// A message exchanged between isolates.
///
/// Concrete messages declare their [type] and [version] and encode their
/// payload in [payloadToJson]. They are registered with a
/// [WorkerMessageCodec] by the isolate that receives them.
abstract base class WorkerMessage {
  /// Creates a message.
  const WorkerMessage();

  /// The key that holds [type] in an encoded message.
  static const String typeKey = 'type';

  /// The key that holds [version] in an encoded message.
  static const String versionKey = 'version';

  /// The stable name that identifies this kind of message.
  String get type;

  /// The version of this message's payload layout.
  ///
  /// Raise it whenever the payload changes in a way an older decoder cannot
  /// read.
  int get version;

  /// Encodes the payload as isolate-sendable values.
  ///
  /// The map must not use the [typeKey] or [versionKey] keys; the codec
  /// adds them.
  Map<String, Object?> payloadToJson();
}

/// Decodes a payload map into a message.
///
/// A decoder throws a [FormatException] or a [TypeError] when the payload
/// is invalid; [WorkerMessageCodec.decode] turns either into a
/// [MalformedWorkerMessage].
typedef WorkerMessageDecoder = WorkerMessage Function(
  Map<String, Object?> json,
);

/// Why a [WorkerMessageCodec] refused an encoded message.
sealed class WorkerMessageException implements Exception {
  /// Creates the exception.
  const WorkerMessageException();
}

/// The encoded message names a type no decoder is registered for.
final class UnknownWorkerMessageType extends WorkerMessageException {
  /// Creates the exception for [type].
  const UnknownWorkerMessageType(this.type);

  /// The unregistered type name.
  final String type;

  @override
  String toString() => 'UnknownWorkerMessageType: no decoder for "$type"';
}

/// The encoded message has a known type but a version no decoder handles.
final class UnsupportedWorkerMessageVersion extends WorkerMessageException {
  /// Creates the exception for [type] at [version].
  const UnsupportedWorkerMessageVersion(this.type, this.version);

  /// The message type.
  final String type;

  /// The version that has no decoder.
  final int version;

  @override
  String toString() =>
      'UnsupportedWorkerMessageVersion: "$type" has no decoder for '
      'version $version';
}

/// The encoded message lacks a valid `type` or `version`, or its payload
/// was refused by its decoder.
final class MalformedWorkerMessage extends WorkerMessageException {
  /// Creates the exception with a human-readable [reason].
  const MalformedWorkerMessage(this.reason);

  /// What is wrong with the message.
  final String reason;

  @override
  String toString() => 'MalformedWorkerMessage: $reason';
}

/// Encodes messages to maps and decodes maps back through registered
/// decoders.
///
/// Each isolate builds its own codec and registers the messages it expects
/// to receive, so a worker and the server may know different sets of
/// messages.
final class WorkerMessageCodec {
  final Map<(String, int), WorkerMessageDecoder> _decoders = {};
  final Set<String> _types = {};

  /// Registers [decoder] for messages of [type] at [version].
  ///
  /// Throws a [StateError] when that pair is already registered.
  void register({
    required String type,
    required int version,
    required WorkerMessageDecoder decoder,
  }) {
    if (_decoders.containsKey((type, version))) {
      throw StateError('Decoder for "$type" version $version exists.');
    }
    _decoders[(type, version)] = decoder;
    _types.add(type);
  }

  /// Encodes [message] as a map that can be sent through an isolate port.
  Map<String, Object?> encode(WorkerMessage message) => {
    ...message.payloadToJson(),
    WorkerMessage.typeKey: message.type,
    WorkerMessage.versionKey: message.version,
  };

  /// Decodes [json] into a message.
  ///
  /// Throws an [UnknownWorkerMessageType], an
  /// [UnsupportedWorkerMessageVersion] or a [MalformedWorkerMessage] when
  /// the map cannot be decoded.
  WorkerMessage decode(Map<String, Object?> json) {
    final type = switch (json[WorkerMessage.typeKey]) {
      final String type => type,
      _ => throw const MalformedWorkerMessage('type is missing or not text'),
    };
    if (!_types.contains(type)) throw UnknownWorkerMessageType(type);
    final version = switch (json[WorkerMessage.versionKey]) {
      final int version => version,
      _ => throw const MalformedWorkerMessage(
        'version is missing or not an integer',
      ),
    };
    final decoder = _decoders[(type, version)];
    if (decoder == null) throw UnsupportedWorkerMessageVersion(type, version);
    try {
      return decoder(json);
    } on FormatException catch (e) {
      throw MalformedWorkerMessage('$type: ${e.message}');
    } on TypeError catch (e) {
      throw MalformedWorkerMessage('$type: $e');
    }
  }
}
