import 'dart:io';

import 'package:kaname_esi/kaname_esi.dart';
import 'package:test/test.dart';

import 'support/contracts.dart';
import 'support/exchanges.dart';
import 'support/fixture_transport.dart';

/// Runs [body] where opening any socket or HTTP client fails the test.
Future<T> _offline<T>(Future<T> Function() body) => HttpOverrides.runZoned(
  () => IOOverrides.runZoned(
    body,
    socketConnect: (host, port, {sourceAddress, sourcePort = 0, timeout}) =>
        fail('a socket to $host:$port was opened'),
    socketStartConnect: (host, port, {sourceAddress, sourcePort = 0}) =>
        fail('a socket to $host:$port was opened'),
  ),
  createHttpClient: (_) => fail('an HTTP client was created'),
);

void main() {
  group('Contract tests over recorded exchanges', () {
    for (final MapEntry(key: name, value: contract) in contracts.entries) {
      test(name, () async {
        final exchange = Exchange.load(name);
        verifyContract(exchange, await _offline(() => contract(exchange)));
      });
    }
  });

  test('decodes scheduler refusal without wire status', () async {
    final until = DateTime.utc(2026, 11, 24, 15);
    final result = await EsiClient(
      FixtureTransport(
        EsiTransportRefused(EsiRefusalReason.budget, retryAt: until),
      ),
    ).getAlliancesAllianceId(allianceId: 99000001);

    expect(
      result,
      isA<EsiNotSent<AlliancesDetail>>()
          .having((r) => r.refusal.reason, 'reason', EsiRefusalReason.budget)
          .having((r) => r.refusal.retryAt, 'retry deadline', until),
    );
  });

  test('preserves suppressed status separately', () async {
    for (final status in [403, 404]) {
      final result = await EsiClient(
        FixtureTransport(EsiTransportRefused.negativeCached(status)),
      ).getAlliancesAllianceId(allianceId: 99000001);
      expect(
        result,
        isA<EsiNotSent<AlliancesDetail>>()
            .having(
              (r) => r.refusal.reason,
              'reason',
              EsiRefusalReason.negativeCached,
            )
            .having((r) => r.refusal.suppressedStatus, 'cached status', status),
      );
    }
  });

  test('fixture transport answers and no connection is opened', () async {
    final exchange = Exchange.load('conforming/alliance_detail');
    final transport = exchange.transport();
    final result = await _offline(
      () => EsiClient(transport).getAlliancesAllianceId(allianceId: 99000001),
    );
    expect(transport.requests, hasLength(1));
    expect(
      result,
      isA<EsiSuccess<AlliancesDetail>>()
          .having((r) => r.body.ticker, 'ticker', 'KTA')
          .having((r) => r.etag, 'etag', '"kta-1"'),
    );
  });

  test('forward-compatibility notification type asserts the exact unknown '
      'string', () async {
    final exchange = Exchange.load('forward/notifications_unlisted_type');
    final result = await EsiClient(exchange.transport())
        .getCharactersCharacterIdNotifications(characterId: 90000001);
    expect(
      result,
      isA<EsiSuccess<List<CharactersCharacterIdNotificationsGetItem>>>().having(
        (r) => r.body.single.type,
        'type',
        isA<EsiUnknown<CharactersCharacterIdNotificationsGetItemType>>().having(
          (u) => u.wire,
          'wire',
          'KanameSyntheticNotice',
        ),
      ),
    );
  });

  test('a conforming exchange whose decoded case differs fails naming the '
      'operation', () async {
    final exchange = Exchange.load('conforming/notifications');
    final facts = await contracts[exchange.name]!(exchange);
    // A bump that dropped AcceptedAlly from the enum would decode it as
    // unknown; simulate that by asserting the unknown case instead.
    final bumped = [
      for (final (what, actual, expected) in facts)
        if (what == 'items')
          (
            what,
            actual,
            contains(
              predicate<Object?>(
                (item) => '$item'.contains('unknown "AcceptedAlly"'),
                'an item whose type decoded as unknown "AcceptedAlly"',
              ),
            ),
          )
        else
          (what, actual, expected),
    ];
    expect(
      () => verifyContract(exchange, bumped),
      throwsA(
        isA<TestFailure>().having(
          (f) => f.message,
          'message',
          allOf(
            contains('GetCharactersCharacterIdNotifications'),
            contains('items'),
          ),
        ),
      ),
    );
  });
}
