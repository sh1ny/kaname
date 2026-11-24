import 'dart:async';
import 'dart:convert';

import 'package:kaname_esi_vault/kaname_esi_vault.dart';
import 'package:test/test.dart';

const _server = (kind: VaultHolderKind.server, id: 'server-a');
const _device = (kind: VaultHolderKind.device, id: 'native-a');
const _r0 = 'fixture-refresh-original';
const _r1 = 'fixture-refresh-rotated';
const _r2 = 'fixture-refresh-newer';

void main() {
  group('ESI token vault', () {
    late _Harness h;
    setUp(() => h = _Harness());
    tearDown(() => h.close());

    test('park invalidates the old holder before another activates', () async {
      final old = await h.install(bearer: h.fresh('old'));
      final refused = await h.vault.activate(
        character: 42,
        holder: _device,
        expectedGeneration: old.generation,
        refreshToken: _r1,
      );
      expect(refused, _failure(VaultFailureReason.notHolder));
      final parked = _success(await h.vault.park(old));
      final next = await h.install(
        holder: _device,
        generation: parked.generation,
        bearer: h.fresh('new'),
      );
      expect(
        await h.vault.readBearer(old),
        _failure(VaultFailureReason.notHolder),
      );
      expect(_success(await h.vault.readBearer(next)).token, 'new');
    });

    test('non-holder and missing authority never exchange', () async {
      final auth = await h.install();
      final device = (
        character: auth.character,
        holder: _device,
        generation: auth.generation,
      );
      expect(
        await h.vault.bearer(device),
        _failure(VaultFailureReason.notHolder),
      );
      h.store.readError = StateError('unreachable');
      expect(
        await h.vault.bearer(auth),
        _failure(VaultFailureReason.unavailable),
      );
      expect(h.exchange.calls, isEmpty);
    });

    test('reauthorization fences old handles', () async {
      final old = await h.install();
      final next = await h.install(
        generation: old.generation,
        bearer: h.fresh('current'),
      );
      expect(await h.vault.bearer(old), _failure(VaultFailureReason.notHolder));
      expect(await h.vault.park(old), _failure(VaultFailureReason.notHolder));
      expect(_success(await h.vault.readBearer(next)).token, 'current');
      expect(h.exchange.calls, isEmpty);
    });

    test('bad key fails closed before reading the store', () {
      const secretInError = 'bad-secret-text';
      for (final key in [
        null,
        secretInError,
        base64Encode(List.filled(31, 7)),
      ]) {
        expect(
          () => h.make(key: key),
          throwsA(
            isA<VaultKeyConfigurationException>().having(
              (error) => error.toString(),
              'diagnostic',
              isNot(contains(secretInError)),
            ),
          ),
        );
      }
      expect(h.store.reads, 0);
      expect(h.exchange.calls, isEmpty);
    });

    test(
      'wrong key tampering and cross-authorization copies are unavailable',
      () async {
        final old = await h.install();
        final copied = h.store.rows[42]!.sealedCredential!;
        final next = await h.install(generation: old.generation);
        final other = await h.install(character: 43, holder: _device);
        final valid = h.store.rows[42]!.sealedCredential!;
        expect(
          await h.make(key: base64Encode(List.filled(32, 17))).bearer(next),
          _failure(VaultFailureReason.unavailable),
        );
        h.store.replaceEnvelope(42, copied);
        expect(
          await h.vault.bearer(next),
          _failure(VaultFailureReason.unavailable),
        );
        h.store.replaceEnvelope(43, valid);
        expect(
          await h.vault.bearer(other),
          _failure(VaultFailureReason.unavailable),
        );
        final tampered = base64Decode(valid);
        tampered[tampered.length - 1] ^= 1;
        h.store.replaceEnvelope(42, base64Encode(tampered));
        expect(
          await h.vault.bearer(next),
          _failure(VaultFailureReason.unavailable),
        );
        expect(_success(await h.vault.inspect(42))?.status, VaultStatus.active);
        expect(h.exchange.calls, isEmpty);
      },
    );

    test(
      'dependency failures keep secrets out of results and diagnostics',
      () async {
        final auth = await h.install();
        final lines = <String>[];
        final thrown = StateError('upstream body with $_r0 and ${h.key}');
        await runZoned(
          () async {
            final result = h.vault.bearer(auth);
            (await h.exchange.next()).reply.completeError(thrown);
            final unavailable = await result;
            expect(unavailable, _failure(VaultFailureReason.unavailable));
            lines.add('$unavailable');
            h.store.readError = thrown;
            final storeError = await h.vault.readBearer(auth);
            expect(storeError, _failure(VaultFailureReason.unavailable));
            lines.add('$storeError');
          },
          zoneSpecification: ZoneSpecification(
            print: (_, _, _, line) => lines.add(line),
          ),
        );
        expect(lines.join('\n'), isNot(contains(_r0)));
        expect(lines.join('\n'), isNot(contains(h.key)));
        expect(lines.join('\n'), isNot(contains('upstream body')));
      },
    );

    test('same character waits for a committed rotation without duplicate exchange', () async {
      final auth = await h.install();
      final leader = h.vault.bearer(auth);
      final request = await h.exchange.next();
      expect(
        await h.make(key: h.key).bearer(auth),
        _failure(VaultFailureReason.busy),
      );
      final ready = Completer<void>();
      final commit = Completer<void>();
      addTearDown(() {
        if (!commit.isCompleted) commit.complete();
      });
      h.store.beforeWrite = () async {
        ready.complete();
        await commit.future;
      };
      request.reply.complete(h.success('first', _r1));
      await ready.future;
      expect(
        await h.vault.readBearer(auth),
        _failure(VaultFailureReason.refreshRequired),
      );
      expect(h.exchange.calls, [_r0]);
      commit.complete();
      expect(_success(await leader).token, 'first');
      expect(_success(await h.make(key: h.key).bearer(auth)).token, 'first');
      expect(h.exchange.calls, [_r0]);
    });

    test('dispatch threshold refuses and refreshes near expiry', () async {
      final auth = await h.install(bearer: h.fresh('old'));
      h.advance(55);
      expect(
        await h.vault.readBearer(auth),
        _failure(VaultFailureReason.refreshRequired),
      );
      final result = h.vault.bearer(auth);
      (await h.exchange.next()).reply.complete(h.success('fresh', _r1));
      expect(_success(await result).token, 'fresh');
    });

    test(
      'pre-refresh has more expiry headroom than read-only dispatch',
      () async {
        final auth = await h.install(bearer: h.fresh('old'));
        h.advance(44);
        expect(_success(await h.vault.bearer(auth)).token, 'old');
        h.advance(1);
        expect(_success(await h.vault.readBearer(auth)).token, 'old');
        final result = h.vault.bearer(auth);
        (await h.exchange.next()).reply.complete(h.success('fresh', _r1));
        expect(_success(await result).token, 'fresh');
        expect(h.exchange.calls, [_r0]);
      },
    );

    test('lease expires exactly at its deadline', () async {
      final auth = await h.install();
      final blocked = h.vault.bearer(auth);
      final abandoned = await h.exchange.next();
      h.advance(29);
      expect(await h.vault.bearer(auth), _failure(VaultFailureReason.busy));
      h.advance(1);
      final next = h.vault.bearer(auth);
      (await h.exchange.next()).reply.complete(h.success('next', _r1));
      expect(_success(await next).token, 'next');
      expect(h.exchange.calls, [_r0, _r0]);
      abandoned.reply.complete(const VaultRefreshTemporaryFailure());
      await blocked;
    });

    test('independent characters complete out of order', () async {
      final first = await h.install();
      final second = await h.install(character: 43, refresh: _r1);
      final blocked = h.vault.bearer(first);
      final holding = await h.exchange.next();
      final next = h.vault.bearer(second);
      (await h.exchange.next()).reply.complete(h.success('second', _r2));
      expect(_success(await next).token, 'second');
      holding.reply.complete(h.success('first', _r1));
      expect(_success(await blocked).token, 'first');
      expect(h.exchange.calls, [_r0, _r1]);
    });

    test(
      'lost commit acknowledgement never releases an unconfirmed bearer',
      () async {
        final auth = await h.install();
        final result = h.vault.bearer(auth);
        final attempt = await h.exchange.next();
        h.store.afterWrite = () => throw StateError('lost acknowledgement');
        attempt.reply.complete(h.success('committed', _r1));
        expect(await result, _failure(VaultFailureReason.unavailable));
        expect(
          _success(await h.make(key: h.key).readBearer(auth)).token,
          'committed',
        );
        expect(h.exchange.calls, [_r0]);
      },
    );

    test('superseded success preserves rotation without publishing bearer or replacing lease', () async {
      final auth = await h.install();
      final (older, first, newer, second) = await h.overlap(auth);
      final live = h.store.rows[42]!;
      first.reply.complete(h.success('not-for-use', _r1));
      expect(await older, _failure(VaultFailureReason.unavailable));
      expect(
        await h.vault.readBearer(auth),
        _failure(VaultFailureReason.refreshRequired),
      );
      final salvaged = h.store.rows[42]!;
      expect(salvaged.sealedCredential, isNot(live.sealedCredential));
      expect(
        (salvaged.fence, salvaged.leaseUntil),
        (live.fence, live.leaseUntil),
      );
      expect(await h.vault.bearer(auth), _failure(VaultFailureReason.busy));
      second.reply.complete(const VaultRefreshTemporaryFailure());
      await newer;
      final next = h.vault.bearer(auth);
      (await h.exchange.next()).reply.complete(h.success('from-salvage', _r2));
      expect(_success(await next).token, 'from-salvage');
      expect(h.exchange.calls, [_r0, _r0, _r1]);
    });

    test(
      'late success cannot overwrite a new refresh token or authorization',
      () async {
        final auth = await h.install();
        final (older, first, newer, second) = await h.overlap(auth);
        second.reply.complete(h.success('newer', _r2));
        expect(_success(await newer).token, 'newer');
        first.reply.complete(h.success('old', _r1));
        expect(await older, _failure(VaultFailureReason.unavailable));
        expect(_success(await h.vault.readBearer(auth)).token, 'newer');
        h.advance(60);
        final displaced = h.vault.bearer(auth);
        final request = await h.exchange.next();
        h.advance(30);
        final replacement = await h.install(
          generation: auth.generation,
          bearer: h.fresh('reauth'),
        );
        request.reply.complete(h.success('stale', _r1));
        expect(await displaced, isA<VaultFailure<VaultBearer>>());
        expect(_success(await h.vault.readBearer(replacement)).token, 'reauth');
        expect(h.exchange.calls, [_r0, _r0, _r2]);
      },
    );

    test(
      'current invalid grant retries an actual salvaged rotation once',
      () async {
        final auth = await h.install();
        final newer = await h.salvageWhileRejecting(auth);
        (await h.exchange.next()).reply.complete(
          h.success('after-recovery', _r2),
        );
        expect(_success(await newer.result).token, 'after-recovery');
        expect(h.exchange.calls, [_r0, _r0, _r1]);
      },
    );

    test('lost rotation requires new login and is never retried', () async {
      final auth = await h.install();
      final result = h.vault.bearer(auth);
      final attempt = await h.exchange.next();
      h.store.beforeWrite = () => throw StateError('crashed before commit');
      attempt.reply.complete(h.success('lost', _r1));
      expect(await result, _failure(VaultFailureReason.unavailable));
      h.advance(30);
      final restarted = h.make(key: h.key);
      final afterRestart = restarted.bearer(auth);
      (await h.exchange.next()).reply.complete(
        const VaultRefreshInvalidGrant(),
      );
      expect(await afterRestart, _failure(VaultFailureReason.reLoginRequired));
      expect(
        await restarted.bearer(auth),
        _failure(VaultFailureReason.reLoginRequired),
      );
      expect(h.store.rows[42]!.sealedCredential, isNull);
      expect(h.exchange.calls, [_r0, _r0]);
      final next = await h.install(
        generation: auth.generation,
        bearer: h.fresh('login'),
      );
      expect(_success(await restarted.readBearer(next)).token, 'login');
    });

    test('second invalid grant marks the current token dead', () async {
      final auth = await h.install();
      final newer = await h.salvageWhileRejecting(auth);
      (await h.exchange.next()).reply.complete(
        const VaultRefreshInvalidGrant(),
      );
      expect(await newer.result, _failure(VaultFailureReason.reLoginRequired));
      expect(
        await h.vault.bearer(auth),
        _failure(VaultFailureReason.reLoginRequired),
      );
      expect(h.exchange.calls, [_r0, _r0, _r1]);
    });

    test(
      'a superseded invalid grant cannot retry or kill the current grant',
      () async {
        final auth = await h.install();
        final (older, first, newer, second) = await h.overlap(auth);
        second.reply.complete(h.success('current', _r2));
        expect(_success(await newer).token, 'current');
        first.reply.complete(const VaultRefreshInvalidGrant());
        expect(await older, _failure(VaultFailureReason.unavailable));
        expect(_success(await h.vault.bearer(auth)).token, 'current');
        expect(h.exchange.calls, [_r0, _r0]);
      },
    );

    test('temporary exchange failure keeps the grant usable', () async {
      final auth = await h.install();
      final first = h.vault.bearer(auth);
      (await h.exchange.next()).reply.complete(
        const VaultRefreshTemporaryFailure(),
      );
      expect(await first, _failure(VaultFailureReason.unavailable));
      final next = h.vault.bearer(auth);
      (await h.exchange.next()).reply.complete(h.success('retry', null));
      expect(_success(await next).token, 'retry');
      expect(h.exchange.calls, [_r0, _r0]);
    });
  }, timeout: const Timeout(Duration(minutes: 2)));
}

T _success<T>(VaultResult<T> result) => switch (result) {
  VaultSuccess(:final value) => value,
  VaultFailure(:final reason) => fail('Expected success, got $reason'),
};

Matcher _failure(VaultFailureReason reason) => isA<VaultFailure<Object?>>()
    .having((result) => result.reason, 'reason', reason);

final class _Store implements VaultStore {
  final rows = <int, VaultRecord>{};
  final _locks = <int, Completer<void>>{};
  int reads = 0;
  Object? readError;
  FutureOr<void> Function()? beforeWrite;
  void Function()? afterWrite;

  @override
  Future<VaultRecord?> read(int character) async {
    reads++;
    if (readError case final error?) throw error;
    return rows[character];
  }

  @override
  Future<T?> withCharacter<T extends Object>(
    int character, {
    required bool wait,
    required Future<VaultWrite<T>> Function(VaultRecord?) update,
  }) async {
    while (_locks.containsKey(character)) {
      if (!wait) return null;
      await _locks[character]!.future;
    }
    final lock = _locks[character] = Completer<void>();
    try {
      final (value: value, :next) = await update(rows[character]);
      if (next != null) {
        final before = beforeWrite;
        beforeWrite = null;
        if (before != null) await before();
        rows[character] = next;
        final after = afterWrite;
        afterWrite = null;
        after?.call();
      }
      return value;
    } finally {
      _locks.remove(character);
      lock.complete();
    }
  }

  void replaceEnvelope(int character, String ciphertext) {
    final old = rows[character]!;
    rows[character] = VaultRecord(
      authorization: old.authorization,
      status: old.status,
      sealedCredential: ciphertext,
      fence: old.fence,
      leaseUntil: old.leaseUntil,
    );
  }
}

final class _Request {
  final reply = Completer<VaultRefreshReply>();
}

final class _Exchange {
  final calls = <String>[];
  final _pending = <_Request>[];
  final _requests = StreamController<_Request>();
  late final _iterator = StreamIterator(_requests.stream);

  Future<VaultRefreshReply> call(String input) {
    calls.add(input);
    final request = _Request();
    _pending.add(request);
    _requests.add(request);
    return request.reply.future;
  }

  Future<_Request> next() async {
    if (!await _iterator.moveNext()) fail('Missing upstream exchange');
    return _iterator.current;
  }

  Future<void> close() async {
    for (final request in _pending) {
      if (!request.reply.isCompleted) {
        request.reply.complete(const VaultRefreshTemporaryFailure());
      }
    }
    await _iterator.cancel();
    unawaited(_requests.close());
  }
}

final class _Harness {
  final store = _Store();
  final exchange = _Exchange();
  final key = base64Encode(List.filled(32, 7));
  DateTime now = DateTime.utc(2026, 1, 1);
  late final vault = make(key: key);

  EsiTokenVault make({required String? key}) => EsiTokenVault(
    store: store,
    base64Key: key,
    refresh: exchange.call,
    now: () => now,
  );

  Future<VaultAuthorization> install({
    int character = 42,
    VaultHolder holder = _server,
    int generation = 0,
    String refresh = _r0,
    VaultBearer? bearer,
  }) async => _success(
    await vault.activate(
      character: character,
      holder: holder,
      expectedGeneration: generation,
      refreshToken: refresh,
      bearer: bearer,
    ),
  );

  VaultBearer fresh(String token) =>
      VaultBearer(token, now.add(const Duration(minutes: 1)));

  VaultRefreshSuccess success(String token, String? replacement) =>
      VaultRefreshSuccess(fresh(token), replacementRefreshToken: replacement);

  void advance(int seconds) => now = now.add(Duration(seconds: seconds));

  Future<
    (
      Future<VaultResult<VaultBearer>>,
      _Request,
      Future<VaultResult<VaultBearer>>,
      _Request,
    )
  >
  overlap(VaultAuthorization auth) async {
    final older = vault.bearer(auth);
    final first = await exchange.next();
    advance(30);
    final newer = vault.bearer(auth);
    final second = await exchange.next();
    return (older, first, newer, second);
  }

  Future<({Future<VaultResult<VaultBearer>> result})> salvageWhileRejecting(
    VaultAuthorization auth,
  ) async {
    final (older, first, newer, second) = await overlap(auth);
    first.reply.complete(success('unpublished', _r1));
    expect(await older, _failure(VaultFailureReason.unavailable));
    second.reply.complete(const VaultRefreshInvalidGrant());
    return (result: newer);
  }

  Future<void> close() => exchange.close();
}
