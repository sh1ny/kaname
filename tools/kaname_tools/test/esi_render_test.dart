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

Map<String, String> _render(Object? document) =>
    switch (renderEsiClient(_read(document), date: esiFixtureDate)) {
      EsiRendered(:final files) => {
        for (final MapEntry(:key, :value) in files.entries)
          key.replaceFirst('$esiGeneratedDirectory/', ''): value,
      },
      EsiRenderRefused(:final reason) => fail('expected files: $reason'),
    };

Map<String, Object?> _map(Object? value) => value! as Map<String, Object?>;

/// Matches generated text containing [snippet], ignoring whitespace and
/// trailing commas, so the formatter's line breaks do not matter.
Matcher _has(String snippet) => predicate<String?>(
  (text) => text != null && _squash(text).contains(_squash(snippet)),
  'contains "$snippet", ignoring layout',
);

String _squash(String text) => text
    .replaceAll(RegExp(r'\s+'), '')
    .replaceAllMapped(RegExp(r',([)\]}])'), (m) => m[1]!);

void main() {
  group('the fixture', () {
    final files = _render(esiFixture());

    test('renders the pin, the catalogue, models and clients per tag', () {
      expect(files.keys.toList()..sort(), [
        'catalogue.dart',
        'esi.dart',
        'gadgets_client.dart',
        '$esiGeneratedTestDirectory/operations_test.dart',
        'pin.dart',
        'widgets_client.dart',
        'widgets_models.dart',
      ]);
      expect(files['esi.dart'], _has("export 'widgets_client.dart';"));
      expect(files['pin.dart'], _has("esiCompatibilityDate = '2030-01-02'"));
      expect(files['pin.dart'], _has('enum EsiLanguage implements'));
    });

    test('required parameter left out: it renders as a required argument', () {
      final client = files['widgets_client.dart']!;
      expect(client, _has('extension WidgetsCalls on EsiClient'));
      expect(client, _has('required int widgetId'));
      expect(client, _has('EsiLanguage? acceptLanguage'));
      expect(client, _has('String? ifNoneMatch'));
      expect(client, _has(r'${EsiCall.segment(widgetId)}'));
    });

    test('renders an operation without a body as returning void', () {
      final client = files['widgets_client.dart']!;
      expect(client, _has('Future<EsiResult<void>> deleteWidgetsWidgetId('));
      expect(client, _has('read: EsiJson.ignore'));
    });

    test('checks bounds and keeps unexploded query arrays', () {
      final client = files['widgets_client.dart']!;
      expect(client, _has('EsiCheck.range(v, p, minimum: 1)'));
      expect(client, _has('explode: false'));
      expect(client, _has('minItems: 1, maxItems: 2'));
      final gadgets = files['gadgets_client.dart']!;
      expect(gadgets, _has('required List<int> body'));
      expect(gadgets, _has('minItems: 1, maxItems: 10, unique: true'));
    });

    test('renders a model class whose required fields are non-null', () {
      final models = files['widgets_models.dart']!;
      expect(models, _has('final class Widget {'));
      expect(models, _has('final int widgetId;'));
      expect(models, _has('final String name;'));
      expect(models, _has('final DateTime? created;'));
      expect(models, _has('final bool? active;'));
      expect(models, _has('final Object? extra;'));
      expect(models, _has('final Map<String, String>? labels;'));
      expect(models, _has('final List<String>? tags;'));
      expect(models, _has('static Widget fromJson(Object? json'));
    });

    test('renders a string enum as EsiEnum over a wire enum', () {
      final models = files['widgets_models.dart']!;
      expect(models, _has('enum WidgetKind implements EsiWireEnum'));
      expect(models, _has('final EsiEnum<WidgetKind> kind;'));
    });

    test('renders oneOf as EsiOneOf with a class per listed variant', () {
      final models = files['widgets_models.dart']!;
      expect(models, _has('sealed class Price {'));
      expect(models, _has('final class PriceIsk extends Price'));
      expect(models, _has('final class PriceTokens extends Price'));
      expect(models, _has('final EsiOneOf<Price>? price;'));
      expect(models, _has('EsiUnknownVariant<Price>(object)'));
    });

    test('renders the catalogue with every route under both keys', () {
      final catalogue = files['catalogue.dart']!;
      expect(catalogue, _has("'GetWidgets': _getWidgets"));
      expect(catalogue, _has("'DELETE /widgets/{widget_id}'"));
      expect(catalogue, _has('pagination: EsiPagination.pages'));
      expect(catalogue, _has('pagination: EsiPagination.cursor'));
      expect(catalogue, _has("name: 'widget-write'"));
      expect(catalogue, _has("roles: ['Director']"));
    });

    test('renders the same text twice', () {
      expect(_render(esiFixture()), files);
    });
  });

  test('a name collision fails, naming both sources', () {
    final document = esiFixture();
    final schemas = _map(_map(document['components'])['schemas']);
    schemas['PriceIsk'] = {
      'type': 'object',
      'properties': {
        'amount': {'type': 'number'},
      },
    };
    _map(_map(schemas['Widget'])['properties'])['isk_price'] = {
      r'$ref': '#/components/schemas/PriceIsk',
    };
    final result = renderEsiClient(_read(document), date: esiFixtureDate);
    expect(
      result,
      isA<EsiRenderRefused>().having(
        (r) => r.reason,
        'reason',
        allOf(
          contains('PriceIsk'),
          contains('#/components/schemas/Price/oneOf/0'),
          contains('#/components/schemas/PriceIsk'),
        ),
      ),
    );
  });
}
