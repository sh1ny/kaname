import 'cipher.dart';
import 'contract.dart';

const _dispatchMargin = Duration(seconds: 5);
const _admissionMargin = Duration(seconds: 15);
const _lease = Duration(seconds: 30);
const _maxInFlight = 32;
const _maxCounter = 0x7fffffffffffffff;

/// Exchanges a refresh token without exposing request or response diagnostics.
///
/// The HTTP adapter must finish or actually abort locally within ten seconds
/// (below the vault's lease). Racing an uncancelled request is not sufficient.
/// The adapter uses the non-secret handle to verify the reply for this grant.
typedef VaultRefreshExchange = Future<VaultRefreshReply> Function(
  VaultAuthorization authorization,
  String refreshToken,
);

typedef _Attempt = ({int fence, String refresh});
typedef _Step = ({VaultResult<VaultBearer>? outcome, _Attempt? attempt});

/// Owns the per-character credential lifecycle in one authoritative store.
///
/// Handles fence trusted in-process users, not RPC callers; callers must verify
/// the grant and destination holder before activation. This vault can't
/// coordinate independent stores. A connected client must not fall back to a
/// solo vault, and handoff must quiesce the old callers and park their grant
/// before activating the new holder. `esi-sso` owns that wiring and surfaces
/// re-login/notification outcomes. Worker vault access remains undecided.
final class EsiTokenVault {
  /// Creates a vault using a separately provisioned install key.
  ///
  /// Throws [VaultKeyConfigurationException] for an absent or invalid key.
  EsiTokenVault({
    required this._store,
    required String? base64Key,
    required VaultRefreshExchange refresh,
    DateTime Function()? now,
  }) : _cipher = VaultCipher(base64Key),
       _exchange = refresh,
       _now = now ?? DateTime.now;

  final VaultStore _store;
  final VaultCipher _cipher;
  final VaultRefreshExchange _exchange;
  final DateTime Function() _now;
  int _inFlight = 0;

  /// Reads non-secret authority metadata; null means no record has been created.
  Future<VaultResult<({VaultAuthorization authorization, VaultStatus status})?>>
  inspect(int character) => _safe(() async {
    if (character <= 0) {
      return const VaultFailure(VaultFailureReason.invalidInput);
    }
    final row = await _store.read(character);
    return VaultSuccess(
      row == null
          ? null
          : (authorization: row.authorization, status: row.status),
    );
  });

  /// Installs a verified grant against the observed [expectedGeneration].
  ///
  /// An unclaimed character uses generation zero. Only the same holder can
  /// replace an unparked grant. Each installation issues a fresh handle.
  Future<VaultResult<VaultAuthorization>> activate({
    required int character,
    required VaultHolder holder,
    required int expectedGeneration,
    required String refreshToken,
    VaultBearer? bearer,
  }) => _safe(() async {
    if (character <= 0 ||
        expectedGeneration < 0 ||
        !_validHolder(holder) ||
        !validToken(refreshToken) ||
        (bearer != null && !validToken(bearer.token))) {
      return const VaultFailure(VaultFailureReason.invalidInput);
    }
    return await _store.withCharacter<VaultResult<VaultAuthorization>>(
          character,
          wait: false,
          update: (row) async {
            final generation = row?.authorization.generation ?? 0;
            if (expectedGeneration != generation ||
                (row != null &&
                    row.status != VaultStatus.parked &&
                    row.authorization.holder != holder)) {
              return _unchanged(
                const VaultFailure(VaultFailureReason.notHolder),
              );
            }
            if (_live(row)) {
              return _unchanged(const VaultFailure(VaultFailureReason.busy));
            }
            if (generation == _maxCounter) {
              return _unchanged(
                const VaultFailure(VaultFailureReason.unavailable),
              );
            }
            final auth = (
              character: character,
              holder: holder,
              generation: generation + 1,
            );
            return (
              value: VaultSuccess(auth),
              next: VaultRecord(
                authorization: auth,
                status: VaultStatus.active,
                sealedCredential: await _cipher.seal(auth, (
                  refresh: refreshToken,
                  bearer: bearer,
                )),
                fence: 0,
                leaseUntil: null,
              ),
            );
          },
        ) ??
        const VaultFailure(VaultFailureReason.busy);
  });

  /// Removes the credential and invalidates the old handle before handoff.
  Future<VaultResult<VaultAuthorization>> park(VaultAuthorization auth) =>
      _safe(() async {
        if (!_validAuth(auth)) {
          return const VaultFailure(VaultFailureReason.invalidInput);
        }
        return await _store.withCharacter<VaultResult<VaultAuthorization>>(
              auth.character,
              wait: false,
              update: (row) async {
                if (row == null ||
                    row.authorization != auth ||
                    row.status == VaultStatus.parked) {
                  return _unchanged(
                    const VaultFailure(VaultFailureReason.notHolder),
                  );
                }
                if (_live(row)) {
                  return _unchanged(
                    const VaultFailure(VaultFailureReason.busy),
                  );
                }
                if (auth.generation == _maxCounter) {
                  return _unchanged(
                    const VaultFailure(VaultFailureReason.unavailable),
                  );
                }
                final parked = (
                  character: auth.character,
                  holder: auth.holder,
                  generation: auth.generation + 1,
                );
                return (
                  value: VaultSuccess(parked),
                  next: VaultRecord(
                    authorization: parked,
                    status: VaultStatus.parked,
                    sealedCredential: null,
                    fence: 0,
                    leaseUntil: null,
                  ),
                );
              },
            ) ??
            const VaultFailure(VaultFailureReason.busy);
      });

  /// Reads a committed bearer without starting refresh or taking a write lock.
  ///
  /// Use [bearer] before scheduler admission, where its longer expiry margin
  /// accounts for the wait and typed failures can be surfaced. Use this shorter
  /// dispatch-time recheck inside the scheduler's two-second bearer callback.
  Future<VaultResult<VaultBearer>> readBearer(VaultAuthorization auth) =>
      _safe(() => _read(auth, _dispatchMargin));

  /// Resolves a reusable or newly refreshed bearer before scheduler admission.
  ///
  /// A competitor receives busy while refresh is live. No bearer obtained by
  /// an exchange is returned without a confirmed commit, even if no rotation
  /// occurred. The caller still rechecks the current handle at dispatch.
  Future<VaultResult<VaultBearer>> bearer(
    VaultAuthorization auth,
  ) => _safe(() async {
    final existing = await _read(auth, _admissionMargin);
    if (existing is! VaultFailure<VaultBearer> ||
        existing.reason != VaultFailureReason.refreshRequired) {
      return existing;
    }
    if (_inFlight >= _maxInFlight) {
      return const VaultFailure(VaultFailureReason.busy);
    }
    _inFlight++;
    try {
      final prepared = await _store.withCharacter<_Step>(
        auth.character,
        wait: false,
        update: (row) async {
          final denied = _check(row, auth);
          if (denied != null) return _stop(denied);
          final credential = await _cipher.open(row!);
          final usable = _usable(credential.bearer, _admissionMargin);
          if (usable != null) {
            return _unchanged((outcome: VaultSuccess(usable), attempt: null));
          }
          if (_live(row)) return _stop(VaultFailureReason.busy);
          return _claim(row, credential.refresh);
        },
      );
      if (prepared == null) return const VaultFailure(VaultFailureReason.busy);
      if (prepared.outcome case final done?) return done;
      var attempt = prepared.attempt!;
      for (var round = 0; ; round++) {
        final reply = await _refresh(auth, attempt.refresh);
        final completed = await _store.withCharacter<_Step>(
          auth.character,
          wait: true,
          update: (row) =>
              _complete(auth, row, attempt, reply, mayRetry: round == 0),
        );
        if (completed == null) {
          return const VaultFailure(VaultFailureReason.unavailable);
        }
        if (completed.outcome case final result?) {
          if (result case VaultSuccess(:final value)) {
            return _usable(value, _admissionMargin) == null
                ? const VaultFailure(VaultFailureReason.refreshRequired)
                : result;
          }
          return result;
        }
        attempt = completed.attempt!;
      }
    } finally {
      _inFlight--;
    }
  });

  Future<VaultResult<VaultBearer>> _read(
    VaultAuthorization auth,
    Duration margin,
  ) async {
    if (!_validAuth(auth)) {
      return const VaultFailure(VaultFailureReason.invalidInput);
    }
    final row = await _store.read(auth.character);
    final denied = _check(row, auth);
    if (denied != null) return VaultFailure(denied);
    final credential = await _cipher.open(row!);
    final bearer = _usable(credential.bearer, margin);
    return bearer == null
        ? const VaultFailure(VaultFailureReason.refreshRequired)
        : VaultSuccess(bearer);
  }

  Future<VaultRefreshReply> _refresh(
    VaultAuthorization auth,
    String token,
  ) async {
    try {
      return await _exchange(auth, token);
    } on Object {
      return const VaultRefreshTemporaryFailure();
    }
  }

  Future<VaultWrite<_Step>> _complete(
    VaultAuthorization auth,
    VaultRecord? snapshot,
    _Attempt attempt,
    VaultRefreshReply reply, {
    required bool mayRetry,
  }) async {
    final denied = _check(snapshot, auth);
    if (denied != null) return _stop(denied);
    final row = snapshot!;
    final ownsLease = row.fence == attempt.fence && row.leaseUntil != null;
    const unavailable = VaultFailureReason.unavailable;
    switch (reply) {
      case VaultRefreshTemporaryFailure():
        return _stop(unavailable, next: ownsLease ? _release(row) : null);
      case VaultRefreshUnverifiedGrant() || VaultRefreshInvalidGrant():
        if (!ownsLease) return _stop(unavailable);
        final credential = await _cipher.open(row);
        if (credential.refresh != attempt.refresh) {
          if (reply is VaultRefreshUnverifiedGrant) {
            return _stop(unavailable, next: _release(row));
          }
          return mayRetry
              ? _claim(row, credential.refresh)
              : _stop(unavailable, next: _release(row));
        }
        return _stop(
          VaultFailureReason.reLoginRequired,
          next: VaultRecord(
            authorization: auth,
            status: VaultStatus.dead,
            sealedCredential: null,
            fence: row.fence,
            leaseUntil: null,
          ),
        );
      case VaultRefreshSuccess(:final bearer, :final replacementRefreshToken):
        final current = await _cipher.open(row);
        final replacement = replacementRefreshToken;
        if (current.refresh != attempt.refresh ||
            (replacement != null && !validToken(replacement))) {
          return _stop(unavailable, next: ownsLease ? _release(row) : null);
        }
        if (!ownsLease) {
          if (replacement == null || replacement == current.refresh) {
            return _stop(unavailable);
          }
          final sealed = await _cipher.seal(auth, (
            refresh: replacement,
            bearer: current.bearer,
          ));
          return _stop(
            unavailable,
            next: VaultRecord(
              authorization: auth,
              status: row.status,
              sealedCredential: sealed,
              fence: row.fence,
              leaseUntil: row.leaseUntil,
            ),
          );
        }
        final valid = validToken(bearer.token);
        final sealed = await _cipher.seal(auth, (
          refresh: replacement ?? attempt.refresh,
          bearer: valid ? bearer : null,
        ));
        final VaultResult<VaultBearer> outcome = valid
            ? VaultSuccess(bearer)
            : const VaultFailure(unavailable);
        return (
          value: (outcome: outcome, attempt: null),
          next: VaultRecord(
            authorization: auth,
            status: row.status,
            sealedCredential: sealed,
            fence: row.fence,
            leaseUntil: null,
          ),
        );
    }
  }

  VaultWrite<_Step> _claim(VaultRecord row, String token) {
    if (row.fence == _maxCounter) return _stop(VaultFailureReason.unavailable);
    final fence = row.fence + 1;
    return (
      value: (outcome: null, attempt: (fence: fence, refresh: token)),
      next: VaultRecord(
        authorization: row.authorization,
        status: row.status,
        sealedCredential: row.sealedCredential,
        fence: fence,
        leaseUntil: _now().toUtc().add(_lease),
      ),
    );
  }

  static VaultRecord _release(VaultRecord row) => VaultRecord(
    authorization: row.authorization,
    status: row.status,
    sealedCredential: row.sealedCredential,
    fence: row.fence,
    leaseUntil: null,
  );

  static VaultWrite<T> _unchanged<T>(T value) => (value: value, next: null);

  static VaultWrite<_Step> _stop(
    VaultFailureReason reason, {
    VaultRecord? next,
  }) => (value: (outcome: VaultFailure(reason), attempt: null), next: next);

  static VaultFailureReason? _check(VaultRecord? row, VaultAuthorization auth) {
    if (row == null ||
        row.authorization != auth ||
        row.status == VaultStatus.parked) {
      return VaultFailureReason.notHolder;
    }
    return row.status == VaultStatus.dead
        ? VaultFailureReason.reLoginRequired
        : null;
  }

  static bool _validAuth(VaultAuthorization auth) =>
      auth.character > 0 && auth.generation > 0 && _validHolder(auth.holder);

  static bool _validHolder(VaultHolder holder) =>
      holder.id.length <= 128 &&
      holder.id.isNotEmpty &&
      holder.id.codeUnits.every((unit) => unit >= 0x21 && unit <= 0x7e);

  bool _live(VaultRecord? row) => row?.leaseUntil?.isAfter(_now()) ?? false;

  VaultBearer? _usable(VaultBearer? bearer, Duration margin) =>
      bearer != null && bearer.expiresAt.isAfter(_now().add(margin))
      ? bearer
      : null;

  static Future<VaultResult<T>> _safe<T>(
    Future<VaultResult<T>> Function() action,
  ) async {
    try {
      return await action();
    } on Object {
      return const VaultFailure(VaultFailureReason.unavailable);
    }
  }
}
