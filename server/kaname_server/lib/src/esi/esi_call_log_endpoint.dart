import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'esi_call_log_store.dart'
    show EsiCallLogDenied, EsiCallLogStore, EsiCallLogViewer;
import 'sso_sessions.dart';

/// Viewer-only receipts and fixed-window totals. Callers cannot choose a viewer.
final class EsiCallLogEndpoint extends Endpoint {
  static final _readers = Expando<EsiCallLogReads>();

  /// Returns the current viewer's bounded page after an optional keyset cursor.
  Future<EsiCallLogPage> ownRows(Session session, EsiCallLogCursor? after) =>
      (_readers[session.serverpod] ??= EsiCallLogReads(
        EsiCallLogStore(),
      )).own(session, after);

  /// Returns released totals only to an authenticated admin.
  Future<EsiRouteCountPage> routeCounts(Session session) =>
      (_readers[session.serverpod] ??= EsiCallLogReads(
        EsiCallLogStore(),
      )).totals(session);
}

/// Per-server admission and one cached result for the current release window.
final class EsiCallLogReads {
  /// Uses the same release boundary for the query and for cache admission.
  EsiCallLogReads(this._store);

  final EsiCallLogStore _store;
  final _reading = <int>{};
  ({DateTime window, EsiRouteCountPage page})? _cached;
  ({DateTime window, Future<EsiRouteCountPage> page})? _computing;
  static final _sessions = SsoSessions(now: DateTime.now);
  static final _number = RegExp(r'^[1-9][0-9]{0,18}$');

  static int? _id(String value) =>
      _number.hasMatch(value) ? int.tryParse(value, radix: 10) : null;

  static Future<EsiCallLogViewer?> _viewer(
    Session session,
    int member,
    String authId,
    bool admin,
  ) async {
    final id = _id(authId);
    if (id == null) return null;
    final current = await _sessions.viewerById(session, id, member);
    return current == null
        ? null
        : EsiCallLogViewer(
            member: member,
            characters: {current.identity.characterId},
            admin: admin,
          );
  }

  /// Admits no more than one read per viewer and four per server.
  Future<EsiCallLogPage> own(Session session, EsiCallLogCursor? after) async {
    EsiCallLogPage failure(String status) =>
        EsiCallLogPage(status: status, rows: []);
    final auth = session.authenticated;
    final member = auth == null ? null : _id(auth.userIdentifier);
    if (member == null) return failure('denied');
    final cursorId = after == null ? null : _id(after.id);
    if (after != null && cursorId == null) return failure('denied');
    if (_reading.length >= 4 || !_reading.add(member)) return failure('busy');
    try {
      final viewer = await _viewer(
        session,
        member,
        auth!.authId,
        auth.scopes.contains(Scope.admin),
      );
      final rows = await _store.ownRows(
        session,
        viewer,
        after: after == null
            ? null
            : (recordedAt: after.recordedAt.toUtc(), id: cursorId!),
      );
      final receipts = [
        for (final row in rows)
          EsiCallLogReceipt(
            cursor: EsiCallLogCursor(
              recordedAt: row.cursor.recordedAt,
              id: row.cursor.id.toString(),
            ),
            recordedAt: row.recordedAt,
            characterId: row.character.toString(),
            operation: row.operation,
            bucket: row.bucket,
            outcome: row.outcome.name,
            status: row.status,
            cost: row.cost,
            latencyMicros: row.latency.inMicroseconds,
          ),
      ];
      return EsiCallLogPage(
        status: 'ok',
        rows: receipts,
        next: receipts.length == 100 ? receipts.last.cursor : null,
      );
    } on EsiCallLogDenied {
      return failure('denied');
    } on Object {
      return failure('unavailable');
    } finally {
      _reading.remove(member);
    }
  }

  /// Joins an admitted, successful aggregate calculation for this release.
  Future<EsiRouteCountPage> totals(Session session) async {
    EsiRouteCountPage failure(String status) =>
        EsiRouteCountPage(status: status, rows: []);
    final auth = session.authenticated;
    if (auth == null || !auth.scopes.contains(Scope.admin)) {
      return failure('denied');
    }
    final member = _id(auth.userIdentifier);
    if (member == null) return failure('denied');
    if (_reading.length >= 4 || !_reading.add(member)) return failure('busy');
    try {
      final viewer = await _viewer(session, member, auth.authId, true);
      if (viewer == null) return failure('denied');
      final window = _store.releasedWindow;
      final cached = _cached;
      if (cached?.window == window) return cached!.page;
      final active = _computing;
      if (active?.window == window) return await active!.page;
      final future = _compute(session, viewer);
      _computing = (window: window, page: future);
      try {
        return await future;
      } finally {
        if (identical(_computing?.page, future)) _computing = null;
      }
    } on EsiCallLogDenied {
      return failure('denied');
    } on Object {
      return failure('unavailable');
    } finally {
      _reading.remove(member);
    }
  }

  Future<EsiRouteCountPage> _compute(
    Session session,
    EsiCallLogViewer viewer,
  ) async {
    final computed = await _store.routeCountsWithWindow(session, viewer);
    final page = EsiRouteCountPage(
      status: 'ok',
      rows: List.unmodifiable([
        for (final row in computed.rows)
          EsiRouteCount(
            operation: row.operation,
            total: row.total,
            errors: row.errors,
          ),
      ]),
    );
    if (_store.releasedWindow == computed.window) {
      _cached = (window: computed.window, page: page);
    }
    return page;
  }
}
