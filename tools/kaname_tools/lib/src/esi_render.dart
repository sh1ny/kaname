/// Renders the typed ESI client, its models and the route catalogue from a
/// read spec (design D12 of `esi-client-generator`).
library;

import 'package:dart_style/dart_style.dart';

import 'esi_pin.dart';
import 'esi_spec.dart';

/// Where the generated files live, relative to the repository root.
const String esiGeneratedDirectory = 'packages/kaname_esi/lib/src/generated';

/// The generated file that exports every other one.
const String esiGeneratedLibrary = 'esi.dart';

/// Where the generated coverage test lives, relative to the repository
/// root.
const String esiGeneratedTestDirectory = 'packages/kaname_esi/test/generated';

/// The directories generation owns: every `.dart` file in them is
/// generated.
const List<String> esiGeneratedDirectories = [
  esiGeneratedDirectory,
  esiGeneratedTestDirectory,
];

/// What [renderEsiClient] produced.
sealed class EsiRenderResult {
  const EsiRenderResult();
}

/// Every generated file, rendered and formatted.
final class EsiRendered extends EsiRenderResult {
  /// Creates the result from [files].
  const EsiRendered(this.files);

  /// Each file's text by its repository-relative path, sorted by path.
  final Map<String, String> files;
}

/// Generation is refused; no file may be written.
final class EsiRenderRefused extends EsiRenderResult {
  /// Creates a refusal explained by [reason].
  const EsiRenderRefused(this.reason);

  /// Why, naming both sources of a name collision.
  final String reason;
}

/// Renders the client for [spec] at the pinned compatibility [date].
///
/// Dart names derive from schema names, property names and operation ids;
/// two sources deriving one name refuse generation, naming both.
EsiRenderResult renderEsiClient(EsiSpec spec, {required String date}) {
  try {
    final renderer = _Renderer(spec, date);
    final files = {
      for (final MapEntry(:key, :value) in renderer.render().entries)
        '$esiGeneratedDirectory/$key': value,
      '$esiGeneratedTestDirectory/operations_test.dart': renderer
          .renderOperationsTest(),
    };
    final formatter = DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    );
    return EsiRendered({
      for (final name in files.keys.toList()..sort())
        name: formatter.format(files[name]!, uri: name),
    });
  } on _Collision catch (collision) {
    return EsiRenderRefused(collision.reason);
  } on FormatterException catch (e) {
    return EsiRenderRefused(
      'the generated code does not parse, a generator bug: ${e.message()}',
    );
  }
}

final class _Collision implements Exception {
  const _Collision(this.reason);

  final String reason;
}

// Naming.

final RegExp _word = RegExp('[A-Za-z0-9]+');

const Set<String> _reservedWords = {
  'assert',
  'await',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'default',
  'do',
  'else',
  'enum',
  'extends',
  'false',
  'final',
  'finally',
  'for',
  'if',
  'in',
  'is',
  'new',
  'null',
  'rethrow',
  'return',
  'super',
  'switch',
  'this',
  'throw',
  'true',
  'try',
  'var',
  'void',
  'while',
  'with',
  'yield',
};

/// Type names a generated type may not take: `dart:core`'s and the
/// hand-written runtime's.
const Set<String> _takenTypeNames = {
  'BigInt',
  'Comparable',
  'DateTime',
  'Duration',
  'Enum',
  'Error',
  'Exception',
  'Expando',
  'Finalizer',
  'Function',
  'Future',
  'Invocation',
  'Iterable',
  'Iterator',
  'List',
  'Map',
  'Match',
  'Never',
  'Null',
  'Object',
  'Pattern',
  'Record',
  'RegExp',
  'Runes',
  'Set',
  'Sink',
  'StackTrace',
  'Stream',
  'String',
  'StringBuffer',
  'Symbol',
  'Type',
  'Uri',
  'WeakReference',
  'bool',
  'double',
  'int',
  'num',
  'EsiCall',
  'EsiCatalogue',
  'EsiCheck',
  'EsiClient',
  'EsiDecodeException',
  'EsiDecoder',
  'EsiEnum',
  'EsiError',
  'EsiInvalidArgument',
  'EsiInvalidRequest',
  'EsiJson',
  'EsiKnown',
  'EsiMalformed',
  'EsiMethod',
  'EsiNoRateGroup',
  'EsiNotModified',
  'EsiOneOf',
  'EsiPagination',
  'EsiRateGroup',
  'EsiRateLimited',
  'EsiRead',
  'EsiRequest',
  'EsiResponse',
  'EsiResult',
  'EsiRoute',
  'EsiSuccess',
  'EsiTransport',
  'EsiTransportFailed',
  'EsiTransportFailure',
  'EsiTransportOutcome',
  'EsiUnknown',
  'EsiUnknownVariant',
  'EsiVariant',
  'EsiWireEnum',
  'EsiWrite',
};

/// Names a generated field or client method may not take.
const Set<String> _takenFieldNames = {
  'hashCode',
  'runtimeType',
  'toString',
  'noSuchMethod',
  'fromJson',
  'toJson',
  'transport',
};

/// Names a generated enum value may not take.
const Set<String> _takenEnumNames = {
  'hashCode',
  'runtimeType',
  'toString',
  'noSuchMethod',
  'values',
  'index',
  'name',
  'wire',
};

List<String> _words(String raw) => [
  for (final match in _word.allMatches(raw)) match[0]!,
];

String _upperFirst(String word) =>
    word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);

String _lowerFirst(String word) =>
    word.isEmpty ? word : word[0].toLowerCase() + word.substring(1);

/// `UpperCamelCase` of [raw]; a leading digit gets a `T` prefix.
String _typeName(String raw) {
  final name = _words(raw).map(_upperFirst).join();
  if (name.isEmpty) return 'T';
  return RegExp('^[0-9]').hasMatch(name) ? 'T$name' : name;
}

/// `lowerCamelCase` of [raw]; a leading digit gets a `v` prefix, and a
/// reserved word or a name in [taken] a `Value` suffix.
String _memberName(String raw, [Set<String> taken = const {}]) {
  final words = _words(raw);
  if (words.isEmpty) return 'value';
  var name = _lowerFirst(words.first) + words.skip(1).map(_upperFirst).join();
  if (RegExp('^[0-9]').hasMatch(name)) name = 'v$name';
  if (_reservedWords.contains(name) || taken.contains(name)) {
    name = '${name}Value';
  }
  return name;
}

String _fileStem(String tag) =>
    _words(tag).map((word) => word.toLowerCase()).join('_');

/// [text] as a single-quoted Dart string literal.
String _literal(String text) {
  final escaped = text
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\t', r'\t');
  return "'$escaped'";
}

/// The Dart expression `'$path.<key>'`, extending the path variable [path]
/// by [key].
String _childPath(String path, String key) {
  final escaped = _literal(key);
  return "'\$$path.${escaped.substring(1, escaped.length - 1)}'";
}

String _pointer(String key) => key.replaceAll('~', '~0').replaceAll('/', '~1');

/// Writes [text] as `///` doc comment lines into [out].
void _doc(StringBuffer out, String? text, String fallback) {
  final lines = (text == null || text.trim().isEmpty ? fallback : text)
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((line) => line.trimRight())
      .toList();
  while (lines.isNotEmpty && lines.first.isEmpty) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  for (final line in lines) {
    out.writeln(line.isEmpty ? '///' : '/// $line');
  }
}

// Types.

/// How a value of one schema is typed, read and written in Dart.
sealed class _Ty {
  const _Ty();

  /// The Dart type; [argument] types enums as the plain enum, which a
  /// caller cannot fill with an unlisted value.
  String type({bool argument = false});

  /// An expression reading [json] at the path expression [path].
  String read(String json, String path);

  /// A function expression of type `EsiRead<T>`.
  String reader() => '(j, p) => ${read('j', 'p')}';

  /// An expression writing [value] at the path expression [path].
  String write(String value, String path, {bool argument = false});

  /// A function expression of type `EsiWrite<T>`.
  String writer({bool argument = false}) =>
      '(v, p) => ${write('v', 'p', argument: argument)}';

  /// Whether `null` is a value of [type] already.
  bool get nullable => false;
}

final class _Scalar extends _Ty {
  const _Scalar(this.dart, this.readFunction, {this.writeFunction});

  final String dart;
  final String readFunction;

  /// A function writing the value, such as `EsiCheck.date`, when the value
  /// is not its own JSON form.
  final String? writeFunction;

  @override
  String type({bool argument = false}) => dart;

  @override
  String read(String json, String path) => '$readFunction($json, $path)';

  @override
  String reader() => readFunction;

  @override
  String write(String value, String path, {bool argument = false}) =>
      switch (writeFunction) {
        final function? => '$function($value, $path)',
        null => value,
      };

  @override
  String writer({bool argument = false}) => writeFunction ?? 'EsiCheck.plain';
}

/// An integer or number with bounds, or a string with a length bound.
final class _Bounded extends _Ty {
  const _Bounded(this.base, this.function, this.values);

  final _Scalar base;

  /// The stated bounds by name: `minimum`, `maximum`, `minLength` or
  /// `maxLength`.
  final Map<String, num> values;

  /// `range` or `length`.
  final String function;

  /// The named arguments, such as `minimum: 1, maximum: 5`.
  String get bounds =>
      [for (final MapEntry(:key, :value) in values.entries) '$key: $value']
          .join(', ');

  @override
  String type({bool argument = false}) => base.dart;

  @override
  String read(String json, String path) => base.read(json, path);

  @override
  String reader() => base.reader();

  @override
  String write(String value, String path, {bool argument = false}) =>
      'EsiCheck.$function($value, $path, $bounds)';
}

final class _Any extends _Ty {
  const _Any();

  @override
  String type({bool argument = false}) => 'Object?';

  @override
  String read(String json, String path) => json;

  @override
  String reader() => 'EsiJson.any';

  @override
  String write(String value, String path, {bool argument = false}) => value;

  @override
  String writer({bool argument = false}) => 'EsiCheck.plain';

  @override
  bool get nullable => true;
}

final class _List extends _Ty {
  const _List(this.item, this.bounds, {this.minItems});

  final _Ty item;
  final String bounds;

  /// The stated minimum item count, if any.
  final int? minItems;

  @override
  String type({bool argument = false}) =>
      'List<${item.type(argument: argument)}>';

  @override
  String read(String json, String path) =>
      'EsiJson.list<${item.type()}>($json, $path, ${item.reader()})';

  @override
  String write(String value, String path, {bool argument = false}) =>
      'EsiCheck.list<${item.type(argument: argument)}>($value, $path, '
      '${item.writer(argument: argument)}$bounds)';
}

final class _Map extends _Ty {
  const _Map(this.value);

  final _Ty value;

  @override
  String type({bool argument = false}) => 'Map<String, ${value.type()}>';

  @override
  String read(String json, String path) =>
      'EsiJson.map<${value.type()}>($json, $path, ${value.reader()})';

  @override
  String write(String value, String path, {bool argument = false}) =>
      'EsiCheck.map<${this.value.type()}>($value, $path, '
      '${this.value.writer()})';
}

final class _Nullable extends _Ty {
  const _Nullable(this.inner);

  final _Ty inner;

  @override
  String type({bool argument = false}) => '${inner.type(argument: argument)}?';

  @override
  String read(String json, String path) =>
      'EsiJson.nullable<${inner.type()}>($json, $path, ${inner.reader()})';

  @override
  String write(String value, String path, {bool argument = false}) =>
      'EsiCheck.optional<${inner.type(argument: argument)}>($value, $path, '
      '${inner.writer(argument: argument)})';

  @override
  bool get nullable => true;
}

final class _NamedTy extends _Ty {
  const _NamedTy(this.named);

  final _Named named;

  @override
  String type({bool argument = false}) => switch (named) {
    _Enum(:final name) => argument ? name : 'EsiEnum<$name>',
    _Union(:final name) => 'EsiOneOf<$name>',
    _Class(:final name) => name,
  };

  @override
  String read(String json, String path) => switch (named) {
    _Enum(:final name) =>
      'EsiJson.enumValue<$name>($json, $path, '
          '$name.values)',
    _Union(:final name) ||
    _Class(:final name) => '$name.fromJson($json, $path)',
  };

  @override
  String reader() => switch (named) {
    _Enum() => super.reader(),
    _Union(:final name) || _Class(:final name) => '$name.fromJson',
  };

  @override
  String write(String value, String path, {bool argument = false}) =>
      switch (named) {
        _Enum() when argument => 'EsiCheck.wire($value, $path)',
        _Enum() => 'EsiCheck.known($value, $path)',
        _Union(:final name) => '$name.toJson($value, $path)',
        _Class() => '$value.toJson($path)',
      };

  @override
  String writer({bool argument = false}) => switch (named) {
    _Enum() when argument => 'EsiCheck.wire',
    _Enum() => 'EsiCheck.known',
    _Union(:final name) => '$name.toJson',
    _Class() => super.writer(argument: argument),
  };
}

/// A generated type: a class, an enum or a union.
sealed class _Named {
  _Named(this.name, this.source, this.file, this.schema);

  final String name;
  final String source;

  /// The generated file that declares it.
  final String file;
  final EsiSchema schema;

  bool decoded = false;
  bool encoded = false;
}

final class _Field {
  _Field(this.key, this.name, this.ty, {required this.required, this.doc});

  final String key;
  final String name;
  final _Ty ty;
  final bool required;
  final String? doc;

  /// The field's Dart type.
  String get type => required || ty.nullable ? ty.type() : '${ty.type()}?';

  /// [ty] without a `null` of its own: what is read when the field is
  /// present and not `null`.
  _Ty get present => switch (ty) {
    _Nullable(:final inner) => inner,
    _ => ty,
  };
}

final class _Class extends _Named {
  _Class(super.name, super.source, super.file, super.schema);

  final List<_Field> fields = [];
}

final class _Enum extends _Named {
  _Enum(super.name, super.source, super.file, super.schema, this.values);

  /// Each wire value with its Dart name and description.
  final List<(String wire, String name, String? doc)> values;
}

final class _VariantCase {
  _VariantCase(this.key, this.className, this.ty, this.doc);

  final String key;
  final String className;
  final _Ty ty;
  final String? doc;
}

final class _Union extends _Named {
  _Union(super.name, super.source, super.file, super.schema);

  final List<_VariantCase> variants = [];
}

/// One operation as the client renders it.
final class _Call {
  _Call(this.operation, this.method, this.file);

  final EsiOperation operation;
  final String method;
  final String file;
  final List<(EsiParameter parameter, String name, _Ty ty)> parameters = [];
  _Ty? body;
  _Ty? success;
}

// The renderer.

final class _Renderer {
  _Renderer(this.spec, this.date);

  final EsiSpec spec;
  final String date;

  /// Every claimed type, extension and file name, with the source that
  /// claimed it.
  final Map<String, String> _claims = {
    for (final name in _takenTypeNames) name: 'the kaname_esi runtime',
  };
  final Map<String, _Ty> _components = {};
  final List<_Named> _types = [];
  final List<_Call> _calls = [];

  void _claim(String name, String source) {
    switch (_claims[name]) {
      case null:
        _claims[name] = source;
      case final other:
        throw _Collision(
          'name collision: Dart name $name derives from $other and from '
          '$source',
        );
    }
  }

  void _claimMember(
    Map<String, String> members,
    String name,
    String source,
    String owner,
  ) {
    switch (members[name]) {
      case null:
        members[name] = source;
      case final other:
        throw _Collision(
          'name collision: member $name of $owner derives from $other and '
          'from $source',
        );
    }
  }

  Map<String, String> render() {
    _claim('EsiLanguage', 'the Accept-Language header');
    final methods = <String, String>{};
    for (final op in spec.operations) {
      final stem = _fileStem(op.tag);
      final pointer = '#/paths/${_pointer(op.path)}/${op.method.name}';
      final call = _Call(
        op,
        _memberName(op.operationId, _takenFieldNames),
        stem,
      );
      _claimMember(
        methods,
        call.method,
        'operation ${op.operationId}',
        'EsiClient',
      );
      final opName = _typeName(op.operationId);
      final names = <String, String>{
        'ifNoneMatch': 'the If-None-Match header',
        'acceptLanguage': 'the Accept-Language header',
        'body': 'the request body',
      };
      for (final (i, parameter) in op.parameters.indexed) {
        final name = _memberName(parameter.name);
        _claimMember(
          names,
          name,
          'parameter ${parameter.name}',
          'operation ${op.operationId}',
        );
        call.parameters.add((
          parameter,
          name,
          _resolve(
            parameter.schema,
            '$opName${_typeName(parameter.name)}',
            '$pointer/parameters/$i/schema',
            stem,
          ),
        ));
      }
      if (op.body case final body?) {
        call.body = _resolve(
          body.schema,
          '${opName}Body',
          '$pointer/requestBody/content/application~1json/schema',
          stem,
        );
      }
      if (op.successSchema case final schema?) {
        final status = op.successStatuses.firstWhere((s) => s != 204);
        call.success = _resolve(
          schema,
          '${opName}Response',
          '$pointer/responses/$status/content/application~1json/schema',
          stem,
        );
      }
      _calls.add(call);
    }
    for (final call in _calls) {
      for (final (_, _, ty) in call.parameters) {
        _mark(ty, encode: true);
      }
      if (call.body case final body?) _mark(body, encode: true);
      if (call.success case final success?) _mark(success, encode: false);
    }

    final stems = <String>[];
    for (final op in spec.operations) {
      final stem = _fileStem(op.tag);
      if (!stems.contains(stem)) {
        _claim('${_typeName(op.tag)}Calls', 'tag ${op.tag}');
        stems.add(stem);
      }
    }
    final files = <String, String>{
      'pin.dart': _renderPin(),
      'catalogue.dart': _renderCatalogue(),
    };
    for (final stem in stems) {
      final models = _types.where((type) => type.file == stem).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      if (models.isNotEmpty) {
        files['${stem}_models.dart'] = _renderModels(stem, models);
      }
      files['${stem}_client.dart'] = _renderClient(
        stem,
        _calls.where((call) => call.file == stem).toList(),
      );
    }
    files[esiGeneratedLibrary] = _renderLibrary(files.keys);
    return files;
  }

  /// Types [schema], declaring the named types it needs in [file]; [hint]
  /// names an inline object, enum or union, and [source] is its JSON
  /// pointer.
  _Ty _resolve(
    EsiSchema schema,
    String hint,
    String source,
    String file, {
    void Function(_Named named)? register,
  }) => _wrap(schema, _resolveShape(schema, hint, source, file, register));

  _Ty _wrap(EsiSchema schema, _Ty ty) =>
      schema.nullable && !ty.nullable ? _Nullable(ty) : ty;

  _Ty _resolveShape(
    EsiSchema schema,
    String hint,
    String source,
    String file,
    void Function(_Named named)? register,
  ) => switch (schema.shape) {
    EsiRefShape(:final name) => _component(name, file),
    EsiIntegerShape(:final minimum, :final maximum) => _bounded(
      const _Scalar('int', 'EsiJson.integer'),
      'range',
      {'minimum': minimum, 'maximum': maximum},
    ),
    EsiNumberShape(:final minimum, :final maximum) => _bounded(
      const _Scalar('double', 'EsiJson.number'),
      'range',
      {'minimum': minimum, 'maximum': maximum},
    ),
    EsiStringShape(enumValues: final values?) => _NamedTy(
      _declareEnum(schema, values, hint, source, file, register),
    ),
    EsiStringShape(format: EsiStringFormat.date) => const _Scalar(
      'DateTime',
      'EsiJson.date',
      writeFunction: 'EsiCheck.date',
    ),
    EsiStringShape(format: EsiStringFormat.dateTime) => const _Scalar(
      'DateTime',
      'EsiJson.dateTime',
      writeFunction: 'EsiCheck.dateTime',
    ),
    EsiStringShape(format: EsiStringFormat.uuid) => const _Scalar(
      'String',
      'EsiJson.uuid',
      writeFunction: 'EsiCheck.uuid',
    ),
    EsiStringShape(:final minLength, :final maxLength) => _bounded(
      const _Scalar('String', 'EsiJson.string'),
      'length',
      {'minLength': minLength, 'maxLength': maxLength},
    ),
    EsiBooleanShape() => const _Scalar('bool', 'EsiJson.boolean'),
    EsiAnyShape() => const _Any(),
    EsiArrayShape(
      :final items,
      :final minItems,
      :final maxItems,
      :final uniqueItems,
    ) =>
      _List(
        _resolve(items, '${hint}Item', '$source/items', file),
        [
          if (minItems != null) ', minItems: $minItems',
          if (maxItems != null) ', maxItems: $maxItems',
          if (uniqueItems) ', unique: true',
        ].join(),
        minItems: minItems,
      ),
    EsiObjectShape(properties: final properties, :final additionalProperties)
        when properties.isEmpty =>
      switch (additionalProperties) {
        final values? => _Map(
          _resolve(
            values,
            '${hint}Value',
            '$source/additionalProperties',
            file,
          ),
        ),
        null => const _Scalar('Map<String, Object?>', 'EsiJson.object'),
      },
    EsiObjectShape() => _NamedTy(
      _declareClass(schema, hint, source, file, register),
    ),
    EsiOneOfShape() => _NamedTy(
      _declareUnion(schema, hint, source, file, register),
    ),
  };

  _Ty _bounded(_Scalar base, String function, Map<String, num?> bounds) {
    final stated = {
      for (final MapEntry(:key, :value) in bounds.entries) key: ?value,
    };
    return stated.isEmpty ? base : _Bounded(base, function, stated);
  }

  _Ty _component(String name, String file) {
    if (_components[name] case final ty?) return ty;
    final schema = spec.schemas[name]!;
    final source = '#/components/schemas/${_pointer(name)}';
    // A named type is cached as soon as it exists, so a schema that refers
    // back to itself resolves to it instead of recursing.
    final ty = _resolve(
      schema,
      _typeName(name),
      source,
      file,
      register: (named) => _components[name] = _wrap(schema, _NamedTy(named)),
    );
    return _components[name] = ty;
  }

  _Enum _declareEnum(
    EsiSchema schema,
    List<String> values,
    String name,
    String source,
    String file,
    void Function(_Named named)? register,
  ) {
    _claim(name, source);
    final descriptions = switch (schema.shape) {
      EsiStringShape(:final enumDescriptions?) => enumDescriptions,
      _ => const <String>[],
    };
    final members = <String, String>{};
    final cases = <(String, String, String?)>[];
    for (final (i, wire) in values.indexed) {
      final member = _memberName(wire, _takenEnumNames);
      _claimMember(members, member, 'value "$wire"', 'enum $name');
      cases.add((
        wire,
        member,
        i < descriptions.length ? descriptions[i] : null,
      ));
    }
    final type = _Enum(name, source, file, schema, cases);
    _types.add(type);
    register?.call(type);
    return type;
  }

  _Class _declareClass(
    EsiSchema schema,
    String name,
    String source,
    String file,
    void Function(_Named named)? register,
  ) {
    _claim(name, source);
    final type = _Class(name, source, file, schema);
    _types.add(type);
    register?.call(type);
    final shape = schema.shape as EsiObjectShape;
    final members = <String, String>{};
    for (final MapEntry(:key, :value) in shape.properties.entries) {
      final member = _memberName(key, _takenFieldNames);
      _claimMember(members, member, 'property "$key"', 'class $name');
      type.fields.add(
        _Field(
          key,
          member,
          _resolve(
            value,
            '$name${_typeName(key)}',
            '$source/properties/${_pointer(key)}',
            file,
          ),
          required: shape.required.contains(key),
          doc: value.description ?? value.title,
        ),
      );
    }
    return type;
  }

  _Union _declareUnion(
    EsiSchema schema,
    String name,
    String source,
    String file,
    void Function(_Named named)? register,
  ) {
    _claim(name, source);
    final type = _Union(name, source, file, schema);
    _types.add(type);
    register?.call(type);
    final shape = schema.shape as EsiOneOfShape;
    for (final (i, variant) in shape.variants.indexed) {
      final className = '$name${_typeName(variant.key)}';
      final variantSource = '$source/oneOf/$i';
      _claim(className, variantSource);
      type.variants.add(
        _VariantCase(
          variant.key,
          className,
          _resolve(
            variant.payload,
            '${className}Value',
            '$variantSource/properties/${_pointer(variant.key)}',
            file,
          ),
          variant.description ?? variant.title,
        ),
      );
    }
    return type;
  }

  /// Marks the named types [ty] reaches as read from responses or written
  /// into requests.
  void _mark(_Ty ty, {required bool encode}) {
    switch (ty) {
      case _Scalar() || _Bounded() || _Any():
        return;
      case _List(:final item):
        _mark(item, encode: encode);
      case _Map(:final value):
        _mark(value, encode: encode);
      case _Nullable(:final inner):
        _mark(inner, encode: encode);
      case _NamedTy(:final named):
        if (encode ? named.encoded : named.decoded) return;
        if (encode) {
          named.encoded = true;
        } else {
          named.decoded = true;
        }
        switch (named) {
          case _Class(:final fields):
            for (final field in fields) {
              _mark(field.ty, encode: encode);
            }
          case _Union(:final variants):
            for (final variant in variants) {
              _mark(variant.ty, encode: encode);
            }
          case _Enum():
            break;
        }
    }
  }

  // Files.

  String _header(String what) =>
      '// Generated by `mise run esi:generate` from $esiSnapshotPath.\n'
      '// Do not edit by hand.\n\n'
      '/// $what\n'
      'library;\n\n';

  String _renderLibrary(Iterable<String> files) {
    final out = StringBuffer(
      _header('Every generated file of the ESI client.'),
    );
    for (final file in files.toList()..sort()) {
      out.writeln("export '$file';");
    }
    return out.toString();
  }

  String _renderPin() {
    final out =
        StringBuffer(
            _header(
              'The pinned compatibility date and the languages it serves.',
            ),
          )
          ..writeln("import '../values.dart';")
          ..writeln()
          ..writeln(
            '/// The compatibility date every request carries, from '
            '`$esiPinPath`.',
          )
          ..writeln('const String esiCompatibilityDate = ${_literal(date)};')
          ..writeln()
          ..writeln('/// The languages ESI answers in, for `Accept-Language`.')
          ..writeln('enum EsiLanguage implements EsiWireEnum {');
    final members = <String, String>{};
    for (final language in spec.languages) {
      final member = _memberName(language, _takenEnumNames);
      _claimMember(members, member, 'value "$language"', 'enum EsiLanguage');
      out
        ..writeln('/// `$language`.')
        ..writeln('$member(${_literal(language)}),');
    }
    out
      ..writeln(';')
      ..writeln()
      ..writeln('const EsiLanguage(this.wire);')
      ..writeln()
      ..writeln('@override')
      ..writeln('final String wire;')
      ..writeln('}');
    return out.toString();
  }

  String _renderCatalogue() {
    final out =
        StringBuffer(_header('Every route of the pinned spec (design D5).'))
          ..writeln("import '../catalogue_types.dart';")
          ..writeln("import '../transport.dart';")
          ..writeln();
    String duration(int? seconds) =>
        seconds == null ? 'null' : 'Duration(seconds: $seconds)';
    String list(List<String> values) => '[${values.map(_literal).join(', ')}]';
    String text(String? value) => value == null ? 'null' : _literal(value);
    for (final call in _calls) {
      final op = call.operation;
      final pagination = switch (op.pagination) {
        'cursor' => 'cursor',
        _
            when op.pagesHeader ||
                op.parameters.any(
                  (p) =>
                      p.name == 'page' &&
                      p.location == EsiParameterLocation.query,
                ) =>
          'pages',
        _ => 'none',
      };
      final rateGroup = switch (op.rateLimit) {
        null => 'EsiRateGroup.none',
        final limit =>
          'EsiRateLimited(name: ${_literal(limit.group)}, '
              'maxTokens: ${limit.maxTokens}, '
              'window: ${duration(limit.window.inSeconds)})',
      };
      out
        ..writeln('const EsiRoute _${call.method} = EsiRoute(')
        ..writeln('operationId: ${_literal(op.operationId)},')
        ..writeln('method: EsiMethod.${op.method.name},')
        ..writeln('pathTemplate: ${_literal(op.path)},')
        ..writeln('rateGroup: $rateGroup,')
        ..writeln('pagination: EsiPagination.$pagination,')
        ..writeln('requiresAuthentication: ${op.requiresAuthentication},')
        ..writeln('scopes: ${list(op.scopes)},')
        ..writeln('roles: ${list(op.roles)},')
        ..writeln('cacheMode: ${text(op.cacheMode)},')
        ..writeln('serverCacheMode: ${text(op.serverCacheMode)},')
        ..writeln('serverCacheTtl: ${duration(op.serverCacheTtl)},')
        ..writeln('clientCacheTtl: ${duration(op.clientCacheTtl)},')
        ..writeln('cacheAge: ${duration(op.cacheAge)},')
        ..writeln(');')
        ..writeln();
    }
    out
      ..writeln('/// Every route of the pinned spec, by operation id and by')
      ..writeln('/// method and path template.')
      ..writeln('const EsiCatalogue esiCatalogue = EsiCatalogue(')
      ..writeln('byOperationId: {');
    for (final call in _calls) {
      out.writeln('${_literal(call.operation.operationId)}: _${call.method},');
    }
    out
      ..writeln('},')
      ..writeln('byMethodAndPath: {');
    for (final call in _calls) {
      final op = call.operation;
      out.writeln(
        '${_literal('${op.method.name.toUpperCase()} ${op.path}')}: '
        '_${call.method},',
      );
    }
    out
      ..writeln('},')
      ..writeln(');');
    return out.toString();
  }

  /// The models files [types] reference, other than the one of the tag
  /// whose file stem is [stem].
  Set<String> _imports(String stem, Iterable<_Ty> types) {
    final files = <String>{};
    void visit(_Ty ty) {
      switch (ty) {
        case _Scalar() || _Bounded() || _Any():
          break;
        case _List(:final item):
          visit(item);
        case _Map(:final value):
          visit(value);
        case _Nullable(:final inner):
          visit(inner);
        case _NamedTy(:final named):
          if (named.file != stem) files.add('${named.file}_models.dart');
      }
    }

    types.forEach(visit);
    return files;
  }

  String _renderModels(String stem, List<_Named> types) {
    final used = <_Ty>[
      for (final type in types)
        ...switch (type) {
          _Class(:final fields) => fields.map((field) => field.ty),
          _Union(:final variants) => variants.map((variant) => variant.ty),
          _Enum() => const <_Ty>[],
        },
    ];
    final out = StringBuffer();
    for (final type in types) {
      switch (type) {
        case _Enum():
          _renderEnum(out, type);
        case _Class():
          _renderClass(out, type);
        case _Union():
          _renderUnion(out, type);
      }
      out.writeln();
    }
    return _withImports(
      'Models of the pinned spec, first used by its ${_tagOf(stem)} '
      'operations.',
      _imports(stem, used),
      out.toString(),
    );
  }

  /// The runtime libraries of `kaname_esi` and the names each declares
  /// that generated code uses.
  static const Map<String, List<String>> _runtime = {
    '../call.dart': ['EsiCall', 'EsiDecodeException', 'EsiInvalidArgument'],
    '../client.dart': ['EsiClient'],
    '../json.dart': ['EsiJson', 'EsiCheck'],
    '../result.dart': ['EsiResult'],
    '../transport.dart': ['EsiMethod', 'EsiRequest'],
    '../values.dart': [
      'EsiEnum',
      'EsiOneOf',
      'EsiVariant',
      'EsiUnknownVariant',
      'EsiWireEnum',
    ],
  };

  /// A file headed by [what], an import of each runtime library [body] names
  /// and of each generated file in [generated], then [body].
  String _withImports(String what, Set<String> generated, String body) {
    final imports = [
      for (final MapEntry(key: file, value: names) in _runtime.entries)
        if (RegExp('\\b(${names.join('|')})\\b').hasMatch(body)) file,
      ...generated.toList()..sort(),
    ];
    return [
      _header(what),
      for (final file in imports) "import '$file';\n",
      if (imports.isNotEmpty) '\n',
      body,
    ].join();
  }

  String _tagOf(String stem) =>
      spec.operations.firstWhere((op) => _fileStem(op.tag) == stem).tag;

  void _renderEnum(StringBuffer out, _Enum type) {
    _doc(
      out,
      type.schema.description ?? type.schema.title,
      'The values of `${type.source}`.',
    );
    out.writeln('enum ${type.name} implements EsiWireEnum {');
    for (final (wire, member, doc) in type.values) {
      _doc(out, doc, '`$wire`.');
      out.writeln('$member(${_literal(wire)}),');
    }
    out
      ..writeln(';')
      ..writeln()
      ..writeln('const ${type.name}(this.wire);')
      ..writeln()
      ..writeln('@override')
      ..writeln('final String wire;')
      ..writeln('}');
  }

  void _renderClass(StringBuffer out, _Class type) {
    final name = type.name;
    _doc(
      out,
      type.schema.description ?? type.schema.title,
      'The object `${type.source}`.',
    );
    out.writeln('final class $name {');
    _doc(out, null, 'Creates a [$name].');
    if (type.fields.isEmpty) {
      out.writeln('const $name();');
    } else {
      out
        ..writeln('const $name({')
        ..writeAll([
          for (final field in type.fields)
            '${field.required ? 'required ' : ''}this.${field.name},\n',
        ])
        ..writeln('});');
    }
    for (final field in type.fields) {
      out.writeln();
      _doc(out, field.doc, 'The `${field.key}` field.');
      out.writeln('final ${field.type} ${field.name};');
    }
    if (type.decoded) {
      out.writeln();
      _doc(
        out,
        null,
        'Reads a [$name] from [json] at [path], or raises\n'
        '[EsiDecodeException] naming the first mismatch.',
      );
      out.writeln('static $name fromJson(Object? json, String path) {');
      if (type.fields.isEmpty) {
        out
          ..writeln('EsiJson.object(json, path);')
          ..writeln('return const $name();')
          ..writeln('}');
      } else {
        out
          ..writeln('final object = EsiJson.object(json, path);')
          ..writeln('return $name(');
        for (final field in type.fields) {
          final key = _literal(field.key);
          final value = switch (field) {
            _Field(required: true) => field.ty.read(
              'EsiJson.required(object, $key, path)',
              _childPath('path', field.key),
            ),
            _Field(ty: _Any()) => 'object[$key]',
            _Field(ty: _Nullable()) =>
              'EsiJson.optionalNullable<${field.present.type()}>(object, $key, '
                  'path, ${field.present.reader()})',
            _ =>
              'EsiJson.optional<${field.present.type()}>(object, $key, path, '
                  '${field.present.reader()})',
          };
          out.writeln('${field.name}: $value,');
        }
        out
          ..writeln(');')
          ..writeln('}');
      }
    }
    if (type.encoded) {
      out.writeln();
      _doc(
        out,
        null,
        'Writes this value as JSON at [path], or raises\n'
        '[EsiInvalidArgument] naming the field outside its bounds.',
      );
      out.writeln('Map<String, Object?> toJson(String path) => {');
      for (final field in type.fields) {
        final self = field.name == 'path' ? 'this.' : '';
        final value = '$self${field.name}';
        final at = _childPath('path', field.key);
        final entry = switch (field) {
          _Field(required: true) => field.ty.write(value, at),
          _Field(ty: _Any()) => '?$value',
          _ =>
            '?EsiCheck.optional<${field.present.type()}>($value, $at, '
                '${field.present.writer()})',
        };
        out.writeln('${_literal(field.key)}: $entry,');
      }
      out.writeln('};');
    }
    out.writeln('}');
  }

  void _renderUnion(StringBuffer out, _Union type) {
    final name = type.name;
    _doc(
      out,
      type.schema.description ?? type.schema.title,
      'The listed variants of `${type.source}`.',
    );
    out
      ..writeln('sealed class $name {')
      ..writeln('const $name();');
    if (type.decoded) {
      out.writeln();
      _doc(
        out,
        null,
        'Reads a [$name] from [json] at [path]: a listed variant, or\n'
        '[EsiUnknownVariant] for an object whose one key names none.\n'
        'Raises [EsiDecodeException] naming the first mismatch.',
      );
      out
        ..writeln(
          'static EsiOneOf<$name> fromJson(Object? json, String path) {',
        )
        ..writeln('final object = EsiJson.object(json, path);')
        ..writeln('final key = EsiJson.oneOfKey(object, path);')
        ..writeln('return switch (key) {');
      for (final variant in type.variants) {
        final read = variant.ty.read(
          'object[key]',
          _childPath('path', variant.key),
        );
        out.writeln(
          '${_literal(variant.key)} => EsiVariant<$name>(key, '
          '${variant.className}($read)),',
        );
      }
      out
        ..writeln('_ => EsiUnknownVariant<$name>(object),')
        ..writeln('};')
        ..writeln('}');
    }
    if (type.encoded) {
      out.writeln();
      _doc(
        out,
        null,
        'Writes [union] as JSON at [path], or raises [EsiInvalidArgument]\n'
        'for an unlisted variant or a value outside its bounds.',
      );
      out.writeln(
        'static Map<String, Object?> toJson(EsiOneOf<$name> union, '
        'String path) => switch (union) {',
      );
      for (final variant in type.variants) {
        final write = variant.ty.write(
          'value',
          _childPath('path', variant.key),
        );
        out.writeln(
          'EsiVariant(value: ${variant.className}(:final value)) => '
          '{${_literal(variant.key)}: $write},',
        );
      }
      out
        ..writeln(
          'EsiUnknownVariant(:final key) => '
          'EsiCheck.unknownVariant(key, path),',
        )
        ..writeln('};');
    }
    out.writeln('}');
    for (final variant in type.variants) {
      final className = variant.className;
      final valueType = variant.ty.type();
      out.writeln();
      _doc(out, variant.doc, 'The `${variant.key}` variant of [$name].');
      out
        ..writeln('final class $className extends $name {')
        ..writeln('/// Wraps [value].')
        ..writeln('const $className(this.value);')
        ..writeln()
        ..writeln('/// The value under `${variant.key}`.')
        ..writeln('final $valueType value;')
        ..writeln()
        ..writeln('@override')
        ..writeln(
          'bool operator ==(Object other) => '
          'other is $className && other.value == value;',
        )
        ..writeln()
        ..writeln('@override')
        ..writeln('int get hashCode => value.hashCode;')
        ..writeln()
        ..writeln('@override')
        ..writeln("String toString() => '$className(\$value)';")
        ..writeln('}');
    }
  }

  String _renderClient(String stem, List<_Call> calls) {
    final tag = calls.first.operation.tag;
    final used = <_Ty>[
      for (final call in calls) ...[
        for (final (_, _, ty) in call.parameters) ty,
        ?call.body,
        ?call.success,
      ],
    ];
    final out = StringBuffer()
      ..writeln('/// The $tag operations of the pinned spec.')
      ..writeln('extension ${_typeName(tag)}Calls on EsiClient {');
    for (final call in calls) {
      _renderCall(out, call);
    }
    out.writeln('}');
    return _withImports('The $tag operations of the pinned spec.', {
      ..._imports('', used),
      'pin.dart',
    }, out.toString());
  }

  void _renderCall(StringBuffer out, _Call call) {
    final op = call.operation;
    final methodWire = op.method.name.toUpperCase();
    final result = switch (call.success) {
      null => 'void',
      final success when op.successStatuses.contains(204) =>
        success.nullable ? success.type() : '${success.type()}?',
      final success => success.type(),
    };

    out.writeln();
    final doc = StringBuffer()
      ..writeln([?op.summary, ?op.description].join('\n\n'))
      ..writeln()
      ..writeln('`$methodWire ${op.path}` (operation `${op.operationId}`).');
    for (final (parameter, name, _) in call.parameters) {
      if (parameter.description case final text?) {
        doc.writeln('\n[$name]: ${text.trim()}');
      }
    }
    _doc(out, doc.toString(), '');
    final required = [
      for (final (parameter, name, ty) in call.parameters)
        if (parameter.required) 'required ${ty.type(argument: true)} $name,',
      if (op.body case EsiRequestBody(required: true))
        'required ${call.body!.type(argument: true)} body,',
    ];
    final optional = [
      for (final (parameter, name, ty) in call.parameters)
        if (!parameter.required) '${_optionalType(ty)} $name,',
      if (op.body case EsiRequestBody(required: false))
        '${call.body!.type(argument: true)}? body,',
      if (op.headers.contains('If-None-Match')) 'String? ifNoneMatch,',
      if (op.headers.contains('Accept-Language'))
        'EsiLanguage? acceptLanguage,',
    ];
    final parameters = [...required, ...optional];
    out
      ..writeln(
        parameters.isEmpty
            ? 'Future<EsiResult<$result>> ${call.method}() =>'
            : 'Future<EsiResult<$result>> ${call.method}({\n'
                  '${parameters.join('\n')}\n}) =>',
      )
      ..writeln('EsiCall.invoke<$result>(')
      ..writeln('transport,')
      ..writeln('() => EsiRequest(')
      ..writeln('method: EsiMethod.${op.method.name},')
      ..writeln('operationId: ${_literal(op.operationId)},')
      ..writeln('target: EsiCall.target(${_target(call)}, [');
    for (final (parameter, name, ty) in call.parameters) {
      if (parameter.location != EsiParameterLocation.query) continue;
      final value = _argument(parameter, name, ty);
      out.writeln(
        '...EsiCall.query(${_literal(parameter.name)}, $value'
        '${parameter.explode ? '' : ', explode: false'}),',
      );
    }
    final hasBody = call.body != null;
    out
      ..writeln(']),')
      ..writeln('headers: EsiCall.headers(')
      ..writeln('compatibilityDate: esiCompatibilityDate,');
    if (op.headers.contains('If-None-Match')) {
      out.writeln('ifNoneMatch: ifNoneMatch,');
    }
    if (op.headers.contains('Accept-Language')) {
      out.writeln('acceptLanguage: acceptLanguage?.wire,');
    }
    if (hasBody) {
      out.writeln(
        op.body!.required ? 'jsonBody: true,' : 'jsonBody: body != null,',
      );
    }
    out.writeln('),');
    if (call.body case final body?) {
      final write = op.body!.required
          ? body.write('body', "'body'", argument: true)
          : 'EsiCheck.optional<${body.type(argument: true)}>(body, \'body\', '
                '${body.writer(argument: true)})';
      out.writeln(
        op.body!.required
            ? 'body: EsiCall.jsonBody($write),'
            : 'body: body == null ? null : EsiCall.jsonBody($write),',
      );
    }
    out
      ..writeln('),')
      ..writeln(switch (call.success) {
        null => 'read: EsiJson.ignore,',
        final success => 'read: ${success.reader()},',
      });
    if (op.successStatuses.contains(204)) {
      out.writeln(
        call.success == null ? 'noContent: () {},' : 'noContent: () => null,',
      );
    }
    out.writeln(');');
  }

  /// The Dart type of an optional argument of [ty].
  String _optionalType(_Ty ty) =>
      ty.nullable ? ty.type(argument: true) : '${ty.type(argument: true)}?';

  /// The JSON value of [parameter], checked against its bounds.
  String _argument(EsiParameter parameter, String name, _Ty ty) {
    final path = _literal(parameter.name);
    if (parameter.required) return ty.write(name, path, argument: true);
    final present = switch (ty) {
      _Nullable(:final inner) => inner,
      _ => ty,
    };
    return 'EsiCheck.optional<${present.type(argument: true)}>($name, $path, '
        '${present.writer(argument: true)})';
  }

  /// The path template as a Dart string expression with each path
  /// parameter percent-encoded once.
  String _target(_Call call) {
    final byName = {
      for (final entry in call.parameters)
        if (entry.$1.location == EsiParameterLocation.path)
          entry.$1.name: entry,
    };
    final template = call.operation.path;
    final out = StringBuffer("'");
    var done = 0;
    for (final match in RegExp(r'\{([^}]+)\}').allMatches(template)) {
      final literal = _literal(template.substring(done, match.start));
      final (parameter, name, ty) = byName[match[1]!]!;
      out
        ..write(literal.substring(1, literal.length - 1))
        ..write(r'${EsiCall.segment(')
        ..write(_argument(parameter, name, ty))
        ..write(', ${_literal(parameter.name)})}');
      done = match.end;
    }
    final literal = _literal(template.substring(done));
    out
      ..write(literal.substring(1, literal.length - 1))
      ..write("'");
    return out.toString();
  }

  // The coverage test.

  /// The generated coverage test: every operation's method, called with
  /// placeholder arguments, against the snapshot read at test time.
  ///
  /// Run [render] first.
  String renderOperationsTest() {
    final out = StringBuffer()
      ..writeln(
        '// Generated by `mise run esi:generate` from $esiSnapshotPath.',
      )
      ..writeln('// Do not edit by hand.')
      ..writeln()
      ..writeln('/// Every operation of the pinned spec, called through its')
      ..writeln('/// generated method with placeholder arguments.')
      ..writeln('library;')
      ..writeln()
      ..writeln("import 'package:kaname_esi/kaname_esi.dart';")
      ..writeln("import 'package:test/test.dart';")
      ..writeln()
      ..writeln("import '../support/operation_coverage.dart';")
      ..writeln()
      ..writeln('void main() {')
      ..writeln('final coverage = OperationCoverage.load();')
      ..writeln()
      ..writeln("test('every operation of the snapshot has a method', () {")
      ..writeln('expect(coverage.operationIds, unorderedEquals(_called));')
      ..writeln('});')
      ..writeln()
      ..writeln(
        "group('every operation sends its method and filled path', () {",
      );
    for (final call in _calls) {
      final op = call.operation;
      final arguments = <String>[];
      final path = <String>[];
      for (final (i, (parameter, name, ty)) in call.parameters.indexed) {
        if (!parameter.required) continue;
        final value = _placeholder(ty, i + 1, argument: true);
        arguments.add('$name: $value');
        if (parameter.location == EsiParameterLocation.path) {
          final wire = switch (ty) {
            _NamedTy(named: _Enum()) => '$value.wire',
            _ => value,
          };
          path.add('${_literal(parameter.name)}: $wire');
        }
      }
      if (op.body case EsiRequestBody(required: true)) {
        arguments.add('body: ${_placeholder(call.body!, 1, argument: true)}');
      }
      out
        ..writeln('test(${_literal(op.operationId)}, () async {')
        ..writeln('await coverage.expectRequest(')
        ..writeln('${_literal(op.operationId)},')
        ..writeln('(client) => client.${call.method}(${arguments.join(', ')}),')
        ..writeln('{${path.join(', ')}},')
        ..writeln(');')
        ..writeln('});');
    }
    out
      ..writeln('});')
      ..writeln('}')
      ..writeln()
      ..writeln('const List<String> _called = [');
    for (final call in _calls) {
      out.writeln('${_literal(call.operation.operationId)},');
    }
    out.writeln('];');
    return out.toString();
  }

  /// A Dart expression of type [ty] inside every stated bound; [seed]
  /// varies values between arguments and list items.
  String _placeholder(
    _Ty ty,
    int seed, {
    bool argument = false,
    int depth = 0,
  }) {
    if (depth > 12) {
      throw _Collision(
        'no placeholder value for ${ty.type()}: its required fields nest '
        'too deeply',
      );
    }
    String inner(_Ty ty, int seed) =>
        _placeholder(ty, seed, argument: argument, depth: depth + 1);
    return switch (ty) {
      _Scalar(readFunction: 'EsiJson.uuid') => _literal(
        '00000000-0000-4000-8000-${seed.toRadixString(16).padLeft(12, '0')}',
      ),
      _Scalar(:final dart) => switch (dart) {
        'int' => '$seed',
        'double' => '$seed.5',
        'bool' => 'true',
        'DateTime' => 'DateTime.utc(2026, 11, 19)',
        'Map<String, Object?>' => 'const <String, Object?>{}',
        _ => _literal('p$seed'),
      },
      _Bounded(base: _Scalar(dart: 'String'), :final values) => _literal(
        _text(seed, values['minLength'], values['maxLength']),
      ),
      _Bounded(base: _Scalar(:final dart), :final values) => _number(
        seed,
        values['minimum'],
        values['maximum'],
        isDouble: dart == 'double',
      ),
      _Any() => 'null',
      _List(:final item, :final minItems) =>
        '[${[for (var i = 0; i < (minItems ?? 1); i++) inner(item, seed + i)].join(', ')}]',
      _Map() => '{}',
      _Nullable(:final inner) => _placeholder(
        inner,
        seed,
        argument: argument,
        depth: depth,
      ),
      _NamedTy(named: _Enum(:final name, :final values)) =>
        switch ('$name.${values[seed % values.length].$2}') {
          final member when argument => member,
          final member => 'EsiKnown($member)',
        },
      _NamedTy(named: _Class(:final name, :final fields)) =>
        '$name(${[for (final field in fields)
          if (field.required) '${field.name}: ${_placeholder(field.ty, seed, depth: depth + 1)}'].join(', ')})',
      _NamedTy(named: _Union(:final name, :final variants)) => switch (variants) {
        [final first, ...] =>
          'EsiVariant<$name>(${_literal(first.key)}, '
              '${first.className}(${_placeholder(first.ty, seed, depth: depth + 1)}))',
        [] => throw _Collision('no placeholder value for union $name'),
      },
    };
  }

  /// [seed] moved inside [minimum] and [maximum].
  static String _number(
    int seed,
    num? minimum,
    num? maximum, {
    required bool isDouble,
  }) {
    num value = seed;
    if (minimum != null && value < minimum) value = minimum;
    if (maximum != null && value > maximum) value = maximum;
    return isDouble ? '${value.toDouble()}' : '${value.toInt()}';
  }

  /// A string from [seed] padded to [minLength] and cut to [maxLength].
  static String _text(int seed, num? minLength, num? maxLength) {
    var text = 'p$seed';
    if (minLength != null && text.length < minLength) {
      text = text.padRight(minLength.toInt(), 'x');
    }
    if (maxLength != null && text.length > maxLength) {
      text = text.substring(0, maxLength.toInt());
    }
    return text;
  }
}
