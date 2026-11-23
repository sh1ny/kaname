import 'dart:convert';

import 'package:kaname_esi/kaname_esi.dart';
import 'package:test/test.dart';

import 'exchanges.dart';

/// One asserted fact of a contract: what is checked, the value seen and
/// the exact expectation: a value or a [Matcher].
typedef ContractFact = (String what, Object? actual, Object? expected);

/// Calls the generated method of an exchange's operation over the
/// exchange's transport and returns the facts its test asserts.
typedef Contract = Future<List<ContractFact>> Function(Exchange exchange);

/// The wire form of an enum value, marking a value the pinned spec does
/// not list, so a known value turning unknown after a bump differs.
String wireOf(EsiEnum<EsiWireEnum> value) => switch (value) {
  EsiKnown(:final value) => value.wire,
  EsiUnknown(:final wire) => 'unknown "$wire"',
};

/// The body of a success, or the result itself to fail the comparison
/// against a body expectation.
Object? bodyOf(EsiResult<Object?> result) => switch (result) {
  EsiSuccess(:final body) => body,
  _ => result,
};

/// Asserts each fact of [exchange], naming its operation and the fact on a
/// difference.
void verifyContract(Exchange exchange, List<ContractFact> facts) {
  for (final (what, actual, expected) in facts) {
    expect(
      actual,
      expected,
      reason: '${exchange.operation} (${exchange.name}): $what',
    );
  }
}

TypeMatcher<EsiSuccess<Object?>> _success({int status = 200}) =>
    isA<EsiSuccess<Object?>>().having((r) => r.status, 'status', status);

Matcher _malformed(String path) => isA<EsiMalformed<Object?>>()
    .having((r) => r.status, 'status', 200)
    .having((r) => r.path, 'path', path);

const int _alliance = 99000001;
const int _pilot = 90000001;
const int _corporation = 98000001;

Future<List<ContractFact>> _allianceDetail(Exchange exchange) async {
  final result = await EsiClient(exchange.transport())
      .getAlliancesAllianceId(allianceId: _alliance);
  return switch (result) {
    EsiSuccess(:final body, :final etag, :final expires) => [
      ('result', result, _success()),
      ('etag', etag, '"kta-1"'),
      ('expires', expires, 'Thu, 19 Nov 2026 12:00:00 GMT'),
      ('creator_corporation_id', body.creatorCorporationId, _corporation),
      ('creator_id', body.creatorId, _pilot),
      ('date_founded', body.dateFounded, DateTime.utc(2010, 11, 4, 13, 11)),
      ('executor_corporation_id', body.executorCorporationId, _corporation),
      ('faction_id', body.factionId, isNull),
      ('name', body.name, 'Kaname Test Alliance'),
      ('ticker', body.ticker, 'KTA'),
    ],
    _ => [('result', result, _success())],
  };
}

Future<List<ContractFact>> _notifications(Exchange exchange) async {
  final result = await EsiClient(exchange.transport())
      .getCharactersCharacterIdNotifications(characterId: _pilot);
  return [
    ('result', result, _success()),
    (
      'items',
      switch (bodyOf(result)) {
        final List<CharactersCharacterIdNotificationsGetItem> items => [
          for (final item in items)
            (
              item.notificationId,
              item.senderId,
              wireOf(item.senderType),
              item.timestamp,
              wireOf(item.type),
              item.isRead,
              item.text,
            ),
        ],
        final other => other,
      },
      switch (exchange.name) {
        'conforming/notifications' => [
          (
            1,
            _corporation,
            'corporation',
            DateTime.utc(2026, 11, 19, 10),
            'AcceptedAlly',
            true,
            'kaname: synthetic',
          ),
          (
            2,
            _pilot,
            'character',
            DateTime.utc(2026, 11, 19, 11, 30),
            'AcceptedAlly',
            null,
            null,
          ),
        ],
        _ => [
          (
            3,
            _pilot,
            'character',
            DateTime.utc(2026, 11, 19, 12),
            'unknown "KanameSyntheticNotice"',
            null,
            null,
          ),
        ],
      },
    ),
  ];
}

Object? _runs(
  EsiOneOf<CharactersCosmeticsSkinrComponentsItemRuns> runs,
) => switch (runs) {
  EsiVariant(
    value: CharactersCosmeticsSkinrComponentsItemRunsRemaining(:final value),
  ) =>
    ('remaining', value),
  EsiVariant(
    value: CharactersCosmeticsSkinrComponentsItemRunsUnlimited(:final value),
  ) =>
    ('unlimited', value),
  EsiUnknownVariant(:final object) => ('unknown', jsonEncode(object)),
};

Future<List<ContractFact>> _skinComponents(Exchange exchange) async {
  final result = await EsiClient(exchange.transport())
      .getCharactersCosmeticsSkinrComponents(characterId: _pilot);
  if (exchange.name == 'negative/skin_components_wrong_payload') {
    return [
      (
        'malformed at path',
        result,
        _malformed(r'$.licenses[0].runs.remaining'),
      ),
    ];
  }
  return [
    ('result', result, _success()),
    (
      'licenses',
      switch (bodyOf(result)) {
        final CharactersCosmeticsSkinrComponents body => [
          for (final item in body.licenses)
            (item.componentId, _runs(item.runs), wireOf(item.type)),
        ],
        final other => other,
      },
      switch (exchange.name) {
        'conforming/skin_components' => [
          (7001, ('remaining', 3), 'nanocoating'),
          (7002, ('unlimited', true), 'nanocoating'),
        ],
        _ => [
          (
            7003,
            ('unknown', '{"seasonal":{"until":"2027-01-01"}}'),
            'nanocoating',
          ),
        ],
      },
    ),
  ];
}

/// Each exchange's contract, by exchange name.
final Map<String, Contract> contracts = {
  'conforming/alliance_detail': _allianceDetail,
  'forward/alliance_extra_field': (exchange) async => [
    for (final (what, actual, expected) in await _allianceDetail(exchange))
      if (what != 'etag' && what != 'expires') (what, actual, expected),
  ],
  'conforming/alliances': (exchange) async {
    final result = await EsiClient(exchange.transport()).getAlliances();
    return [
      ('result', result, _success()),
      ('body', bodyOf(result), [99000001, 99000002, 99000003]),
      (
        'etag',
        switch (result) {
          EsiSuccess(:final etag) => etag,
          _ => null,
        },
        '"list-1"',
      ),
    ];
  },
  'conforming/alliances_not_modified': (exchange) async {
    final transport = exchange.transport();
    final result = await EsiClient(transport)
        .getAlliances(ifNoneMatch: '"list-1"');
    return [
      (
        'not modified',
        result,
        isA<EsiNotModified<Object?>>()
            .having((r) => r.etag, 'etag', '"list-1"')
            .having(
              (r) => r.expires,
              'expires',
              'Thu, 19 Nov 2026 12:05:00 GMT',
            ),
      ),
      (
        'If-None-Match sent',
        transport.requests.single.headers['If-None-Match'],
        '"list-1"',
      ),
    ];
  },
  'conforming/alliance_not_found': (exchange) async => [
    (
      'error message',
      await EsiClient(exchange.transport())
          .getAlliancesAllianceId(allianceId: _alliance),
      isA<EsiError<Object?>>()
          .having((r) => r.status, 'status', 404)
          .having((r) => r.message, 'message', 'Alliance not found'),
    ),
  ],
  'conforming/notifications': _notifications,
  'forward/notifications_unlisted_type': _notifications,
  'conforming/skin_components': _skinComponents,
  'forward/skin_components_unlisted_runs': _skinComponents,
  'negative/skin_components_wrong_payload': _skinComponents,
  'conforming/assets_page': (exchange) async {
    final result = await EsiClient(exchange.transport())
        .getCharactersCharacterIdAssets(characterId: _pilot, page: 1);
    return [
      ('result', result, _success()),
      (
        'pages',
        switch (result) {
          EsiSuccess(:final pages) => pages,
          _ => null,
        },
        3,
      ),
      (
        'items',
        switch (bodyOf(result)) {
          final List<CharactersCharacterIdAssetsGetItem> items => [
            for (final item in items)
              (
                item.isSingleton,
                item.itemId,
                wireOf(item.locationFlag),
                item.locationId,
                wireOf(item.locationType),
                item.quantity,
                item.typeId,
              ),
          ],
          final other => other,
        },
        [(false, 1000000001, 'Hangar', 60000001, 'station', 5, 34)],
      ),
    ];
  },
  'conforming/contacts_deleted': (exchange) async {
    final transport = exchange.transport();
    final result = await EsiClient(transport)
        .deleteCharactersCharacterIdContacts(
          characterId: _pilot,
          contactIds: [_corporation],
        );
    return [
      ('no content', result, _success(status: 204)),
      ('request method', transport.requests.single.method, EsiMethod.delete),
    ];
  },
  'conforming/universe_names': (exchange) async {
    final transport = exchange.transport();
    final result = await EsiClient(transport)
        .postUniverseNames(body: [_pilot, _corporation]);
    final request = transport.requests.single;
    return [
      ('request method', request.method, EsiMethod.post),
      ('request target', '${request.target}', '/universe/names'),
      ('request body', utf8.decode(request.body!), '[90000001,98000001]'),
      (
        'request content type',
        request.headers['Content-Type'],
        'application/json',
      ),
      ('result', result, _success()),
      (
        'names',
        switch (bodyOf(result)) {
          final List<UniverseNamesPostItem> items => [
            for (final item in items)
              (wireOf(item.category), item.id, item.name),
          ],
          final other => other,
        },
        [
          ('character', _pilot, 'Kaname Pilot One'),
          ('corporation', _corporation, 'Kaname Test Corp'),
        ],
      ),
    ];
  },
  'conforming/freelance_cursor': (exchange) async {
    final transport = exchange.transport();
    final result = await EsiClient(transport)
        .getCorporationsFreelanceJobsListing(
          corporationId: _corporation,
          after: 'k+1/2=',
        );
    final target = transport.requests.single.target;
    return [
      (
        'request target',
        '$target',
        '/corporations/98000001/freelance-jobs?after=k%2B1%2F2%3D',
      ),
      ('cursor decoded once', target.queryParameters['after'], 'k+1/2='),
      (
        'result',
        result,
        isA<EsiError<Object?>>().having((r) => r.status, 'status', 503),
      ),
    ];
  },
  'negative/alliance_missing_name': (exchange) async => [
    (
      'malformed at path',
      await EsiClient(exchange.transport())
          .getAlliancesAllianceId(allianceId: _alliance),
      _malformed(r'$.name'),
    ),
  ],
  'negative/alliance_not_json': (exchange) async => [
    (
      'malformed at path',
      await EsiClient(exchange.transport())
          .getAlliancesAllianceId(allianceId: _alliance),
      _malformed(r'$'),
    ),
  ],
};

/// The constructs the contract tests must cover, inbound then outbound
/// (esi-client → Contract coverage), each with the fact that asserts it.
///
/// An exchange covers a construct only when it is tagged with it and its
/// contract returns that fact, so removing the asserting fact uncovers the
/// construct even while the exchange keeps its tag.
const Map<String, String> requiredConstructs = {
  'object': 'name',
  'array': 'items',
  'scalar-array': 'body',
  'oneof-variant': 'licenses',
  'unknown-enum': 'items',
  'unknown-variant': 'licenses',
  'no-content': 'no content',
  'not-modified': 'not modified',
  'error-body': 'error message',
  'malformed-body': 'malformed at path',
  'page-count': 'pages',
  'cursor': 'cursor decoded once',
  'request-body': 'request body',
};
