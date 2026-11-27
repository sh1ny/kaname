import 'dart:convert';

import 'package:kaname_core/kaname_core.dart';
import 'package:serverpod/serverpod.dart';

/// Public affiliation at the time of the last valid lookup, server-side only.
typedef AffiliationObservation = ({
  int corporationId,
  int? allianceId,
  DateTime observedAt,
});

/// The PostgreSQL adapter for the verified registry and affiliation observations.
final class AffiliationStore implements AffiliationRegistry {
  /// Binds database work to an active server session.
  const AffiliationStore(this._session);

  final Session _session;

  /// Reads by CCP character ID. Null means unknown, not unaffiliated.
  Future<AffiliationObservation?> read(int characterId) async {
    final rows = await _query(
      '''
      SELECT a."corporationId", a."allianceId", a."observedAt"
      FROM esi_identity AS i
      JOIN character_affiliation AS a ON a."identityId" = i.id
      WHERE i."characterId" = @character::bigint
      ''',
      {'character': characterId},
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return (
      corporationId: row[0] as int,
      allianceId: row[1] as int?,
      observedAt: (row[2] as DateTime).toUtc(),
    );
  }

  @override
  Future<int?> highWater() async {
    final rows = await _query('SELECT max(id) FROM esi_identity');
    return rows.single[0] as int?;
  }

  @override
  Future<List<AffiliationIdentity>> pageAfter(
    int after,
    int through,
    int limit,
  ) async {
    final rows = await _query(
      '''
      SELECT id, "characterId" FROM esi_identity
      WHERE id > @after::bigint AND id <= @through::bigint
      ORDER BY id LIMIT @limit::int
      ''',
      {'after': after, 'through': through, 'limit': limit},
    );
    return [
      for (final row in rows)
        (identityId: row[0] as int, characterId: row[1] as int),
    ];
  }

  @override
  Future<AffiliationIdentity?> identity(int identityId) async {
    final rows = await _query(
      '''
      SELECT "characterId" FROM esi_identity WHERE id = @id::bigint
      ''',
      {'id': identityId},
    );
    if (rows.isEmpty) return null;
    return (identityId: identityId, characterId: rows.single[0] as int);
  }

  @override
  Future<int> allocateOrder() async {
    final rows = await _query('''
      SELECT nextval(pg_get_serial_sequence('character_affiliation', 'id'))
      ''');
    return rows.single[0] as int;
  }

  @override
  Future<void> save(
    int order,
    DateTime observedAt,
    List<AffiliationWrite> rows,
  ) async {
    // Lock only the still-present identities for the duration of the write.
    // Sorted keys give overlapping batches the same upsert lock order.
    final records = jsonEncode([
      for (final row in rows)
        {'i': row.identityId, 'c': row.corporationId, 'a': row.allianceId},
    ]);
    await _limited(
      (tx) => _session.db.unsafeExecute(
        '''
      INSERT INTO character_affiliation
        ("identityId", "corporationId", "allianceId", "observedAt", "lookupOrder")
      SELECT r.i, r.c, r.a, @at::timestamp, @lookup::bigint
      FROM jsonb_to_recordset(@rows::jsonb) AS r(i bigint, c bigint, a bigint)
      JOIN esi_identity AS i ON i.id = r.i
      ORDER BY r.i FOR KEY SHARE OF i
      ON CONFLICT ("identityId") DO UPDATE SET
        "corporationId" = EXCLUDED."corporationId",
        "allianceId" = EXCLUDED."allianceId",
        "observedAt" = EXCLUDED."observedAt",
        "lookupOrder" = EXCLUDED."lookupOrder"
      WHERE character_affiliation."lookupOrder" < EXCLUDED."lookupOrder"
      ''',
        parameters: QueryParameters.named({
          'rows': records,
          'at': observedAt.toUtc(),
          'lookup': order,
        }),
        transaction: tx,
      ),
    );
  }

  Future<DatabaseResult> _query(
    String sql, [
    Map<String, Object>? parameters,
  ]) => _limited(
    (tx) => _session.db.unsafeQuery(
      sql,
      parameters: parameters == null ? null : QueryParameters.named(parameters),
      transaction: tx,
    ),
  );

  Future<T> _limited<T>(Future<T> Function(Transaction) run) =>
      _session.db.transaction((tx) async {
        await _session.db.unsafeExecute(
          "SET LOCAL statement_timeout = '10s'",
          transaction: tx,
        );
        return run(tx);
      });
}
