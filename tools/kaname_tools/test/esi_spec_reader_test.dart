import 'package:kaname_tools/kaname_tools.dart';
import 'package:test/test.dart';

import 'support/esi_fixtures.dart';

EsiSpec _read(Object? document) =>
    switch (const EsiSpecReader().read(document)) {
      EsiSpecRead(:final spec) => spec,
      EsiSpecRefused(:final path, :final reason) => fail(
        'expected the fixture to be read, refused at $path: $reason',
      ),
    };

Map<String, Object?> _map(Object? value) => value! as Map<String, Object?>;

Map<String, Object?> _at(Map<String, Object?> document, List<String> keys) {
  var node = document;
  for (final key in keys) {
    node = _map(node[key]);
  }
  return node;
}

void main() {
  group('the fixture', () {
    final spec = _read(esiFixture());
    EsiOperation operation(String id) =>
        spec.operations.singleWhere((o) => o.operationId == id);

    test('gives its dates, languages and operations in spec order', () {
      expect(spec.version, '2030-01-02');
      expect(spec.compatibilityDates, ['2030-01-02']);
      expect(spec.languages, ['en', 'de']);
      expect(spec.operations.map((o) => o.operationId), [
        'GetWidgetsWidgetId',
        'DeleteWidgetsWidgetId',
        'GetWidgets',
        'GetGadgets',
        'PostGadgets',
      ]);
    });

    test('reads a public GET with a path parameter and cache facts', () {
      final get = operation('GetWidgetsWidgetId');
      expect(get.method, EsiHttpMethod.get);
      expect(get.path, '/widgets/{widget_id}');
      expect(get.tag, 'Widgets');
      expect(get.summary, 'Get a widget');
      expect(get.headers, esiStandardHeaders);
      expect(get.parameters.single.name, 'widget_id');
      expect(get.parameters.single.location, EsiParameterLocation.path);
      expect(get.parameters.single.required, isTrue);
      expect(
        get.parameters.single.schema.shape,
        isA<EsiRefShape>().having((s) => s.name, 'name', 'WidgetID'),
      );
      expect(get.successStatuses, [200]);
      expect(
        get.successSchema?.shape,
        isA<EsiRefShape>().having((s) => s.name, 'name', 'Widget'),
      );
      expect(get.requiresAuthentication, isFalse);
      expect(get.scopes, isEmpty);
      expect(get.rateLimit, isNull);
      expect(get.serverCacheMode, 'ttl-based');
      expect(get.serverCacheTtl, 3600);
      expect(get.clientCacheTtl, 3600);
      expect(get.cacheAge, 3600);
      expect(get.cacheMode, isNull);
      expect(get.pagesHeader, isFalse);
    });

    test('reads a scoped 204 DELETE with roles and a rate limit', () {
      final delete = operation('DeleteWidgetsWidgetId');
      expect(delete.successStatuses, [204]);
      expect(delete.successSchema, isNull);
      expect(delete.requiresAuthentication, isTrue);
      expect(delete.scopes, ['widgets.write.v1']);
      expect(delete.roles, ['Director']);
      expect(delete.rateLimit?.group, 'widget-write');
      expect(delete.rateLimit?.maxTokens, 150);
      expect(delete.rateLimit?.window, const Duration(minutes: 15));
      expect(delete.headers, {'X-Compatibility-Date'});
    });

    test('reads page and array query parameters and the X-Pages header', () {
      final list = operation('GetWidgets');
      expect(list.pagesHeader, isTrue);
      final [page, kinds] = list.parameters;
      expect(page.required, isFalse);
      expect(
        page.schema.shape,
        isA<EsiIntegerShape>()
            .having((s) => s.format, 'format', EsiIntegerFormat.int32)
            .having((s) => s.minimum, 'minimum', 1),
      );
      expect(kinds.explode, isFalse);
      expect(
        kinds.schema.shape,
        isA<EsiArrayShape>()
            .having((s) => s.minItems, 'minItems', 1)
            .having((s) => s.maxItems, 'maxItems', 2),
      );
      expect(operation('GetGadgets').pagination, 'cursor');
    });

    test('reads a required JSON body and a 201 response', () {
      final post = operation('PostGadgets');
      expect(post.body?.required, isTrue);
      expect(
        post.body?.schema.shape,
        isA<EsiArrayShape>()
            .having((s) => s.uniqueItems, 'uniqueItems', isTrue)
            .having((s) => s.maxItems, 'maxItems', 10),
      );
      expect(post.successStatuses, [201]);
    });

    test('reads object, enum, oneOf, nullable, any and map schemas', () {
      final widget = spec.schemas['Widget']!;
      expect(widget.description, 'One widget.');
      final object = widget.shape as EsiObjectShape;
      expect(object.required, ['widget_id', 'name', 'kind']);
      expect(
        object.properties['kind']!.shape,
        isA<EsiStringShape>()
            .having((s) => s.enumValues, 'enum', ['round', 'square'])
            .having((s) => s.enumDescriptions, 'descriptions', [
              'Round',
              'Square',
            ]),
      );
      expect(
        object.properties['created']!.shape,
        isA<EsiStringShape>().having(
          (s) => s.format,
          'format',
          EsiStringFormat.dateTime,
        ),
      );
      expect(object.properties['active']!.nullable, isTrue);
      expect(object.properties['active']!.shape, isA<EsiBooleanShape>());
      expect(object.properties['extra']!.shape, isA<EsiAnyShape>());
      expect(
        (object.properties['labels']!.shape as EsiObjectShape)
            .additionalProperties
            ?.shape,
        isA<EsiStringShape>(),
      );
      final price = spec.schemas['Price']!.shape as EsiOneOfShape;
      expect(price.variants.map((v) => v.key), ['isk', 'tokens']);
      expect(price.variants.first.payload.shape, isA<EsiNumberShape>());
      expect(
        spec.schemas['Empty']!.shape,
        isA<EsiObjectShape>().having(
          (s) => s.properties,
          'properties',
          isEmpty,
        ),
      );
    });
  });

  // Scenario: Unsupported construct in the snapshot.
  group('an unsupported construct is refused with its JSON path', () {
    final cases =
        <(String, void Function(Map<String, Object?>), String, String)>[
          (
            'allOf',
            (d) => _at(d, ['components', 'schemas', 'Widget'])['allOf'] = [],
            '#/components/schemas/Widget/allOf',
            'unsupported key "allOf"',
          ),
          (
            'a float format',
            (d) => _map(
              _map(
                _map(
                  (_at(d, ['components', 'schemas', 'Price'])['oneOf']!
                      as List<Object?>)[0],
                )['properties'],
              )['isk'],
            )['format'] = 'float',
            '#/components/schemas/Price/oneOf/0/properties/isk/format',
            'unsupported number format "float"',
          ),
          (
            'a pattern',
            (d) => _at(d, [
              'components',
              'schemas',
              'Widget',
              'properties',
              'name',
            ])['pattern'] = '^a',
            '#/components/schemas/Widget/properties/name/pattern',
            'unsupported key "pattern"',
          ),
          (
            'a cookie parameter',
            (d) => _map(
              (_at(d, ['paths', '/widgets', 'get'])['parameters']!
                  as List<Object?>)[0],
            )['in'] = 'cookie',
            '#/paths/~1widgets/get/parameters/0/in',
            'unsupported parameter location "cookie"',
          ),
          (
            'an inline header parameter',
            (d) =>
                (_at(d, ['paths', '/widgets', 'get'])['parameters']!
                        as List<Object?>)
                    .add({
                      'in': 'header',
                      'name': 'X-Other',
                      'schema': {'type': 'string'},
                    }),
            '#/paths/~1widgets/get/parameters/3/in',
            'unsupported parameter location "header"',
          ),
          (
            'a non-JSON response',
            (d) =>
                _at(d, [
                    'paths',
                    '/gadgets',
                    'get',
                    'responses',
                    '200',
                    'content',
                  ])
                  ..['text/plain'] = {
                    'schema': {'type': 'string'},
                  },
            '#/paths/~1gadgets/get/responses/200/content/text~1plain',
            'unsupported key "text/plain"',
          ),
          (
            'an unknown operation key',
            (d) => _at(d, ['paths', '/gadgets', 'get'])['deprecated'] = true,
            '#/paths/~1gadgets/get/deprecated',
            'unsupported key "deprecated"',
          ),
          (
            'a PATCH operation',
            (d) => _at(d, ['paths', '/gadgets'])['patch'] = <String, Object?>{},
            '#/paths/~1gadgets/patch',
            'unsupported path item key "patch"',
          ),
          (
            'an external \$ref',
            (d) => _at(d, [
              'components',
              'schemas',
              'Widget',
              'properties',
              'price',
            ])[r'$ref'] = 'other.json#/Price',
            r'#/components/schemas/Widget/properties/price/$ref',
            r'unsupported $ref "other.json#/Price"',
          ),
          (
            'a oneOf variant with two keys',
            (d) =>
                _map(
                  (_at(d, ['components', 'schemas', 'Price'])['oneOf']!
                      as List<Object?>)[1],
                )['properties'] = {
                  'a': {'type': 'string'},
                  'b': {'type': 'string'},
                },
            '#/components/schemas/Price/oneOf/1',
            'oneOf variant without exactly one property',
          ),
          (
            'an unlisted response status',
            (d) => _at(d, ['paths', '/gadgets', 'get', 'responses'])['202'] = {
              'description': 'Accepted',
            },
            '#/paths/~1gadgets/get/responses/202',
            'unsupported response status "202"',
          ),
        ];

    for (final (name, change, path, reason) in cases) {
      test(name, () {
        final document = esiFixture();
        change(document);
        expect(
          const EsiSpecReader().read(document),
          isA<EsiSpecRefused>()
              .having((r) => r.path, 'path', path)
              .having((r) => r.reason, 'reason', reason),
        );
      });
    }
  });
}
