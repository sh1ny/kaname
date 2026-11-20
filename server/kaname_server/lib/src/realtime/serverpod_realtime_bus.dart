import 'dart:async';

import 'package:kaname_core/kaname_core.dart';
import 'package:serverpod/serverpod.dart';

/// What [ServerpodRealtimeBus] posts on a topic's channel: the payload with
/// the topic's name and version.
///
/// It is a [SerializableModel] only so Serverpod's message system accepts it.
/// Local delivery passes the instance as it is and never serialises it, so
/// the payload can be any object; delivery through Redis (ADR 0014, C21)
/// would need a serialisable payload, and [toJson] says so.
final class BusEnvelope implements SerializableModel {
  /// Wraps [payload] as a message of the topic called [topic] at [version].
  const BusEnvelope({
    required this.topic,
    required this.version,
    required this.payload,
  });

  /// The name of the topic the message belongs to.
  final String topic;

  /// The topic version the sender published at.
  final int version;

  /// The typed message.
  final Object? payload;

  /// Always throws: the envelope is only delivered locally.
  @override
  Map<String, Object?> toJson() => throw UnsupportedError(
    'BusEnvelope is delivered locally and has no JSON form',
  );
}

/// The server's [RealtimeBus], on Serverpod's message system with local
/// scope.
///
/// **Only the main isolate publishes (C10).** The bus lives in the main
/// isolate and posts through the pod's internal session; a worker isolate
/// never holds a bus or a session. A change a worker makes reaches the bus as
/// a typed worker reply (ADR 0009) that the main isolate turns into a message
/// and publishes.
///
/// A message is posted as a [BusEnvelope] on the channel named like its
/// topic, with `MessageScope.local`: it reaches every subscriber in this
/// server process synchronously into that subscriber's stream, and no other
/// server instance (ADR 0014, C21). Listeners are added through the session
/// given to the constructor, which should be `pod.internalSession`, because
/// that session stays open until shutdown. Each subscribed stream owns one
/// listener and removes it when its subscription is cancelled.
///
/// A message whose envelope names another topic, a version the receiving
/// [Topic] does not know, or a payload that is not the topic's type is logged
/// with its topic and version and dropped; later messages are still
/// delivered. Publishing while nothing subscribes drops the message and does
/// not fail.
final class ServerpodRealtimeBus implements RealtimeBus {
  /// Creates a bus that posts and listens through [session].
  ///
  /// [log] receives each drop's description; it defaults to a warning in
  /// [session]'s log.
  ServerpodRealtimeBus(this._session, {void Function(String message)? log})
    : _log =
          log ?? ((message) => _session.log(message, level: LogLevel.warning));

  final Session _session;
  final void Function(String message) _log;

  @override
  Future<void> publish<T>(Topic<T> topic, T message) async {
    await _session.messages.postMessage(
      topic.name,
      BusEnvelope(topic: topic.name, version: topic.version, payload: message),
      scope: MessageScope.local,
    );
  }

  @override
  Stream<T> subscribe<T>(Topic<T> topic) {
    late final StreamController<T> controller;
    void listener(SerializableModel message) {
      switch (message) {
        case BusEnvelope(
              topic: final name,
              version: final version,
              payload: final T payload,
            )
            when name == topic.name && version == topic.version:
          controller.add(payload);
        case BusEnvelope(topic: final name, version: final version):
          _log(
            'Realtime bus dropped a message on topic "${topic.name}": '
            'it names topic "$name" version $version, expected '
            '"${topic.name}" version ${topic.version} carrying $T.',
          );
        default:
          _log(
            'Realtime bus dropped a message on topic "${topic.name}" that '
            'is not a bus envelope: ${message.runtimeType}.',
          );
      }
    }

    controller = StreamController<T>(
      onListen: () => _session.messages.addListener(topic.name, listener),
      onCancel: () => _session.messages.removeListener(topic.name, listener),
    );
    return controller.stream;
  }
}
