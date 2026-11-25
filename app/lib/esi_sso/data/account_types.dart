import 'package:kaname_esi/kaname_esi.dart' show EsiRefusalReason;

/// A viewer from a verified Kaname or native authorization. No CCP secret.
final class AccountPilot {
  /// Public projection used by app state.
  const AccountPilot({
    required this.characterId,
    required this.name,
    this.memberId,
    this.admin = false,
    this.holder,
  });

  /// String representation preserves the full ID on web.
  final String characterId;

  /// Name returned by the verified identity provider.
  final String name;

  /// Kaname member ID for connected sessions only.
  final String? memberId;

  /// Current server admin scope. Native solo never grants it.
  final bool admin;

  /// Fixed server or native holder state; never an upstream diagnostic.
  final String? holder;

  /// Decodes a trusted app RPC response; invalid values have no authority.
  static AccountPilot? parse(Object? response) {
    if (response case {
      'characterId': final String id,
      'characterName': final String name,
      'memberId': final String member,
      'admin': final bool admin,
    }) {
      final result = response as Map<String, Object?>;
      return AccountPilot(
        characterId: id,
        name: name,
        memberId: member,
        admin: admin,
        holder: result['holder'] is String ? result['holder'] as String : null,
      );
    }
    return null;
  }
}

/// The two values shown by the skills read in Settings.
typedef SkillStats = ({int count, int totalSp});

/// A scheduler refusal with a known retry time when one was supplied.
typedef SkillsRefusal = ({EsiRefusalReason reason, DateTime? retryAt});

/// The result of one connected or solo skills request.
typedef SkillsRead = (AccountNotice, SkillStats?, SkillsRefusal?);

/// A stable failure or next step, suitable for app state and localization.
enum AccountNotice {
  /// A definitive grant rejection requires fresh scoped authorization.
  reauthorize,

  /// Kaname's own work limit prevented the skills request.
  busy,

  /// Completed or nothing pending.
  none,

  /// Work was refused or did not complete. No raw error reaches the app.
  unavailable,

  /// The user cancelled before activation.
  cancelled,

  /// The existing holder has not yet confirmed exclusion.
  pending,

  /// This installation cannot take or reclaim the current holder.
  blocked,

  /// The viewer needs a valid bearer again.
  signedOut,
}

/// The server's answer to a desktop take request.
sealed class DeviceTakeResult {
  const DeviceTakeResult();
}

/// A confirmed source park, with no CCP credential.
final class DeviceReservation extends DeviceTakeResult {
  /// Identifies the reserved assignment and its owner.
  const DeviceReservation({
    required this.generation,
    required this.ownerFingerprint,
  });

  /// The assignment generation the original device must return.
  final String generation;

  /// The digest of the character ID and verified owner claim.
  final String ownerFingerprint;
}

/// The server refused this request without reserving a holder for it.
final class DeviceTakeRefused extends DeviceTakeResult {
  /// Creates a confirmed refusal.
  const DeviceTakeRefused();
}

/// The exact fenced intent never committed and can no longer commit.
final class DeviceTakeNotAccepted extends DeviceTakeResult {
  /// Creates a terminal outcome for the matching epoch and proof.
  const DeviceTakeNotAccepted();
}

/// The reply proves neither a reservation nor a definitive refusal.
final class DeviceTakeIncomplete extends DeviceTakeResult {
  /// Wraps the fixed notice for the incomplete request.
  const DeviceTakeIncomplete(this.notice);

  /// The notice to show without discarding the pending intent.
  final AccountNotice notice;
}

/// The source's answer before the desktop creates a new take journal.
sealed class DeviceTakePreparation {
  const DeviceTakePreparation();
}

/// The epoch to attach to the new proof before sending it.
final class DeviceTakeEpoch extends DeviceTakePreparation {
  /// Creates preparation for a canonical positive source epoch.
  const DeviceTakeEpoch(this.epoch);

  /// The epoch used for both start and reconciliation.
  final int epoch;
}

/// The source does not implement the fenced take route.
final class DeviceTakeLegacy extends DeviceTakePreparation {
  /// The legacy route is available for unbound proofs only.
  const DeviceTakeLegacy();
}

/// The caller cannot prepare a new take now.
final class DeviceTakeUnprepared extends DeviceTakePreparation {
  /// Keeps the fixed notice without creating a journal.
  const DeviceTakeUnprepared(this.notice);

  /// The notice to report to the user.
  final AccountNotice notice;
}

/// The parts of a connected session needed by the original desktop device.
abstract interface class HolderRemote {
  /// Canonical origin of the authenticated server.
  String get origin;

  /// Current trusted connected viewer, never a typed-in target character.
  AccountPilot get pilot;

  /// Requests or resumes parking on the server.
  ///
  /// A refusal applies only to this request. A retry can be refused after an
  /// earlier request committed, so it must not discard the existing journal.
  Future<DeviceTakeResult> take(String proof);

  /// Reads the source epoch before the new intent is committed locally.
  Future<DeviceTakePreparation> prepareTake();

  /// Starts or reconciles a journal that already has an epoch and proof.
  ///
  /// A pre-upgrade journal has no saved prior state. An epoch-bound proof
  /// must never reach the legacy [take] route, even after a server downgrade.
  Future<DeviceTakeResult> takeIntent(
    String proof,
    int sourceEpoch, {
    required bool reconcile,
  });

  /// Returns a parked reservation to the server.
  Future<AccountNotice> release(String proof, String generation);

  /// Joins a server that had no holder assignment for this character.
  Future<AccountNotice> join(String proof, String ownerFingerprint);
}

/// Credential-only surface available on the supported desktop platforms.
abstract interface class DesktopAccount {
  /// Stored public ID, not a client secret.
  String? get clientId;

  /// Whether this app can request a new server grant without a local overlap.
  bool permitsServerGrant(String characterId);

  /// Whether the original device holds a confirmed reservation or grant.
  bool ownsReservationFor(String origin, String characterId);

  /// The current native identity and visible journal state.
  AccountPilot? get pilot;

  /// Sets the owner-provided native application ID when safe to do so.
  AccountNotice configure(String clientId);

  /// Runs an unscoped native identity check.
  Future<AccountNotice> identify();

  /// Records local permission and performs a new, scoped PKCE authorization.
  Future<AccountNotice> authorizeSkills();

  /// Revokes local scope without releasing a linked holder.
  Future<AccountNotice> disableSkills();

  /// Confirms park on the server before allowing a native grant.
  Future<AccountNotice> take(HolderRemote remote);

  /// Parks local credentials before returning or joining.
  Future<AccountNotice> returnTo(HolderRemote remote);

  /// Reads skills only with a current local holder and scope.
  Future<SkillsRead> skills();

  /// Cancels an open browser attempt.
  void cancel();

  /// Drains work and closes scheduler, OAuth client and credential store.
  Future<void> close();
}
