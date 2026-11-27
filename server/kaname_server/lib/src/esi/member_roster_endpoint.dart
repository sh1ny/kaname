import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'member_account_endpoint.dart' show memberWireId;
import 'sso_sessions.dart';

/// Bounded roster RPC. A separate endpoint lets HTTP ingress match both the
/// generated client's body-method route and Serverpod's slash route.
final class MemberRosterEndpoint extends Endpoint {
  final _reading = <int>{};

  @override
  bool get requireLogin => true;

  /// Reads one page and both roles from the same live-session snapshot.
  Future<MemberRosterPage> page(Session session, String? after) async {
    final auth = session.authenticated;
    final sessions = SsoSessions.forPod(session.serverpod);
    final account = auth == null ? null : memberWireId(auth.userIdentifier);
    final id = auth == null ? null : memberWireId(auth.authId);
    final cursor = after == null ? null : memberWireId(after);
    if (sessions == null ||
        account == null ||
        id == null ||
        (after != null && cursor == null)) {
      return _failure(MemberRosterStatus.denied);
    }
    if (!_reading.add(account)) return _failure(MemberRosterStatus.busy);
    try {
      return await session.db.transaction(
        (tx) async {
          await session.db.unsafeExecute(
            "SET LOCAL statement_timeout = '10s'",
            transaction: tx,
          );
          final viewer = await sessions.viewerById(
            session,
            id,
            account,
            transaction: tx,
          );
          if (viewer == null) return _failure(MemberRosterStatus.denied);
          final stored = await MemberAccountRow.db.findById(
            session,
            account,
            transaction: tx,
          );
          if (stored == null) return _failure(MemberRosterStatus.unavailable);
          final main = viewer.identity.id == stored.mainIdentityId
              ? viewer.identity
              : await SsoIdentityRow.db.findById(
                  session,
                  stored.mainIdentityId,
                  transaction: tx,
                );
          if (main?.accountId != account) {
            return _failure(MemberRosterStatus.unavailable);
          }
          final rows = await SsoIdentityRow.db.find(
            session,
            where: (t) =>
                t.accountId.equals(account) & (t.characterId > (cursor ?? 0)),
            orderBy: (t) => t.characterId,
            limit: 51,
            transaction: tx,
          );
          return MemberRosterPage(
            status: MemberRosterStatus.ok,
            accountId: account.toString(),
            main: _project(main!),
            signing: _project(viewer.identity),
            characters: [for (final row in rows.take(50)) _project(row)],
            next: rows.length == 51 ? rows[49].characterId.toString() : null,
          );
        },
        settings: const TransactionSettings(
          isolationLevel: IsolationLevel.repeatableRead,
        ),
      );
    } on Exception {
      return _failure(MemberRosterStatus.unavailable);
    } finally {
      _reading.remove(account);
    }
  }

  static MemberRosterPage _failure(MemberRosterStatus status) =>
      MemberRosterPage(status: status, characters: []);

  static MemberCharacter _project(SsoIdentityRow identity) => MemberCharacter(
    characterId: identity.characterId.toString(),
    name: identity.characterName,
    blocked: identity.blocked,
  );
}

/// Reserves a server-wide slot before Serverpod begins bearer DB lookup.
final class MemberRosterIngress {
  static const _envelopeSize = 2048;
  static const _envelopeTime = Duration(seconds: 10);

  int _active = 0;

  /// Shares one slot across bearer authentication and page work.
  Middleware get middleware =>
      (next) => (request) async {
        // Serverpod joins decoded segments before splitting endpoint and method.
        final first = request.url.pathSegments.firstOrNull;
        if (first == null ||
            first != 'memberRoster' && !first.startsWith('memberRoster/')) {
          return next(request);
        }
        final validated = await _validate(request);
        if (validated == null) return _rejected(400, 'badRequest');
        if (_active == 4) return _rejected(429, 'busy');
        ++_active;
        try {
          return await next(
            request.copyWith(
              body: Body.fromData(validated, mimeType: MimeType.json),
            ),
          );
        } finally {
          --_active;
        }
      };

  static Future<Uint8List?> _validate(Request request) async {
    // Serverpod's generated web client sends JSON as text/plain.
    final mediaType = request.headers['content-type']?.singleOrNull
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    if (request.method != Method.post ||
        (mediaType != 'application/json' && mediaType != 'text/plain') ||
        request.url.query.length > _envelopeSize) {
      return null;
    }
    final path = request.url.pathSegments.join('/');
    if (path != 'memberRoster' && path != 'memberRoster/page') return null;
    final body = await _readEnvelope(request);
    if (body == null) return null;
    try {
      final Object? decoded = body.isEmpty
          ? <String, Object?>{}
          : jsonDecode(utf8.decode(body));
      if (decoded is! Map<String, Object?> ||
          decoded.keys.any((key) => key != 'method' && key != 'after')) {
        return null;
      }
      for (final entry in request.url.queryParametersAll.entries) {
        if ((entry.key != 'method' && entry.key != 'after') ||
            entry.value.length != 1) {
          return null;
        }
        decoded[entry.key] = entry.value.single;
      }
      final method = decoded['method'];
      if (method != 'page' && (method != null || path == 'memberRoster')) {
        return null;
      }
      final after = decoded['after'];
      if (after != null && (after is! String || memberWireId(after) == null)) {
        return null;
      }
      return body;
    } on FormatException {
      return null;
    }
  }

  static Future<Uint8List?> _readEnvelope(Request request) async {
    try {
      final input = StreamIterator(request.read(maxLength: _envelopeSize));
      final budget = Stopwatch()..start();
      final body = BytesBuilder(copy: false);
      try {
        while (await input.moveNext().timeout(_envelopeTime - budget.elapsed)) {
          body.add(input.current);
        }
        return body.takeBytes();
      } finally {
        await input.cancel();
      }
    } on Exception {
      return null;
    }
  }

  static Response _rejected(int status, String outcome) => Response(
    status,
    body: Body.fromString('{"status":"$outcome"}', mimeType: MimeType.json),
    headers: Headers.build((headers) {
      headers['cache-control'] = ['no-store'];
    }),
  );
}
