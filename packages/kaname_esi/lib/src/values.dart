/// Values the pinned spec may not list (design D1 of `esi-client-generator`).
library;

/// An enum the generator writes for a spec enum: each value knows its wire
/// form.
abstract interface class EsiWireEnum implements Enum {
  /// The value as ESI writes it.
  String get wire;
}

/// A value of a spec enum as received: a listed value, or one the pinned
/// spec does not list.
sealed class EsiEnum<E extends EsiWireEnum> {
  const EsiEnum();

  /// The value as ESI wrote it.
  String get wire;
}

/// A value the pinned spec lists.
final class EsiKnown<E extends EsiWireEnum> extends EsiEnum<E> {
  /// Wraps [value].
  const EsiKnown(this.value);

  /// The listed value.
  final E value;

  @override
  String get wire => value.wire;

  @override
  bool operator ==(Object other) =>
      other is EsiKnown<E> && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'EsiKnown($wire)';
}

/// A string the pinned spec does not list, kept as received.
final class EsiUnknown<E extends EsiWireEnum> extends EsiEnum<E> {
  /// Wraps the received [wire] string.
  const EsiUnknown(this.wire);

  @override
  final String wire;

  @override
  bool operator ==(Object other) =>
      other is EsiUnknown<E> && other.wire == wire;

  @override
  int get hashCode => wire.hashCode;

  @override
  String toString() => 'EsiUnknown($wire)';
}
