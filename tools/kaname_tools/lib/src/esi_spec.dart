/// Typed values for the pinned ESI OpenAPI snapshot, and the reader that
/// produces them (design D4 of `esi-client-generator`).
library;

/// The HTTP methods the reader accepts.
enum EsiHttpMethod {
  /// `get`.
  get,

  /// `post`.
  post,

  /// `put`.
  put,

  /// `delete`.
  delete,
}

/// Where a request parameter goes.
enum EsiParameterLocation {
  /// A `{name}` segment of the path template.
  path,

  /// A query parameter.
  query,
}

/// The integer formats the reader accepts.
enum EsiIntegerFormat {
  /// No `format` key.
  unspecified,

  /// `int32`.
  int32,

  /// `int64`.
  int64,
}

/// The string formats the reader accepts.
enum EsiStringFormat {
  /// No `format` key.
  plain,

  /// `date`.
  date,

  /// `date-time`.
  dateTime,

  /// `uuid`.
  uuid,
}

/// One schema node: its shape plus the facts every node may carry.
final class EsiSchema {
  /// Creates a node.
  const EsiSchema(
    this.shape, {
    this.nullable = false,
    this.description,
    this.title,
  });

  /// What values the node allows.
  final EsiShape shape;

  /// Whether `null` is allowed too (`"type": [T, "null"]`).
  final bool nullable;

  /// The node's `description`, when present.
  final String? description;

  /// The node's `title`, when present.
  final String? title;
}

/// What values a schema node allows.
sealed class EsiShape {
  const EsiShape();
}

/// A reference to a named schema under `#/components/schemas/`.
final class EsiRefShape extends EsiShape {
  /// Refers to the schema called [name].
  const EsiRefShape(this.name);

  /// The referenced schema's name.
  final String name;
}

/// An integer.
final class EsiIntegerShape extends EsiShape {
  /// Creates an integer shape.
  const EsiIntegerShape({
    this.format = EsiIntegerFormat.unspecified,
    this.minimum,
    this.maximum,
  });

  /// The stated format.
  final EsiIntegerFormat format;

  /// The inclusive lower bound, when stated.
  final num? minimum;

  /// The inclusive upper bound, when stated.
  final num? maximum;
}

/// A floating-point number (`format: double` or no format).
final class EsiNumberShape extends EsiShape {
  /// Creates a number shape.
  const EsiNumberShape({this.minimum, this.maximum});

  /// The inclusive lower bound, when stated.
  final num? minimum;

  /// The inclusive upper bound, when stated.
  final num? maximum;
}

/// A string, possibly limited to an enum.
final class EsiStringShape extends EsiShape {
  /// Creates a string shape.
  const EsiStringShape({
    this.format = EsiStringFormat.plain,
    this.enumValues,
    this.enumDescriptions,
    this.minLength,
    this.maxLength,
  });

  /// The stated format.
  final EsiStringFormat format;

  /// The listed values, or `null` for a free string.
  final List<String>? enumValues;

  /// `x-enum-descriptions`, one per listed value, when present.
  final List<String>? enumDescriptions;

  /// The minimum length, when stated.
  final int? minLength;

  /// The maximum length, when stated.
  final int? maxLength;
}

/// A boolean.
final class EsiBooleanShape extends EsiShape {
  /// Creates a boolean shape.
  const EsiBooleanShape();
}

/// An array of [items].
final class EsiArrayShape extends EsiShape {
  /// Creates an array shape.
  const EsiArrayShape(
    this.items, {
    this.minItems,
    this.maxItems,
    this.uniqueItems = false,
  });

  /// The schema of each item.
  final EsiSchema items;

  /// The minimum item count, when stated.
  final int? minItems;

  /// The maximum item count, when stated.
  final int? maxItems;

  /// Whether the items must differ.
  final bool uniqueItems;
}

/// An object with declared [properties], or a map of
/// [additionalProperties].
final class EsiObjectShape extends EsiShape {
  /// Creates an object shape.
  const EsiObjectShape({
    this.properties = const {},
    this.required = const [],
    this.additionalProperties,
  });

  /// The declared fields, in the spec's order.
  final Map<String, EsiSchema> properties;

  /// The names of the required fields.
  final List<String> required;

  /// The schema of every value of a map-like object, when stated.
  final EsiSchema? additionalProperties;
}

/// A `oneOf` of single-key objects; the key names the variant.
final class EsiOneOfShape extends EsiShape {
  /// Creates a union of [variants].
  const EsiOneOfShape(this.variants);

  /// The listed variants, in the spec's order.
  final List<EsiVariant> variants;
}

/// One listed variant of a [EsiOneOfShape].
final class EsiVariant {
  /// Creates the variant named by [key].
  const EsiVariant(this.key, this.payload, {this.title, this.description});

  /// The object's single key.
  final String key;

  /// The schema of the value under [key].
  final EsiSchema payload;

  /// The variant's `title`, when present.
  final String? title;

  /// The variant's `description`, when present.
  final String? description;
}

/// Any JSON value: a schema with no `type`, `\$ref` or `oneOf`, only
/// descriptive keys (`{}` included).
final class EsiAnyShape extends EsiShape {
  /// Creates the any-value shape.
  const EsiAnyShape();
}

/// A path or query parameter.
final class EsiParameter {
  /// Creates a parameter.
  const EsiParameter({
    required this.name,
    required this.location,
    required this.required,
    required this.schema,
    this.description,
    this.explode = true,
  });

  /// The wire name.
  final String name;

  /// Where it goes.
  final EsiParameterLocation location;

  /// Whether the operation requires it.
  final bool required;

  /// Its schema.
  final EsiSchema schema;

  /// Its description, when present.
  final String? description;

  /// For an array query parameter: `true` repeats the name per value,
  /// `false` joins the values with commas.
  final bool explode;
}

/// A JSON request body.
final class EsiRequestBody {
  /// Creates a body.
  const EsiRequestBody(this.schema, {required this.required});

  /// Its schema.
  final EsiSchema schema;

  /// Whether the operation requires it.
  final bool required;
}

/// An operation's `x-rate-limit`.
final class EsiRateLimit {
  /// Creates a rate limit.
  const EsiRateLimit({
    required this.group,
    required this.maxTokens,
    required this.window,
  });

  /// The group name.
  final String group;

  /// The tokens per window.
  final int maxTokens;

  /// The window.
  final Duration window;
}

/// The header parameters an operation may declare, all by reference to
/// `#/components/parameters/`.
const Set<String> esiStandardHeaders = {
  'Accept-Language',
  'If-None-Match',
  'X-Compatibility-Date',
  'X-Tenant',
  'If-Modified-Since',
};

/// One operation of the spec.
final class EsiOperation {
  /// Creates an operation.
  const EsiOperation({
    required this.operationId,
    required this.method,
    required this.path,
    required this.tag,
    required this.parameters,
    required this.headers,
    required this.successStatuses,
    this.summary,
    this.description,
    this.body,
    this.successSchema,
    this.pagesHeader = false,
    this.requiresAuthentication = false,
    this.scopes = const [],
    this.roles = const [],
    this.rateLimit,
    this.cacheMode,
    this.serverCacheMode,
    this.serverCacheTtl,
    this.clientCacheTtl,
    this.cacheAge,
    this.pagination,
  });

  /// The operation id.
  final String operationId;

  /// The HTTP method.
  final EsiHttpMethod method;

  /// The path template.
  final String path;

  /// The operation's single tag.
  final String tag;

  /// `summary`, when present.
  final String? summary;

  /// `description`, when present.
  final String? description;

  /// The path and query parameters, in the spec's order.
  final List<EsiParameter> parameters;

  /// The names of the standard header parameters it declares.
  final Set<String> headers;

  /// The JSON request body, when it takes one.
  final EsiRequestBody? body;

  /// The success statuses it lists (200, 201, 204).
  final List<int> successStatuses;

  /// The schema of the 200 or 201 body, when it lists one.
  final EsiSchema? successSchema;

  /// Whether a success response states the `X-Pages` header.
  final bool pagesHeader;

  /// Whether it lists a security requirement.
  final bool requiresAuthentication;

  /// The SSO scopes its security requirement lists.
  final List<String> scopes;

  /// `x-required-roles`.
  final List<String> roles;

  /// `x-rate-limit`, when stated.
  final EsiRateLimit? rateLimit;

  /// `x-cache-mode`, when stated.
  final String? cacheMode;

  /// `x-server-cache-mode`, when stated.
  final String? serverCacheMode;

  /// `x-server-cache-ttl` in seconds, when stated.
  final int? serverCacheTtl;

  /// `x-client-cache-ttl` in seconds, when stated.
  final int? clientCacheTtl;

  /// `x-cache-age` in seconds, when stated.
  final int? cacheAge;

  /// `x-pagination`, when stated (only `cursor` is accepted).
  final String? pagination;
}

/// The whole spec, as the generator needs it.
final class EsiSpec {
  /// Creates a spec.
  const EsiSpec({
    required this.version,
    required this.compatibilityDates,
    required this.languages,
    required this.schemas,
    required this.operations,
  });

  /// `info.version`.
  final String version;

  /// The `X-Compatibility-Date` parameter's enum.
  final List<String> compatibilityDates;

  /// The `Accept-Language` parameter's enum.
  final List<String> languages;

  /// The named schemas, in the spec's order.
  final Map<String, EsiSchema> schemas;

  /// Every operation, in path order, then method order within a path.
  final List<EsiOperation> operations;
}

/// What [EsiSpecReader.read] produced.
sealed class EsiSpecReadResult {
  const EsiSpecReadResult();
}

/// The document is within the supported subset.
final class EsiSpecRead extends EsiSpecReadResult {
  /// Wraps [spec].
  const EsiSpecRead(this.spec);

  /// The typed spec.
  final EsiSpec spec;
}

/// The document uses something the reader does not support.
final class EsiSpecRefused extends EsiSpecReadResult {
  /// Creates a refusal at the JSON [path].
  const EsiSpecRefused(this.path, this.reason);

  /// The JSON pointer of the offending node, such as
  /// `#/components/schemas/Foo/properties/bar`.
  final String path;

  /// What is not supported there.
  final String reason;

  @override
  String toString() => '$path: $reason';
}

final class _Refusal implements Exception {
  const _Refusal(this.path, this.reason);

  final String path;
  final String reason;
}

/// Reads an ESI OpenAPI document into an [EsiSpec].
///
/// It supports only the subset the pinned snapshot uses (design D4 of
/// `esi-client-generator`): local `$ref`s to `#/components/schemas/`,
/// object, array, string, integer, number and boolean types, `[T, "null"]`
/// nullable types, string enums, `oneOf` unions of single-key objects, the
/// formats `int32`, `int64`, `double`, `date`, `date-time` and `uuid`, path
/// and query parameters, the standard header parameters by reference, JSON
/// request bodies, and the `x-` extensions the route catalogue needs.
/// Descriptive keys are read for doc comments or ignored. Anything else
/// fails closed: the result names the construct and its JSON path, and
/// nothing is generated (constraint C4 of `esi-client-generator`).
/// Widening this subset is a deliberate generator change, made in the PR
/// that bumps the pinned date.
final class EsiSpecReader {
  /// Creates a reader.
  const EsiSpecReader();

  static const _topKeys = {
    'openapi',
    'info',
    'servers',
    'tags',
    'paths',
    'components',
  };
  static const _componentKeys = {
    'schemas',
    'parameters',
    'headers',
    'securitySchemes',
  };
  static const _schemaKeys = {
    'type',
    'format',
    'description',
    'title',
    'examples',
    'example',
    'default',
    'enum',
    'x-enum-descriptions',
    'x-common-model',
    'properties',
    'required',
    'items',
    r'$ref',
    'oneOf',
    'additionalProperties',
    'minItems',
    'maxItems',
    'uniqueItems',
    'minimum',
    'maximum',
    'minLength',
    'maxLength',
  };
  static const _descriptiveKeys = {
    'description',
    'title',
    'examples',
    'example',
    'x-common-model',
  };
  static const _operationKeys = {
    'operationId',
    'summary',
    'description',
    'tags',
    'parameters',
    'requestBody',
    'responses',
    'security',
    'x-compatibility-date',
    'x-rate-limit',
    'x-cache-mode',
    'x-server-cache-mode',
    'x-server-cache-ttl',
    'x-client-cache-ttl',
    'x-cache-age',
    'x-tombstone-ttl',
    'x-required-roles',
    'x-pagination',
  };
  static const _parameterKeys = {
    'name',
    'in',
    'required',
    'schema',
    'description',
    'explode',
    'example',
    'examples',
  };
  static const _successStatuses = {'200', '201', '204'};

  /// Reads [document], the decoded JSON of a snapshot.
  EsiSpecReadResult read(Object? document) {
    try {
      return EsiSpecRead(_Reader(document).spec());
    } on _Refusal catch (refusal) {
      return EsiSpecRefused(refusal.path, refusal.reason);
    }
  }
}

final class _Reader {
  _Reader(this.document);

  final Object? document;
  late final Map<String, Object?> _schemas;

  /// The component schemas, read before any operation.
  late final Map<String, EsiSchema> _components;

  Never _refuse(String path, String reason) => throw _Refusal(path, reason);

  static String _child(String path, String key) =>
      '$path/${key.replaceAll('~', '~0').replaceAll('/', '~1')}';

  Map<String, Object?> _object(Object? value, String path) => switch (value) {
    final Map<String, Object?> map => map,
    _ => _refuse(path, 'expected a JSON object'),
  };

  List<Object?> _array(Object? value, String path) => switch (value) {
    final List<Object?> list => list,
    _ => _refuse(path, 'expected a JSON array'),
  };

  String _string(Object? value, String path) => switch (value) {
    final String text => text,
    _ => _refuse(path, 'expected a string'),
  };

  String? _optionalString(Map<String, Object?> map, String key, String path) =>
      switch (map[key]) {
        null => null,
        final String text => text,
        _ => _refuse(_child(path, key), 'expected a string'),
      };

  int? _optionalInt(Map<String, Object?> map, String key, String path) =>
      switch (map[key]) {
        null => null,
        final int value => value,
        _ => _refuse(_child(path, key), 'expected an integer'),
      };

  num? _optionalNum(Map<String, Object?> map, String key, String path) =>
      switch (map[key]) {
        null => null,
        final num value => value,
        _ => _refuse(_child(path, key), 'expected a number'),
      };

  bool _optionalBool(
    Map<String, Object?> map,
    String key,
    String path, {
    required bool orElse,
  }) => switch (map[key]) {
    null => orElse,
    final bool value => value,
    _ => _refuse(_child(path, key), 'expected a boolean'),
  };

  List<String> _strings(Object? value, String path) => [
    for (final (i, item) in _array(value, path).indexed)
      _string(item, '$path/$i'),
  ];

  void _onlyKeys(Map<String, Object?> map, Set<String> allowed, String path) {
    for (final key in map.keys) {
      if (!allowed.contains(key)) {
        _refuse(_child(path, key), 'unsupported key "$key"');
      }
    }
  }

  EsiSpec spec() {
    const root = '#';
    final top = _object(document, root);
    _onlyKeys(top, EsiSpecReader._topKeys, root);
    final openapi = _string(top['openapi'], '#/openapi');
    if (!openapi.startsWith('3.1.')) {
      _refuse('#/openapi', 'unsupported OpenAPI version "$openapi"');
    }
    final info = _object(top['info'], '#/info');
    final version = _string(info['version'], '#/info/version');

    final components = _object(top['components'], '#/components');
    _onlyKeys(components, EsiSpecReader._componentKeys, '#/components');
    _schemas = _object(components['schemas'], '#/components/schemas');
    final parameters = _object(
      components['parameters'],
      '#/components/parameters',
    );

    final schemas = _components = <String, EsiSchema>{
      for (final MapEntry(:key, :value) in _schemas.entries)
        key: _schema(value, _child('#/components/schemas', key)),
    };

    final operations = <EsiOperation>[];
    final paths = _object(top['paths'], '#/paths');
    final ids = <String>{};
    for (final MapEntry(key: path, value: item) in paths.entries) {
      final itemPath = _child('#/paths', path);
      final methods = _object(item, itemPath);
      for (final MapEntry(key: method, value: op) in methods.entries) {
        final opPath = _child(itemPath, method);
        final httpMethod = EsiHttpMethod.values
            .where((m) => m.name == method)
            .firstOrNull;
        if (httpMethod == null) {
          _refuse(opPath, 'unsupported path item key "$method"');
        }
        final operation = _operation(op, opPath, path, httpMethod, parameters);
        if (!ids.add(operation.operationId)) {
          _refuse(
            _child(opPath, 'operationId'),
            'duplicate operation id "${operation.operationId}"',
          );
        }
        operations.add(operation);
      }
    }

    return EsiSpec(
      version: version,
      compatibilityDates: _headerEnum(parameters, 'CompatibilityDate'),
      languages: _headerEnum(parameters, 'AcceptLanguage'),
      schemas: schemas,
      operations: operations,
    );
  }

  List<String> _headerEnum(Map<String, Object?> parameters, String name) {
    final path = _child('#/components/parameters', name);
    final parameter = _object(parameters[name], path);
    final schema = _object(parameter['schema'], '$path/schema');
    return _strings(schema['enum'], '$path/schema/enum');
  }

  EsiSchema _schema(Object? value, String path) {
    final node = _object(value, path);
    _onlyKeys(node, EsiSpecReader._schemaKeys, path);
    final description = _optionalString(node, 'description', path);
    final title = _optionalString(node, 'title', path);
    EsiSchema make(EsiShape shape, {bool nullable = false}) => EsiSchema(
      shape,
      nullable: nullable,
      description: description,
      title: title,
    );

    if (node.keys.every(EsiSpecReader._descriptiveKeys.contains)) {
      return make(const EsiAnyShape());
    }
    if (node[r'$ref'] case final Object ref) {
      _onlyKeys(node, {r'$ref', ...EsiSpecReader._descriptiveKeys}, path);
      return make(EsiRefShape(_ref(ref, _child(path, r'$ref'))));
    }
    if (node['oneOf'] case final Object variants) {
      _onlyKeys(node, {'oneOf', ...EsiSpecReader._descriptiveKeys}, path);
      return make(_oneOf(variants, _child(path, 'oneOf')));
    }

    final typePath = _child(path, 'type');
    final (type, nullable) = switch (node['type']) {
      final String type => (type, false),
      [final String type, 'null'] => (type, true),
      null => _refuse(path, 'schema without "type", "\$ref" or "oneOf"'),
      _ => _refuse(typePath, 'unsupported type ${node['type']}'),
    };
    final allowed = switch (type) {
      'integer' || 'number' => {'format', 'minimum', 'maximum', 'default'},
      'string' => {
        'format',
        'enum',
        'x-enum-descriptions',
        'minLength',
        'maxLength',
        'default',
      },
      'boolean' => {'default'},
      'array' => {'items', 'minItems', 'maxItems', 'uniqueItems'},
      'object' => {'properties', 'required', 'additionalProperties'},
      _ => _refuse(typePath, 'unsupported type "$type"'),
    };
    _onlyKeys(node, {
      'type',
      ...EsiSpecReader._descriptiveKeys,
      ...allowed,
    }, path);
    final format = _optionalString(node, 'format', path);
    final formatPath = _child(path, 'format');

    final EsiShape shape = switch (type) {
      'integer' => EsiIntegerShape(
        format: switch (format) {
          null => EsiIntegerFormat.unspecified,
          'int32' => EsiIntegerFormat.int32,
          'int64' => EsiIntegerFormat.int64,
          _ => _refuse(formatPath, 'unsupported integer format "$format"'),
        },
        minimum: _optionalNum(node, 'minimum', path),
        maximum: _optionalNum(node, 'maximum', path),
      ),
      'number' => switch (format) {
        null || 'double' => EsiNumberShape(
          minimum: _optionalNum(node, 'minimum', path),
          maximum: _optionalNum(node, 'maximum', path),
        ),
        _ => _refuse(formatPath, 'unsupported number format "$format"'),
      },
      'string' => _stringShape(node, path, format),
      'boolean' => const EsiBooleanShape(),
      'array' => EsiArrayShape(
        _schema(node['items'], _child(path, 'items')),
        minItems: _optionalInt(node, 'minItems', path),
        maxItems: _optionalInt(node, 'maxItems', path),
        uniqueItems: _optionalBool(node, 'uniqueItems', path, orElse: false),
      ),
      _ => _objectShape(node, path),
    };
    return make(shape, nullable: nullable);
  }

  EsiStringShape _stringShape(
    Map<String, Object?> node,
    String path,
    String? format,
  ) {
    final enumValues = node.containsKey('enum')
        ? _strings(node['enum'], _child(path, 'enum'))
        : null;
    final descriptions = node.containsKey('x-enum-descriptions')
        ? _strings(
            node['x-enum-descriptions'],
            _child(path, 'x-enum-descriptions'),
          )
        : null;
    if (enumValues != null && enumValues.isEmpty) {
      _refuse(_child(path, 'enum'), 'empty enum');
    }
    if (descriptions != null && descriptions.length != enumValues?.length) {
      _refuse(
        _child(path, 'x-enum-descriptions'),
        'one description per enum value expected',
      );
    }
    return EsiStringShape(
      format: switch (format) {
        null => EsiStringFormat.plain,
        'date' => EsiStringFormat.date,
        'date-time' => EsiStringFormat.dateTime,
        'uuid' => EsiStringFormat.uuid,
        _ => _refuse(
          _child(path, 'format'),
          'unsupported string format "$format"',
        ),
      },
      enumValues: enumValues,
      enumDescriptions: descriptions,
      minLength: _optionalInt(node, 'minLength', path),
      maxLength: _optionalInt(node, 'maxLength', path),
    );
  }

  EsiObjectShape _objectShape(Map<String, Object?> node, String path) {
    final propertiesPath = _child(path, 'properties');
    final properties = <String, EsiSchema>{
      if (node.containsKey('properties'))
        for (final MapEntry(:key, :value) in _object(
          node['properties'],
          propertiesPath,
        ).entries)
          key: _schema(value, _child(propertiesPath, key)),
    };
    final required = node.containsKey('required')
        ? _strings(node['required'], _child(path, 'required'))
        : const <String>[];
    for (final (i, name) in required.indexed) {
      if (!properties.containsKey(name)) {
        _refuse(
          '${_child(path, 'required')}/$i',
          'required field "$name" is not a declared property',
        );
      }
    }
    final additional = switch (node['additionalProperties']) {
      null => null,
      final Map<String, Object?> schema => _schema(
        schema,
        _child(path, 'additionalProperties'),
      ),
      _ => _refuse(
        _child(path, 'additionalProperties'),
        'only a schema is supported for additionalProperties',
      ),
    };
    if (properties.isNotEmpty && additional != null) {
      _refuse(path, 'object with both properties and additionalProperties');
    }
    return EsiObjectShape(
      properties: properties,
      required: required,
      additionalProperties: additional,
    );
  }

  EsiOneOfShape _oneOf(Object? value, String path) {
    final variants = <EsiVariant>[];
    final keys = <String>{};
    for (final (i, item) in _array(value, path).indexed) {
      final variantPath = '$path/$i';
      final node = _object(item, variantPath);
      _onlyKeys(node, {
        'type',
        'properties',
        ...EsiSpecReader._descriptiveKeys,
      }, variantPath);
      if (node['type'] != 'object') {
        _refuse(variantPath, 'oneOf variant that is not an object');
      }
      final propertiesPath = _child(variantPath, 'properties');
      final properties = _object(node['properties'], propertiesPath);
      if (properties.length != 1) {
        _refuse(variantPath, 'oneOf variant without exactly one property');
      }
      final MapEntry(:key, value: payload) = properties.entries.single;
      if (!keys.add(key)) _refuse(variantPath, 'duplicate oneOf key "$key"');
      variants.add(
        EsiVariant(
          key,
          _schema(payload, _child(propertiesPath, key)),
          title: _optionalString(node, 'title', variantPath),
          description: _optionalString(node, 'description', variantPath),
        ),
      );
    }
    if (variants.isEmpty) _refuse(path, 'empty oneOf');
    return EsiOneOfShape(variants);
  }

  /// Checks a referenced standard header at [path] against what the client
  /// emits: a string schema, and `required` only for
  /// `X-Compatibility-Date`, the one header the client always sends; every
  /// other header is an optional argument or the transport's.
  void _referencedHeader(Map<String, Object?> node, String name, String path) {
    _onlyKeys(node, {
      'in',
      'name',
      'required',
      'schema',
      'description',
      'example',
    }, path);
    final required = _optionalBool(node, 'required', path, orElse: false);
    if (required && name != 'X-Compatibility-Date') {
      _refuse(
        _child(path, 'required'),
        'the header "$name" is required, but the client sends it only when '
        'given',
      );
    }
    final schemaPath = _child(path, 'schema');
    if (_resolved(_schema(node['schema'], schemaPath).shape)
        is! EsiStringShape) {
      _refuse(schemaPath, 'the header "$name" is not a string');
    }
  }

  /// Refuses a parameter [schema] the client cannot write into a request:
  /// a path parameter must be a scalar (integer, number, string or
  /// boolean), a query parameter a scalar or an array of scalars. A
  /// `$ref` is followed to the schema it names.
  void _serialisable(
    EsiSchema schema,
    EsiParameterLocation location,
    String path,
  ) {
    final shape = _resolved(schema.shape);
    final ok = switch (shape) {
      EsiArrayShape(:final items) =>
        location == EsiParameterLocation.query && _isScalar(items.shape),
      _ => _isScalar(shape),
    };
    if (!ok) {
      _refuse(
        path,
        'a ${location.name} parameter must be a scalar'
        '${location == EsiParameterLocation.query ? ' or an array of scalars' : ''}',
      );
    }
  }

  bool _isScalar(EsiShape shape) => switch (_resolved(shape)) {
    EsiIntegerShape() ||
    EsiNumberShape() ||
    EsiStringShape() ||
    EsiBooleanShape() => true,
    _ => false,
  };

  /// [shape], with references followed to the component they name.
  EsiShape _resolved(EsiShape shape) {
    final seen = <String>{};
    var current = shape;
    while (current is EsiRefShape && seen.add(current.name)) {
      current = _components[current.name]!.shape;
    }
    return current;
  }

  /// Checks the `default` response has the shape the runtime assumes when
  /// it reads an error message: no body, or a JSON object whose `error`
  /// field is a string.
  void _defaultResponse(Map<String, Object?> node, String path) {
    final contentNode = node['content'];
    if (contentNode == null) return;
    final contentPath = _child(path, 'content');
    final content = _object(contentNode, contentPath);
    _onlyKeys(content, {'application/json'}, contentPath);
    final mediaPath = _child(contentPath, 'application/json');
    final media = _object(content['application/json'], mediaPath);
    _onlyKeys(media, {'schema'}, mediaPath);
    final schemaPath = _child(mediaPath, 'schema');
    switch (_resolved(_schema(media['schema'], schemaPath).shape)) {
      case EsiObjectShape(:final properties)
          when properties['error']?.shape is EsiStringShape:
        return;
      default:
        _refuse(
          schemaPath,
          'the default response is not an object with a string "error" '
          'field, which the client reads as the error message',
        );
    }
  }

  String _ref(Object? value, String path) {
    const prefix = '#/components/schemas/';
    final ref = _string(value, path);
    if (!ref.startsWith(prefix)) _refuse(path, 'unsupported \$ref "$ref"');
    final name = ref.substring(prefix.length);
    if (!_schemas.containsKey(name)) {
      _refuse(path, '\$ref to a missing schema "$name"');
    }
    return name;
  }

  EsiOperation _operation(
    Object? value,
    String path,
    String template,
    EsiHttpMethod method,
    Map<String, Object?> componentParameters,
  ) {
    final op = _object(value, path);
    _onlyKeys(op, EsiSpecReader._operationKeys, path);
    final operationId = _string(op['operationId'], _child(path, 'operationId'));
    final tags = _strings(op['tags'], _child(path, 'tags'));
    if (tags.length != 1) {
      _refuse(_child(path, 'tags'), 'exactly one tag expected');
    }

    final parameters = <EsiParameter>[];
    final headers = <String>{};
    final parametersPath = _child(path, 'parameters');
    for (final (i, item) in _array(
      op['parameters'] ?? const <Object?>[],
      parametersPath,
    ).indexed) {
      final parameterPath = '$parametersPath/$i';
      final node = _object(item, parameterPath);
      if (node[r'$ref'] case final Object ref) {
        const prefix = '#/components/parameters/';
        final refPath = _child(parameterPath, r'$ref');
        final text = _string(ref, refPath);
        if (!text.startsWith(prefix)) {
          _refuse(refPath, 'unsupported \$ref "$text"');
        }
        final target = componentParameters[text.substring(prefix.length)];
        if (target == null) _refuse(refPath, '\$ref to a missing parameter');
        final targetNode = _object(target, text);
        final name = _string(targetNode['name'], '$text/name');
        if (targetNode['in'] != 'header' ||
            !esiStandardHeaders.contains(name)) {
          _refuse(refPath, 'unsupported referenced parameter "$name"');
        }
        _referencedHeader(targetNode, name, text);
        headers.add(name);
        continue;
      }
      _onlyKeys(node, EsiSpecReader._parameterKeys, parameterPath);
      final name = _string(node['name'], _child(parameterPath, 'name'));
      final location = switch (node['in']) {
        'path' => EsiParameterLocation.path,
        'query' => EsiParameterLocation.query,
        final other => _refuse(
          _child(parameterPath, 'in'),
          'unsupported parameter location "$other"',
        ),
      };
      final required = _optionalBool(
        node,
        'required',
        parameterPath,
        orElse: false,
      );
      if (location == EsiParameterLocation.path &&
          (!required || !template.contains('{$name}'))) {
        _refuse(parameterPath, 'path parameter not required in "$template"');
      }
      final schemaPath = _child(parameterPath, 'schema');
      final schema = _schema(node['schema'], schemaPath);
      _serialisable(schema, location, schemaPath);
      parameters.add(
        EsiParameter(
          name: name,
          location: location,
          required: required,
          schema: schema,
          description: _optionalString(node, 'description', parameterPath),
          explode: _optionalBool(node, 'explode', parameterPath, orElse: true),
        ),
      );
    }
    for (final match in RegExp(r'\{([^}]+)\}').allMatches(template)) {
      final name = match.group(1)!;
      if (!parameters.any(
        (p) => p.location == EsiParameterLocation.path && p.name == name,
      )) {
        _refuse(path, 'path segment {$name} has no path parameter');
      }
    }

    final body = switch (op['requestBody']) {
      null => null,
      final Object node => _requestBody(node, _child(path, 'requestBody')),
    };

    final responsesPath = _child(path, 'responses');
    final responses = _object(op['responses'], responsesPath);
    final successStatuses = <int>[];
    EsiSchema? successSchema;
    var pagesHeader = false;
    for (final MapEntry(key: status, value: response) in responses.entries) {
      final responsePath = _child(responsesPath, status);
      final node = _object(response, responsePath);
      _onlyKeys(node, {'description', 'content', 'headers'}, responsePath);
      if (status == 'default') {
        _defaultResponse(node, responsePath);
        continue;
      }
      if (!EsiSpecReader._successStatuses.contains(status)) {
        _refuse(responsePath, 'unsupported response status "$status"');
      }
      successStatuses.add(int.parse(status));
      if (node['headers'] case final Object headerMap) {
        pagesHeader |= _object(
          headerMap,
          _child(responsePath, 'headers'),
        ).containsKey('X-Pages');
      }
      final contentNode = node['content'];
      if (contentNode == null) {
        // Only a 204 is read as no content; any other success is decoded
        // as JSON, so a bodyless one would always look malformed.
        if (status != '204') {
          _refuse(responsePath, 'a $status response with no content');
        }
        continue;
      }
      final contentPath = _child(responsePath, 'content');
      final content = _object(contentNode, contentPath);
      _onlyKeys(content, {'application/json'}, contentPath);
      final mediaPath = _child(contentPath, 'application/json');
      final media = _object(content['application/json'], mediaPath);
      _onlyKeys(media, {'schema'}, mediaPath);
      final schema = _schema(media['schema'], _child(mediaPath, 'schema'));
      if (status == '204') {
        if (schema.shape is! EsiAnyShape) {
          _refuse(mediaPath, 'a 204 response with a body schema');
        }
        continue;
      }
      if (successSchema != null) {
        _refuse(responsePath, 'more than one success response with a body');
      }
      successSchema = schema;
    }
    if (successStatuses.isEmpty) {
      _refuse(responsesPath, 'no success response');
    }

    final (requiresAuthentication, scopes) = _security(op, path);
    return EsiOperation(
      operationId: operationId,
      method: method,
      path: template,
      tag: tags.single,
      summary: _optionalString(op, 'summary', path),
      description: _optionalString(op, 'description', path),
      parameters: parameters,
      headers: headers,
      body: body,
      successStatuses: successStatuses,
      successSchema: successSchema,
      pagesHeader: pagesHeader,
      requiresAuthentication: requiresAuthentication,
      scopes: scopes,
      roles: op.containsKey('x-required-roles')
          ? _strings(op['x-required-roles'], _child(path, 'x-required-roles'))
          : const [],
      rateLimit: _rateLimit(op['x-rate-limit'], _child(path, 'x-rate-limit')),
      cacheMode: _optionalString(op, 'x-cache-mode', path),
      serverCacheMode: _optionalString(op, 'x-server-cache-mode', path),
      serverCacheTtl: _optionalInt(op, 'x-server-cache-ttl', path),
      clientCacheTtl: _optionalInt(op, 'x-client-cache-ttl', path),
      cacheAge: _optionalInt(op, 'x-cache-age', path),
      pagination: switch (op['x-pagination']) {
        null => null,
        'cursor' => 'cursor',
        final other => _refuse(
          _child(path, 'x-pagination'),
          'unsupported pagination "$other"',
        ),
      },
    );
  }

  EsiRequestBody _requestBody(Object node, String path) {
    final body = _object(node, path);
    _onlyKeys(body, {'content', 'required', 'description'}, path);
    final contentPath = _child(path, 'content');
    final content = _object(body['content'], contentPath);
    _onlyKeys(content, {'application/json'}, contentPath);
    final mediaPath = _child(contentPath, 'application/json');
    final media = _object(content['application/json'], mediaPath);
    _onlyKeys(media, {'schema'}, mediaPath);
    return EsiRequestBody(
      _schema(media['schema'], _child(mediaPath, 'schema')),
      required: _optionalBool(body, 'required', path, orElse: false),
    );
  }

  (bool, List<String>) _security(Map<String, Object?> op, String path) {
    final value = op['security'];
    if (value == null) return (false, const []);
    final securityPath = _child(path, 'security');
    return switch (_array(value, securityPath)) {
      [{'OAuth2': final Object scopes} && final Map<String, Object?> entry]
          when entry.length == 1 =>
        (true, _strings(scopes, '$securityPath/0/OAuth2')),
      _ => _refuse(securityPath, 'only one OAuth2 requirement is supported'),
    };
  }

  EsiRateLimit? _rateLimit(Object? value, String path) {
    if (value == null) return null;
    final node = _object(value, path);
    _onlyKeys(node, {'group', 'max-tokens', 'window-size'}, path);
    final window = _string(node['window-size'], _child(path, 'window-size'));
    final match = RegExp(r'^([1-9][0-9]*)([smh])$').firstMatch(window);
    if (match == null) {
      _refuse(_child(path, 'window-size'), 'unsupported window "$window"');
    }
    final amount = int.parse(match.group(1)!);
    return EsiRateLimit(
      group: _string(node['group'], _child(path, 'group')),
      maxTokens: switch (node['max-tokens']) {
        final int tokens => tokens,
        _ => _refuse(_child(path, 'max-tokens'), 'expected an integer'),
      },
      window: switch (match.group(2)) {
        's' => Duration(seconds: amount),
        'm' => Duration(minutes: amount),
        _ => Duration(hours: amount),
      },
    );
  }
}
