/// The realtime bus that carries server events to subscribers (ADR 0008,
/// ADR 0014).
library;

import 'dart:async';

/// Whether a topic's messages may reach every client or need the privacy
/// scope first.
enum TopicVisibility {
  /// The topic carries only public, non-character data, and its delivery
  /// scope passes every message.
  public,

  /// The topic carries data that only the privacy scope may release. A client
  /// stream is refused until that scope exists (ADR 0006).
  scoped,
}

/// A named, versioned channel on the [RealtimeBus] whose messages are [T].
final class Topic<T> {
  /// Declares the topic called [name] at payload layout [version].
  ///
  /// Raise [version] whenever [T] changes in a way an older receiver cannot
  /// read. A receiver drops a message whose version it does not know.
  const Topic({
    required this.name,
    required this.version,
    required this.visibility,
  });

  /// The stable name that identifies the topic.
  final String name;

  /// The version of the layout of [T].
  final int version;

  /// Whether the topic is [TopicVisibility.public] or
  /// [TopicVisibility.scoped].
  final TopicVisibility visibility;

  @override
  String toString() => 'Topic($name v$version, ${visibility.name})';
}

/// Carries typed messages from publishers to subscribers.
abstract interface class RealtimeBus {
  /// Delivers [message] to every current subscriber of [topic].
  ///
  /// Publishing while nothing subscribes drops the message and does not fail.
  Future<void> publish<T>(Topic<T> topic, T message);

  /// Listens to [topic].
  ///
  /// The returned stream sends only messages published on [topic], each once,
  /// as [T]. Cancelling its subscription removes the listener.
  Stream<T> subscribe<T>(Topic<T> topic);
}

/// Decides which messages of a topic may be delivered to a client stream.
abstract interface class DeliveryScope<T> {
  /// Whether [message] may be delivered to the client stream.
  bool passes(T message);
}

/// The delivery scope of a [TopicVisibility.public] topic: it passes every
/// message.
final class PublicDeliveryScope<T> implements DeliveryScope<T> {
  /// Creates the scope.
  const PublicDeliveryScope();

  @override
  bool passes(T message) => true;
}

/// The outcome of asking for a topic's delivery scope.
sealed class DeliveryScopeResolution<T> {
  const DeliveryScopeResolution();
}

/// A client stream may be served; every delivery passes [scope].
final class DeliveryScopeAccepted<T> extends DeliveryScopeResolution<T> {
  /// Creates the outcome.
  const DeliveryScopeAccepted(this.scope);

  /// The scope each delivery must pass.
  final DeliveryScope<T> scope;
}

/// A client stream must not be served.
final class DeliveryScopeRefused<T> extends DeliveryScopeResolution<T> {
  /// Creates the outcome with [reason].
  const DeliveryScopeRefused(this.reason);

  /// Why the subscription is refused.
  final String reason;
}

/// The reason a client stream is refused a scoped topic.
const String scopedTopicRefusal = 'topic needs the privacy scope';

/// Resolves the delivery scope a client stream of [topic] must use.
///
/// A public topic resolves to a scope that passes every message. A scoped
/// topic is refused with [scopedTopicRefusal] until the privacy scope exists
/// (ADR 0006); no topic bypasses the scope.
DeliveryScopeResolution<T> resolveDeliveryScope<T>(Topic<T> topic) =>
    switch (topic.visibility) {
      TopicVisibility.public => DeliveryScopeAccepted(PublicDeliveryScope<T>()),
      TopicVisibility.scoped => const DeliveryScopeRefused(scopedTopicRefusal),
    };

/// A [RealtimeBus] that delivers inside one process, in memory.
///
/// Delivery is asynchronous, as a broadcast stream's is: a message reaches a
/// subscriber after the publisher's current event finishes.
final class InMemoryRealtimeBus implements RealtimeBus {
  /// Creates an empty bus.
  InMemoryRealtimeBus();

  final Map<String, Set<void Function(Object?)>> _listeners = {};

  @override
  Future<void> publish<T>(Topic<T> topic, T message) async {
    final listeners = _listeners[topic.name];
    if (listeners == null) return;
    for (final listener in listeners.toList()) {
      listener(message);
    }
  }

  @override
  Stream<T> subscribe<T>(Topic<T> topic) {
    late final StreamController<T> controller;
    void listener(Object? message) {
      if (message is T) controller.add(message);
    }

    controller = StreamController<T>(
      onListen: () => (_listeners[topic.name] ??= {}).add(listener),
      onCancel: () {
        final listeners = _listeners[topic.name];
        listeners?.remove(listener);
        if (listeners != null && listeners.isEmpty) {
          _listeners.remove(topic.name);
        }
      },
    );
    return controller.stream;
  }
}
