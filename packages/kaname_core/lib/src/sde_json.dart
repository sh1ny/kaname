/// The JSON wrapper that Serverpod stores in `jsonb` columns.
library;

/// A JSON object read from the EVE static data export (SDE), kept whole.
///
/// Serverpod needs a class with `toJson` and a `fromJson` factory to
/// serialize a field that is not a model, so this wraps the plain map. It
/// lives here, free of Serverpod, because the server and the generated
/// client must both depend on the package that holds it.
final class SdeJson {
  /// Creates a wrapper around [value].
  const SdeJson(this.value);

  /// Reads a wrapper from the object Serverpod decoded.
  ///
  /// Throws a [FormatException] when [json] is not a map with text keys.
  factory SdeJson.fromJson(Object? json) {
    if (json is! Map<Object?, Object?>) {
      throw FormatException('SdeJson expects a JSON object', json);
    }
    return SdeJson({
      for (final MapEntry(:key, :value) in json.entries)
        switch (key) {
          final String key => key,
          _ => throw FormatException('SdeJson key is not text', key),
        }: value,
    });
  }

  /// The JSON object.
  final Map<String, Object?> value;

  /// Returns the JSON object for Serverpod to store.
  Map<String, Object?> toJson() => value;

  /// Returns a copy, with [value] replaced when given.
  SdeJson copyWith({Map<String, Object?>? value}) =>
      SdeJson(value ?? this.value);

  @override
  String toString() => 'SdeJson($value)';
}
