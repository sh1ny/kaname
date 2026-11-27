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
  /// Uses the same durable release boundary for query and response admission.
  /// [readSeal] defaults to a fresh read from the store.
  /// [beforeAggregate] lets tests hold a calculation and observe a waiter
  /// joining it without a timing assumption.
  EsiCallLogReads(
    this._store, {
    Future<DateTime?> Function(Session)? readSeal,
    this._beforeAggregate,
  }) : _readSeal = readSeal ?? _store.currentSeal;

  final EsiCallLogStore _store;
  final Future<DateTime?> Function(Session) _readSeal;
  final Future<void> Function({required bool joining})? _beforeAggregate;
  final _reading = <int>{};
  ({DateTime window, EsiRouteCountPage page})? _cached;
  ({DateTime window, Future<EsiRouteCountPage> page})? _computing;
  static final _number = RegExp(r'^[1-9][0-9]{0,18}$');

  static int? _id(String value) =>
      _number.hasMatch(value) ? int.tryParse(value, radix: 10) : null;

  /// Admits no more than one read per viewer and four per server.
  Future<EsiCallLogPage> own(Session session, EsiCallLogCursor? after) async {
    EsiCallLogPage failure(String status) =>
        EsiCallLogPage(status: status, rows: []);
    final auth = session.authenticated;
    final member = auth == null ? null : _id(auth.userIdentifier);
    final id = auth == null ? null : _id(auth.authId);
    if (member == null || id == null) return failure('denied');
    final cursorId = after == null ? null : _id(after.id);
    if (after != null && cursorId == null) return failure('denied');
    if (_reading.length >= 4 || !_reading.add(member)) return failure('busy');
    try {
      final rows = await _store.ownRows(
        session,
        (account: member, session: id),
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
    final id = _id(auth.authId);
    final authority = SsoSessions.forPod(session.serverpod);
    if (member == null || id == null || authority == null) {
      return failure('denied');
    }
    if (_reading.length >= 4 || !_reading.add(member)) return failure('busy');
    try {
      final live = await authority.viewerById(session, id, member);
      if (live?.admin != true) return failure('denied');
      final viewer = EsiCallLogViewer(member: member, admin: true);
      final window = await _store.sealWindow(session);
      final page = await _pageForSeal(session, viewer, window);
      return await _readSeal(session) == window ? page : failure('unavailable');
    } on EsiCallLogDenied {
      return failure('denied');
    } on Object {
      return failure('unavailable');
    } finally {
      _reading.remove(member);
    }
  }

  Future<EsiRouteCountPage> _pageForSeal(
    Session session,
    EsiCallLogViewer viewer,
    DateTime window,
  ) async {
    final cached = _cached;
    if (cached?.window == window) return cached!.page;
    final active = _computing;
    if (active?.window == window) {
      final before = _beforeAggregate;
      if (before != null) await before(joining: true);
      return active!.page;
    }
    final future = _compute(session, viewer, window);
    if (active == null || active.window.isBefore(window)) {
      _computing = (window: window, page: future);
    }
    try {
      return await future;
    } finally {
      if (identical(_computing?.page, future)) _computing = null;
    }
  }

  Future<EsiRouteCountPage> _compute(
    Session session,
    EsiCallLogViewer viewer,
    DateTime window,
  ) async {
    final before = _beforeAggregate;
    if (before != null) await before(joining: false);
    final rows = await _store.countsForSeal(session, viewer, window);
    final page = EsiRouteCountPage(
      status: 'ok',
      rows: List.unmodifiable([
        for (final row in rows)
          EsiRouteCount(
            operation: row.operation,
            total: row.total,
            errors: row.errors,
          ),
      ]),
    );
    final cached = _cached;
    if (cached == null || cached.window.isBefore(window)) {
      _cached = (window: window, page: page);
    }
    return page;
  }
}
