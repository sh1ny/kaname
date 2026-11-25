/// Installation role under ADR 0005.
enum VaultHolderKind {
  /// Holds the credential on behalf of connected clients.
  server,

  /// Holds the credential locally in solo or solo-lite.
  device,
}

/// Non-secret holder identity within the authority.
typedef VaultHolder = ({VaultHolderKind kind, String id});

/// Non-secret handle to one verified authorization, not proof of identity.
typedef VaultAuthorization = ({
  int character,
  VaultHolder holder,
  int generation,
});

/// Durable credential state.
enum VaultStatus {
  /// Credential belongs to the current holder.
  active,

  /// Credential removed and another holder may activate.
  parked,

  /// Current holder must re-authorize before any further refresh.
  dead,
}

/// Observable vault failure, never carrying credentials or a dependency error.
enum VaultFailureReason {
  /// The request does not have the current holder and generation.
  notHolder,

  /// An active lease, character transaction or vault capacity excludes work.
  busy,

  /// A definitive rejection requires a fresh interactive authorization.
  reLoginRequired,

  /// No committed bearer has sufficient lifetime for this lookup.
  refreshRequired,

  /// Credential storage, decoding or refresh did not produce a usable result.
  unavailable,

  /// The supplied character, holder or grant is invalid.
  invalidInput,
}

/// Success or a secret-free failure from the vault.
sealed class VaultResult<T> {
  const VaultResult();
}

/// The operation's committed result.
final class VaultSuccess<T> extends VaultResult<T> {
  /// Wraps a committed [value].
  const VaultSuccess(this.value);

  /// The value for the trusted caller (may be sensitive).
  final T value;
}

/// The operation did not yield a usable result.
final class VaultFailure<T> extends VaultResult<T> {
  /// Wraps a stable refusal [reason].
  const VaultFailure(this.reason);

  /// The complete, safe diagnostic for the refusal.
  final VaultFailureReason reason;

  @override
  String toString() => 'VaultFailure(${reason.name})';
}

/// Short-lived secret for a trusted ESI transport, never a log value.
final class VaultBearer {
  /// Binds [token] to its absolute [expiresAt] instant.
  const VaultBearer(this.token, this.expiresAt);

  /// The access token to send only as authorization.
  final String token;

  /// The upstream expiration instant.
  final DateTime expiresAt;
}

/// Closed outcomes of the trusted refresh exchange.
sealed class VaultRefreshReply {
  const VaultRefreshReply();
}

/// An exchange issued a bearer and may have rotated the refresh token.
final class VaultRefreshSuccess extends VaultRefreshReply {
  /// Wraps the issued [bearer] and optional replacement credential.
  const VaultRefreshSuccess(this.bearer, {this.replacementRefreshToken});

  /// The issued access token and expiry.
  final VaultBearer bearer;

  /// The new refresh token, or null if the presented one remains current.
  final String? replacementRefreshToken;
}

/// Upstream definitively rejected the presented refresh token.
final class VaultRefreshInvalidGrant extends VaultRefreshReply {
  /// Reports `invalid_grant` after the adapter verifies that classification.
  const VaultRefreshInvalidGrant();
}

/// A reply could not be verified for the current authorization.
final class VaultRefreshUnverifiedGrant extends VaultRefreshReply {
  /// Discards the current credential without retrying on a replacement.
  const VaultRefreshUnverifiedGrant();
}

/// No definitive grant result was obtained from upstream.
final class VaultRefreshTemporaryFailure extends VaultRefreshReply {
  /// Reports only the classification, not a response, exception or stack.
  const VaultRefreshTemporaryFailure();
}

/// A malformed or absent separately supplied install key.
final class VaultKeyConfigurationException implements Exception {
  /// Constructs a configuration error without retaining the supplied value.
  const VaultKeyConfigurationException();

  @override
  String toString() =>
      'ESI vault requires a canonical Base64 32-byte install key';
}

/// One authoritative row. Only the sealed envelope contains credentials.
final class VaultRecord {
  /// Constructs an immutable snapshot of the character's persisted state.
  const VaultRecord({
    required this.authorization,
    required this.status,
    required this.sealedCredential,
    required this.fence,
    required this.leaseUntil,
  });

  /// Current or last holder and its generation.
  final VaultAuthorization authorization;

  /// Credential lifecycle status.
  final VaultStatus status;

  /// Authenticated ciphertext, present only when active.
  final String? sealedCredential;

  /// A monotonic attempt counter within the authorization generation.
  final int fence;

  /// The first instant a competing attempt may take over, or no lease.
  final DateTime? leaseUntil;
}

/// Transaction result and optional replacement row; null means no write.
typedef VaultWrite<T> = ({T value, VaultRecord? next});

/// Authoritative ciphertext storage, shared by all vault instances for a holder.
abstract interface class VaultStore {
  /// Reads one committed row, or null for an unclaimed character.
  Future<VaultRecord?> read(int character);

  /// Locks the character even if no row exists, reads and applies [update].
  ///
  /// Runs [update] once under exclusivity. Returns only after any write is
  /// committed. Returns null on try-lock contention; [wait] instead allows a
  /// bounded wait for a completion holding a returned rotation. Throws on
  /// store failure or uncertain commit. Never retries [update] implicitly.
  Future<T?> withCharacter<T extends Object>(
    int character, {
    required bool wait,
    required Future<VaultWrite<T>> Function(VaultRecord?) update,
  });
}
