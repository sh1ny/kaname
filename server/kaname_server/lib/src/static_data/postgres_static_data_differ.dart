/// The SQL differ of two stored builds.
library;

import 'package:kaname_static_data/kaname_static_data.dart';
import 'package:postgres/postgres.dart' as pg;

/// A [StaticDataDiffer] that compares two builds with SQL on the store's
/// connection (D4).
///
/// It runs read-only in one repeatable-read transaction and writes nothing;
/// storing the report is the caller's job. It runs one statement per file
/// (and a second one for the changed fields of a file that has changes), so
/// each stays within the connection's five-minute `statement_timeout`
/// (design A3, "Diff query per table").
///
/// For a typed table it joins the two builds on `sdeId` with a full outer
/// join; rows on one side are added or removed, and rows on both sides whose
/// `raw` jsonb differ are changed (`jsonb` equality ignores key order, A1).
/// For `sde_record` it classifies per record as [BuildDiffReport] describes
/// (C5): a non-empty key that occurs exactly once on each side is paired on
/// it, and every other record is counted as a multiset of `(key, record)`,
/// one group per distinct pair, so a repeated key can never multiply a join.
///
/// ## Plans that need no statistics
///
/// A build's rows are inserted moments before the diff, so no `ANALYZE` has
/// seen them, and a CTE hides the table's statistics from the planner in any
/// case. The first live run showed it: the planner estimated one group for
/// each `GROUP BY key ... HAVING count(*) = 1` and joined the two sides, of
/// about 345,000 groups each, with a nested loop, which ran past the
/// statement timeout (design A3). So no statement joins two derived
/// relations. A typed table is one full outer join (which is always a hash
/// or merge join); a raw file is one `GROUP BY (key, record)` over the two
/// builds' records with per-side counts, and the per-key totals come from
/// window functions, so a plan can only be a scan, a hash aggregate and a
/// sort whatever the estimates.
final class PostgresStaticDataDiffer implements StaticDataDiffer {
  /// Creates a differ over [_connection].
  ///
  /// [onStatement], when given, sees every statement with its duration.
  PostgresStaticDataDiffer(
    this._connection, {
    this.onStatement,
    this.onStatementStart,
  });

  final pg.Connection _connection;

  /// The observer of the statements, for timing.
  final DiffStatementObserver? onStatement;

  /// The observer that sees each statement before it runs.
  final DiffStatementStart? onStatementStart;

  @override
  Future<BuildDiffReport> compare(int fromBuild, int toBuild) =>
      _connection.runTx((tx) async {
        final stored = await tx.execute(
          r'SELECT "build" FROM "sde_build" WHERE "build" = ANY($1::bigint[])',
          parameters: [
            [fromBuild, toBuild],
          ],
        );
        final present = {for (final row in stored) row[0]! as int};
        for (final build in [fromBuild, toBuild]) {
          if (!present.contains(build)) throw BuildNotStoredException(build);
        }
        final params = [fromBuild, toBuild];
        final files = <FileDiff>[];
        for (final TypedFile(:fileName, :table) in typedFiles) {
          final diff = await _file(
            tx,
            fileName,
            _typedSql(table, _summaryTail),
            params,
            fieldsSql: _typedSql(table, _typedFieldsTail),
          );
          if (diff != null) files.add(diff);
        }
        final names = await _run(
          tx,
          'sde_record files',
          r'SELECT DISTINCT "file" FROM "sde_record" '
              r'WHERE "build" = ANY($1::bigint[]) ORDER BY "file"',
          [params],
        );
        for (final row in names) {
          final file = row[0]! as String;
          final diff = await _file(tx, file, _rawSql(_summaryTail), [
            ...params,
            file,
          ], fieldsSql: _rawSql(_rawFieldsTail));
          if (diff != null) files.add(diff);
        }
        files.sort((a, b) => a.file.compareTo(b.file));
        return BuildDiffReport(
          fromBuild: fromBuild,
          toBuild: toBuild,
          files: files,
        );
      }, settings: _readOnlySnapshot);

  static final _readOnlySnapshot = pg.TransactionSettings(
    isolationLevel: pg.IsolationLevel.repeatableRead,
    accessMode: pg.AccessMode.readOnly,
  );

  Future<pg.Result> _run(
    pg.Session session,
    String name,
    String sql,
    List<Object?> parameters,
  ) async {
    await onStatementStart?.call(name, sql, parameters);
    final timer = Stopwatch()..start();
    final result = await session.execute(sql, parameters: parameters);
    timer.stop();
    onStatement?.call(name, timer.elapsed, result.length);
    return result;
  }

  /// Runs [sql] for [file] and reads its summary; `null` when neither build
  /// has the file.
  Future<FileDiff?> _file(
    pg.Session session,
    String file,
    String sql,
    List<Object?> parameters, {
    required String fieldsSql,
  }) async {
    final counts = <String, int>{};
    final distinctKeys = <String, int>{};
    final keys = <String, List<String>>{};
    var inOld = false;
    var inNew = false;
    for (final row in await _run(session, file, sql, parameters)) {
      final [part as String, kind as String?, key as String?, total, other] =
          row.toList();
      switch (part) {
        case 'side':
          inOld = total == 1;
          inNew = other == 1;
        case 'count':
          counts[kind!] = total! as int;
          distinctKeys[kind] = other! as int;
        case 'key':
          (keys[kind!] ??= []).add(key!);
        case _:
          throw StateError('unknown part $part');
      }
    }
    if (!inOld && !inNew) return null;
    RecordChanges changes(String kind) => RecordChanges(
      count: counts[kind] ?? 0,
      keys: keys[kind] ?? const [],
      truncated: (distinctKeys[kind] ?? 0) > (keys[kind]?.length ?? 0),
    );
    final changed = changes('changed');
    final fields = <String, int>{};
    if (changed.count > 0) {
      for (final row in await _run(
        session,
        '$file fields',
        fieldsSql,
        parameters,
      )) {
        fields[row[0]! as String] = row[1]! as int;
      }
    }
    return FileDiff(
      file: file,
      status: switch ((inOld, inNew)) {
        (false, _) => DiffFileStatus.newFile,
        (_, false) => DiffFileStatus.removedFile,
        _ => DiffFileStatus.both,
      },
      added: changes('added'),
      removed: changes('removed'),
      changed: changed,
      changedFields: fields,
    );
  }
}

/// The columns every summary row has: part, kind, key, total, other.
///
/// Reads the CTE `ev(k, kind, n)`: one row per record group that was added,
/// removed or changed, with its key (empty when it has none) and its record
/// count. Returns the side markers, the complete counts with the number of
/// distinct non-empty keys, and the first keys per kind in key order.
const _summaryTail =
    '''
SELECT 'side'::text AS part, NULL::text AS kind, NULL::text AS k,
       (EXISTS (SELECT 1 FROM o))::int::bigint AS total,
       (EXISTS (SELECT 1 FROM n))::int::bigint AS other
UNION ALL
SELECT 'count', kind, NULL, sum(n)::bigint,
       (count(DISTINCT k) FILTER (WHERE k <> ''))::bigint
FROM ev GROUP BY kind
UNION ALL
SELECT 'key', kind, k, 0::bigint, 0::bigint
FROM (
  SELECT kind, k, row_number() OVER (
           PARTITION BY kind ORDER BY length(k), k COLLATE "C") AS rn
  FROM (SELECT DISTINCT kind, k FROM ev WHERE k <> '') AS d
) AS ranked
WHERE rn <= ${BuildDiffReport.maxKeysPerKind}
''';

/// Counts the fields that differ in the changed records, reading `c(a, b)`.
const _fieldsOf = '''
SELECT f.key::text, count(*)::bigint
FROM c
CROSS JOIN LATERAL (
  SELECT key
  FROM jsonb_each(c.a) AS x(key, value)
  FULL OUTER JOIN jsonb_each(c.b) AS y(key, value) USING (key)
  WHERE x.value IS DISTINCT FROM y.value
) AS f
GROUP BY f.key
''';

/// A typed table's statement, with parameters `$1` (old) and `$2` (new).
///
/// One full outer join, read by `ev` and `c`; no other join exists.
String _typedSql(String table, String tail) =>
    '''
WITH o AS (
  SELECT "sdeId" AS id, "raw" AS r FROM "$table" WHERE "build" = \$1::bigint),
n AS (
  SELECT "sdeId" AS id, "raw" AS r FROM "$table" WHERE "build" = \$2::bigint),
j AS (
  SELECT o.id AS oid, n.id AS nid, o.r AS orr, n.r AS nrr
  FROM o FULL OUTER JOIN n ON o.id = n.id
),
ev AS (
  SELECT COALESCE(oid, nid)::text AS k,
         CASE WHEN oid IS NULL THEN 'added'
              WHEN nid IS NULL THEN 'removed'
              ELSE 'changed' END AS kind,
         1::bigint AS n
  FROM j
  WHERE oid IS NULL OR nid IS NULL OR orr <> nrr
),
c AS (
  SELECT orr AS a, nrr AS b FROM j
  WHERE oid IS NOT NULL AND nid IS NOT NULL AND orr <> nrr
)
$tail''';

/// The tail that returns the changed fields of a typed table.
const _typedFieldsTail = _fieldsOf;

/// A raw file's statement, with parameters `$1` (old), `$2` (new) and `$3`
/// (the file).
///
/// `u` holds both builds' records of the file, `m` one row per distinct
/// `(key, record)` with its count on each side (`mo`, `mn`) and the key's
/// totals (`ko`, `kn`). A key is paired when it is not empty and occurs once
/// on each side. A paired record that differs shows as two rows, one per
/// side; the one with the old record is the changed record. Every other row
/// is added or removed by the difference of its counts.
String _rawSql(String tail) => '''
WITH o AS (
  SELECT "key" AS k, "record" AS r FROM "sde_record"
  WHERE "build" = \$1::bigint AND "file" = \$3::text),
n AS (
  SELECT "key" AS k, "record" AS r FROM "sde_record"
  WHERE "build" = \$2::bigint AND "file" = \$3::text),
m AS (
  SELECT k, r, mo, mn,
         sum(mo) OVER (PARTITION BY k) AS ko,
         sum(mn) OVER (PARTITION BY k) AS kn
  FROM (
    SELECT k, r, sum(old_side) AS mo, sum(new_side) AS mn
    FROM (
      SELECT k, r, 1::bigint AS old_side, 0::bigint AS new_side FROM o
      UNION ALL
      SELECT k, r, 0::bigint, 1::bigint FROM n
    ) AS u
    GROUP BY k, r
  ) AS g
),
ev AS (
  SELECT k, 'changed' AS kind, 1::bigint AS n FROM m
  WHERE k <> '' AND ko = 1 AND kn = 1 AND mo = 1 AND mn = 0
  UNION ALL
  SELECT k, CASE WHEN mn > mo THEN 'added' ELSE 'removed' END, abs(mn - mo)
  FROM m
  WHERE NOT (k <> '' AND ko = 1 AND kn = 1) AND mn <> mo
),
c AS (
  SELECT (array_agg(r) FILTER (WHERE mo = 1))[1] AS a,
         (array_agg(r) FILTER (WHERE mn = 1))[1] AS b
  FROM m
  WHERE k <> '' AND ko = 1 AND kn = 1
  GROUP BY k
  HAVING count(*) = 2
)
$tail''';

/// The tail that returns the changed fields of a raw file.
const _rawFieldsTail = _fieldsOf;
