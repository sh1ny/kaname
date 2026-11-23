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

/// A `oneOf` value of a spec union as received: a listed variant, or an
/// object with one key the pinned spec does not list.
///
/// [V] is the union's sealed type; its subclasses are the listed variants.
sealed class EsiOneOf<V extends Object> {
  const EsiOneOf();

  /// The object's single key.
  String get key;
}

/// A variant the pinned spec lists.
final class EsiVariant<V extends Object> extends EsiOneOf<V> {
  /// Wraps [value], whose key is [key].
  const EsiVariant(this.key, this.value);

  @override
  final String key;

  /// The listed variant.
  final V value;

  @override
  bool operator ==(Object other) =>
      other is EsiVariant<V> && other.key == key && other.value == value;

  @override
  int get hashCode => Object.hash(key, value);

  @override
  String toString() => 'EsiVariant($key: $value)';
}

/// An object whose single key names no listed variant, kept as received.
final class EsiUnknownVariant<V extends Object> extends EsiOneOf<V> {
  /// Wraps the received [object], which holds exactly one key.
  const EsiUnknownVariant(this.object);

  /// The object as received.
  final Map<String, Object?> object;

  @override
  String get key => object.keys.single;

  @override
  bool operator ==(Object other) =>
      other is EsiUnknownVariant<V> && _sameJson(other.object, object);

  @override
  int get hashCode => Object.hash(key, object.length);

  @override
  String toString() => 'EsiUnknownVariant($object)';
}

/// Whether two decoded JSON values are equal, comparing lists and maps by
/// content.
bool _sameJson(Object? a, Object? b) => switch ((a, b)) {
  (final List<Object?> a, final List<Object?> b) =>
    a.length == b.length &&
        [for (var i = 0; i < a.length; i++) i]
            .every((i) => _sameJson(a[i], b[i])),
  (final Map<String, Object?> a, final Map<String, Object?> b) =>
    a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && _sameJson(a[k], b[k])),
  _ => a == b,
};
