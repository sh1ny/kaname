import 'job.dart';

/// A verified registry row and its corresponding public EVE character ID.
typedef AffiliationIdentity = ({int identityId, int characterId});

/// The public IDs in one ESI result. Faction is validated but not stored.
typedef AffiliationRow = ({
  int characterId,
  int corporationId,
  int? allianceId,
  int? factionId,
});

/// A validated reply joined to the registry row that requested it.
typedef AffiliationWrite = ({
  int identityId,
  int corporationId,
  int? allianceId,
});

/// The decoded public response, or the reason no usable response is available.
sealed class AffiliationLookupResult {
  const AffiliationLookupResult();
}

/// An ESI reply to validate as a whole before storing any of it.
final class AffiliationReply extends AffiliationLookupResult {
  /// Wraps the decoded response rows.
  const AffiliationReply(this.rows);

  /// Rows returned by ESI, which can omit requested characters.
  final List<AffiliationRow> rows;
}

/// A refused, failed or undecodable exchange that writes nothing.
final class AffiliationLookupFailed extends AffiliationLookupResult {
  /// Reports the exchange category without IDs, credentials or response data.
  const AffiliationLookupFailed({this.malformed = false});

  /// Whether ESI sent a response that could not be decoded.
  final bool malformed;
}

/// Job diagnostics that can be logged with a count and no character IDs.
enum AffiliationIssue {
  /// The exchange failed or was not sent.
  unavailable,

  /// The response cannot safely be applied, even in part.
  malformed,

  /// A valid response did not include all requested characters.
  omitted,
}

/// The verified registry and observation store used by [AffiliationJob].
///
/// Each operation releases its database resources before the next one starts.
abstract interface class AffiliationRegistry {
  /// Returns the greatest visible identity key, or null for an empty registry.
  Future<int?> highWater();

  /// Returns at most [limit] identities in increasing key order within bounds.
  Future<List<AffiliationIdentity>> pageAfter(
    int after,
    int through,
    int limit,
  );

  /// Returns the registered identity if it still exists.
  Future<AffiliationIdentity?> identity(int identityId);

  /// Allocates a durable order before ESI submission.
  Future<int> allocateOrder();

  /// Writes observations for still-present identities when [order] is newer.
  Future<void> save(
    int order,
    DateTime observedAt,
    List<AffiliationWrite> rows,
  );
}

/// Refreshes public affiliation for the verified registry or one known identity.
///
/// No transaction spans ESI, and a failed lookup never changes an observation.
final class AffiliationJob implements Job<void> {
  /// Binds the job to storage, a scheduled public lookup, and a shutdown flag.
  ///
  /// Omit [identityId] for a full sweep. A submitted batch may finish after
  /// shutdown begins; the job does not submit another batch after that.
  const AffiliationJob({
    required this._registry,
    required this._lookup,
    required this._now,
    required this._isStopping,
    required this._onIssue,
    this._identityId,
  });

  static const _batchLimit = 1000;
  final AffiliationRegistry _registry;
  final Future<AffiliationLookupResult> Function(List<int>) _lookup;
  final DateTime Function() _now;
  final bool Function() _isStopping;
  final void Function(AffiliationIssue, int) _onIssue;
  final int? _identityId;

  @override
  String get name => 'character-affiliation';

  @override
  Future<void> run() async {
    if (_isStopping()) return;
    if (_identityId case final id?) {
      if (await _registry.identity(id) case final identity?) {
        await _refresh([identity]);
      }
      return;
    }
    final through = await _registry.highWater();
    if (through == null) return;
    var after = 0;
    while (after < through && !_isStopping()) {
      final page = await _registry.pageAfter(after, through, _batchLimit);
      if (page.isEmpty || _isStopping()) return;
      await _refresh(page);
      after = page.last.identityId;
    }
  }

  Future<void> _refresh(List<AffiliationIdentity> page) async {
    if (_isStopping()) return;
    final requested = {
      for (final pair in page) pair.characterId: pair.identityId,
    };
    final ids = requested.keys.toList(growable: false);
    final order = await _registry.allocateOrder();
    if (_isStopping()) return;
    switch (await _lookup(ids)) {
      case AffiliationLookupFailed(:final malformed):
        _onIssue(
          malformed ? AffiliationIssue.malformed : AffiliationIssue.unavailable,
          page.length,
        );
      case AffiliationReply(:final rows):
        final at = _now().toUtc();
        if (rows.length > page.length) {
          _onIssue(AffiliationIssue.malformed, page.length);
          return;
        }
        final writes = <AffiliationWrite>[];
        for (final row in rows) {
          // Removing a requested ID also detects a duplicate in the same reply.
          final identityId = requested.remove(row.characterId);
          if (identityId == null ||
              row.characterId <= 0 ||
              row.corporationId <= 0 ||
              (row.allianceId ?? 1) <= 0 ||
              (row.factionId ?? 1) <= 0) {
            _onIssue(AffiliationIssue.malformed, page.length);
            return;
          }
          writes.add((
            identityId: identityId,
            corporationId: row.corporationId,
            allianceId: row.allianceId,
          ));
        }
        if (writes.isNotEmpty) await _registry.save(order, at, writes);
        if (requested.isNotEmpty) {
          _onIssue(AffiliationIssue.omitted, requested.length);
        }
    }
  }
}
