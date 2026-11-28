import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:kaname_esi/kaname_esi.dart'
    show EsiNotSent, EsiSuccess, SkillsCalls;
import 'package:kaname_esi_scheduler/kaname_esi_scheduler.dart'
    show EsiPrincipal, EsiPriority;
import 'package:kaname_esi_scheduler/native.dart' show NativeEsiRuntime;
import 'package:kaname_esi_sso/kaname_esi_sso.dart';
import 'package:kaname_esi_vault/kaname_esi_vault.dart';

import 'account_types.dart';
import 'device_store.dart';
import 'native_pkce.dart';

/// Desktop runtime for the explicitly selected character. It never falls back
/// from connected requests to native dispatch (ADR 0005 and ADR 0017).
final class NativeAccount implements DesktopAccount {
  /// Owns [store] and [httpClient]; tests can supply a loopback ESI origin.
  NativeAccount({
    required DeviceStore store,
    required http.Client httpClient,
    required this._launch,
    Uri? testEsiOrigin,
    int testPort = 48175,
    DateTime Function()? now,
  }) : _store = store,
       _http = httpClient,
       _now = now ?? DateTime.now {
    _oauth = CcpOAuth(_http, now: _now);
    _verifier = CcpJwtVerifier(now: _now, loadKeys: _oauth.loadSigningKeys);
    _pkce = NativePkce(oauth: _oauth, verifier: _verifier, port: testPort);
    _vault = EsiTokenVault(
      store: store,
      base64Key: store.installKey,
      refresh: _refresh,
      now: _now,
    );
    _esi = NativeEsiRuntime.solo(
      key: base64Decode(store.installKey),
      userAgent: 'Kaname/0.0.1 (+https://github.com/sh1ny/kaname)',
      testOrigin: testEsiOrigin,
      now: _now,
    );
  }

  final DeviceStore _store;
  final http.Client _http;
  final Future<bool> Function(Uri) _launch;
  final DateTime Function() _now;
  late final CcpOAuth _oauth;
  late final CcpJwtVerifier _verifier;
  late final NativePkce _pkce;
  late final EsiTokenVault _vault;
  late final NativeEsiRuntime _esi;
  Future<Object?>? _running;
  bool _closing = false;
  bool _authorizationCancelled = false;
  static final _registration = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static final _hash = RegExp(r'^[0-9a-f]{64}$');
  static const _holder = (kind: VaultHolderKind.device, id: 'native');
  static final _redirect = Uri.parse(
    'http://localhost:48175/auth/esi/callback',
  );

  @override
  String? get clientId => _store.setting('ccp-native-client-id');

  DeviceCharacter? get _selected {
    final id = int.tryParse(
      _store.setting(DeviceStore.selectedCharacterSetting) ?? '',
      radix: 10,
    );
    return id == null ? null : _store.character(id);
  }

  @override
  bool permitsServerGrant(String characterId) {
    try {
      final id = int.tryParse(characterId, radix: 10);
      final row = id == null ? null : _store.character(id);
      return row == null ||
          row.phase == DevicePhase.returned ||
          (row.phase == DevicePhase.identified && row.serverOrigin == null);
    } on Object {
      return false;
    }
  }

  @override
  bool ownsReservationFor(String origin, String characterId) {
    try {
      final id = int.tryParse(characterId, radix: 10);
      final row = id == null ? null : _store.character(id);
      return row != null && _holdsReservationFor(row, origin);
    } on Object {
      return false;
    }
  }

  static bool _holdsReservationFor(DeviceCharacter row, String origin) =>
      row.serverOrigin == origin &&
      row.assignment != null &&
      row.proofDigest != null &&
      (row.phase == DevicePhase.deviceReserved ||
          row.phase == DevicePhase.solo ||
          row.phase == DevicePhase.blocked);

  @override
  AccountPilot? get pilot {
    final row = _selected;
    if (row == null) return null;
    return AccountPilot(
      characterId: row.characterId.toString(),
      name: row.name,
      holder: row.phase.name,
    );
  }

  @override
  AccountNotice configure(String clientId) {
    try {
      if (!_registration.hasMatch(clientId) || _running != null || _closing) {
        return AccountNotice.unavailable;
      }
      final row = _selected;
      if (row != null &&
          row.registration != clientId &&
          row.phase != DevicePhase.identified &&
          row.phase != DevicePhase.returned) {
        return AccountNotice.blocked;
      }
      _store.setSetting('ccp-native-client-id', clientId);
      return AccountNotice.none;
    } on Object {
      return AccountNotice.unavailable;
    }
  }

  @override
  Future<AccountNotice> identify() => _act(() async {
    final registration = clientId;
    if (registration == null) return AccountNotice.unavailable;
    final selected = _selected;
    if (selected != null &&
        const {
          DevicePhase.taking,
          DevicePhase.returning,
          DevicePhase.joining,
          DevicePhase.blocked,
        }.contains(selected.phase)) {
      return AccountNotice.blocked;
    }
    final result = await _pkce.run(
      clientId: registration,
      scopes: const {},
      launch: _launch,
    );
    if (result is! NativeSignedGrant) return _failed(result);
    final identity = result.identity;
    if (selected?.phase == DevicePhase.deviceReserved &&
        identity.characterId != selected!.characterId) {
      return AccountNotice.blocked;
    }
    final row = _store.character(identity.characterId);
    // A denied identity check must not reopen a completed Return.
    if (row?.phase == DevicePhase.returned) return AccountNotice.blocked;
    if (row?.phase == DevicePhase.deviceReserved &&
        (row!.ownerFingerprint !=
                _owner(identity.characterId, identity.owner) ||
            await _store.proof(row) == null)) {
      return AccountNotice.blocked;
    }
    if (row != null && row.owner.isNotEmpty && row.owner != identity.owner) {
      _store.save(_change(row, phase: DevicePhase.blocked));
      return AccountNotice.blocked;
    }
    if (row != null &&
        row.phase != DevicePhase.identified &&
        row.phase != DevicePhase.deviceReserved &&
        row.phase != DevicePhase.solo) {
      return AccountNotice.blocked;
    }
    if (row != null &&
        row.phase != DevicePhase.identified &&
        row.registration != registration) {
      return AccountNotice.blocked;
    }
    final identified = row == null || row.phase == DevicePhase.identified
        ? _newRow(
            identity.characterId,
            identity.owner,
            identity.name,
            registration,
          )
        : _change(row, owner: identity.owner, name: identity.name);
    _select(identified);
    return AccountNotice.none;
  });

  @override
  Future<AccountNotice> authorizeSkills({
    SavedTakeSource? source,
  }) => _act(() async {
    _authorizationCancelled = false;
    final row = _selected;
    if (row == null ||
        row.owner.isEmpty ||
        row.registration != clientId ||
        !const {
          DevicePhase.identified,
          DevicePhase.deviceReserved,
          DevicePhase.solo,
        }.contains(row.phase)) {
      return AccountNotice.blocked;
    }
    ({SavedTakeSource source, String proof, int generation})? reservation;
    if (row.serverOrigin case final origin?) {
      final generation = row.assignment;
      if (source == null ||
          generation == null ||
          source.remote.origin != origin ||
          source.remote.pilot.characterId != row.characterId.toString() ||
          !source.isCurrent()) {
        return AccountNotice.blocked;
      }
      final proof = await _store.proof(row);
      if (proof == null) return AccountNotice.blocked;
      if (_authorizationCancelled || !source.isCurrent()) {
        return AccountNotice.cancelled;
      }
      reservation = (source: source, proof: proof, generation: generation);
    }
    final opted = _change(
      row,
      optInRevision: row.optInRevision.isEven
          ? row.optInRevision + 1
          : row.optInRevision,
    );
    _store.save(opted);
    final scopes = _scopes(opted);
    final result = await _pkce.run(
      clientId: row.registration,
      scopes: scopes,
      launch: _launch,
    );
    if (result is! NativeSignedGrant) return _failed(result);
    final identity = result.identity;
    if (identity.characterId != row.characterId) return AccountNotice.blocked;
    if (identity.owner != row.owner) {
      _store.save(_change(opted, phase: DevicePhase.blocked));
      return AccountNotice.blocked;
    }
    final current = await _store.read(row.characterId);
    if (reservation case (
      source: final origin,
      :final proof,
      :final generation,
    )) {
      if (_authorizationCancelled || !origin.isCurrent()) {
        return AccountNotice.cancelled;
      }
      final fingerprint = _owner(identity.characterId, identity.owner);
      if (fingerprint != row.ownerFingerprint) return AccountNotice.blocked;
      final notice = await origin.remote.confirmTake(
        proof,
        '$generation',
        fingerprint,
      );
      // Confirmation is the final await before submitting the vault write.
      if (_authorizationCancelled || !origin.isCurrent()) {
        return AccountNotice.cancelled;
      }
      if (notice != AccountNotice.none) return notice;
      if (!identity.expiresAt.isAfter(_now())) return AccountNotice.reauthorize;
    }
    final active = await _vault.activate(
      character: row.characterId,
      holder: _holder,
      expectedGeneration: current?.authorization.generation ?? 0,
      refreshToken: result.grant.refreshToken,
      bearer: VaultBearer(result.grant.accessToken, identity.expiresAt),
    );
    if (active is! VaultSuccess<VaultAuthorization>) {
      return AccountNotice.unavailable;
    }
    _select(
      _change(
        opted,
        phase: DevicePhase.solo,
        name: identity.name,
        vaultGeneration: active.value.generation,
        grantRevision: opted.optInRevision,
      ),
    );
    return AccountNotice.none;
  });

  @override
  Future<AccountNotice> disableSkills() => _act(() async {
    final row = _selected;
    if (row == null || row.optInRevision.isEven) return AccountNotice.none;
    _store.save(_change(row, optInRevision: row.optInRevision + 1));
    return AccountNotice.none;
  });

  @override
  Future<AccountNotice> take(HolderRemote remote) => _act(() => _take(remote));

  Future<AccountNotice> _take(HolderRemote remote) async {
    final id = int.tryParse(remote.pilot.characterId, radix: 10);
    final registration = clientId;
    if (id == null || id <= 0 || registration == null) {
      return AccountNotice.unavailable;
    }
    var row = _store.character(id);
    var fresh = false;
    if (row?.phase == DevicePhase.deviceReserved ||
        row?.phase == DevicePhase.solo) {
      if (row!.serverOrigin != remote.origin) return AccountNotice.blocked;
      _select(row);
      return AccountNotice.none;
    }
    if (row == null ||
        row.phase == DevicePhase.returned ||
        row.phase == DevicePhase.identified && row.serverOrigin == null) {
      final int? epoch;
      switch (await remote.prepareTake()) {
        case DeviceTakeEpoch(epoch: final value):
          epoch = value;
        case DeviceTakeLegacy():
          epoch = null;
        case DeviceTakeUnprepared(:final notice):
          return notice;
      }
      final digest = await _store.newProof(id);
      row = _change(
        _newRow(id, '', remote.pilot.name, registration),
        phase: DevicePhase.taking,
        serverOrigin: remote.origin,
        proofDigest: digest,
      );
      _store.beginTake(row, epoch);
      fresh = true;
    }
    if (row.phase != DevicePhase.taking ||
        row.serverOrigin != remote.origin ||
        row.registration != registration) {
      return AccountNotice.blocked;
    }
    final recovery = _store.takeRecovery(id);
    if (recovery != null && recovery.digest != row.proofDigest) {
      return AccountNotice.blocked;
    }
    final epoch = recovery?.epoch;
    final proof = await _store.proof(row);
    if (proof == null) return AccountNotice.blocked;
    final result = epoch == null
        ? await remote.take(proof)
        : await remote.takeIntent(proof, epoch, reconcile: !fresh);
    switch (result) {
      case DeviceTakeRefused():
        if (fresh && epoch == null) {
          await _store.restoreRefusedTake(row);
        }
        return AccountNotice.blocked;
      case DeviceTakeNotAccepted():
        if (epoch == null) return AccountNotice.blocked;
        // Throws if the rollback does not commit; proof cleanup after the
        // commit cannot change this notice. A fresh take keeps the existing
        // blocked notice; only recovery explains that a new Take can start.
        await _store.restoreRefusedTake(row);
        return fresh ? AccountNotice.blocked : AccountNotice.takeNotAccepted;
      case DeviceTakePending():
        return fresh ? AccountNotice.pending : AccountNotice.takeUnconfirmed;
      case DeviceTakeIncomplete(:final notice):
        return notice;
      case DeviceReservation(:final generation, :final ownerFingerprint):
        final assignment = int.tryParse(generation, radix: 10);
        if (assignment == null ||
            assignment <= 0 ||
            !_hash.hasMatch(ownerFingerprint)) {
          return AccountNotice.unavailable;
        }
        _store.finishTake(
          row,
          _change(
            row,
            phase: DevicePhase.deviceReserved,
            assignment: assignment,
            ownerFingerprint: ownerFingerprint,
          ),
        );
        return AccountNotice.none;
    }
  }

  @override
  Future<AccountNotice> returnTo(HolderRemote remote) => _act(() async {
    final id = int.tryParse(remote.pilot.characterId, radix: 10);
    if (id == null) return AccountNotice.blocked;
    var row = _store.character(id);
    if (row == null) {
      return AccountNotice.blocked;
    }
    if (row.phase == DevicePhase.taking) {
      final pending = await _take(remote);
      if (pending != AccountNotice.none) return pending;
      row = _store.character(id)!;
    }
    if (row.serverOrigin == null && row.phase == DevicePhase.solo) {
      final digest = await _store.newProof(id);
      row = _change(
        row,
        phase: DevicePhase.joining,
        serverOrigin: remote.origin,
        proofDigest: digest,
      );
      _select(row);
    } else if (_holdsReservationFor(row, remote.origin)) {
      row = _change(row, phase: DevicePhase.returning);
      _select(row);
    }
    if (row.serverOrigin != remote.origin ||
        (row.phase != DevicePhase.returning &&
            row.phase != DevicePhase.joining)) {
      return AccountNotice.blocked;
    }
    final proof = await _store.proof(row);
    if (proof == null) return AccountNotice.blocked;
    // Check the real vault even if the journal still says no grant committed.
    // This also repairs the interval between a successful park and a lost ack.
    final snapshot = await _store.read(id);
    if (snapshot != null && snapshot.status != VaultStatus.parked) {
      final done = await _vault.park(snapshot.authorization);
      if (done is! VaultSuccess<VaultAuthorization>) {
        return AccountNotice.pending;
      }
    }
    if (row.phase == DevicePhase.joining) {
      if (row.owner.isEmpty) return AccountNotice.blocked;
      final joined = await remote.join(proof, _owner(id, row.owner));
      if (joined == AccountNotice.none) {
        _select(_change(row, phase: DevicePhase.returned));
      }
      return joined;
    }
    final generation = row.assignment;
    if (generation == null) return AccountNotice.blocked;
    final released = await remote.release(proof, generation.toString());
    if (released == AccountNotice.none) {
      _select(_change(row, phase: DevicePhase.returned));
    }
    return released;
  });

  @override
  Future<SkillsRead> skills() =>
      _one<SkillsRead>((AccountNotice.unavailable, null, null), () async {
        final row = _selected;
        if (row == null) return (AccountNotice.blocked, null, null);
        final auth = await _live(row);
        if (auth == null) return (AccountNotice.blocked, null, null);
        if (await _vault.bearer(auth) case VaultFailure(:final reason)) {
          return (
            reason == VaultFailureReason.reLoginRequired
                ? AccountNotice.reauthorize
                : AccountNotice.unavailable,
            null,
            null,
          );
        }
        final result = await _esi.scheduler
            .client(
              EsiPriority.interactive,
              principal: EsiPrincipal(
                application: row.registration,
                character: row.characterId,
                generation: auth.generation.toString(),
                bearer: () async => switch (await _vault.readBearer(auth)) {
                  VaultSuccess(:final value) => value.token,
                  _ => null,
                },
              ),
            )
            .getCharactersCharacterIdSkills(characterId: row.characterId);
        return switch (result) {
          EsiSuccess(:final body) => (
            AccountNotice.none,
            (count: body.skills.length, totalSp: body.totalSp),
            null,
          ),
          EsiNotSent(:final refusal) => (
            AccountNotice.none,
            null,
            (reason: refusal.reason, retryAt: refusal.retryAt),
          ),
          _ => (AccountNotice.unavailable, null, null),
        };
      });

  Future<VaultAuthorization?> _live(DeviceCharacter row) async {
    if (row.phase != DevicePhase.solo ||
        row.vaultGeneration == null ||
        row.optInRevision.isEven ||
        row.grantRevision != row.optInRevision ||
        row.registration != clientId ||
        row.serverOrigin != null &&
            (row.assignment == null || await _store.proof(row) == null)) {
      return null;
    }
    final auth = (
      character: row.characterId,
      holder: _holder,
      generation: row.vaultGeneration!,
    );
    return (await _store.read(row.characterId))?.authorization == auth
        ? auth
        : null;
  }

  Future<VaultRefreshReply> _refresh(
    VaultAuthorization auth,
    String refreshToken,
  ) async {
    final row = _store.character(auth.character);
    if (row == null || await _live(row) != auth) {
      return const VaultRefreshUnverifiedGrant();
    }
    final reply = await _oauth.refresh(
      CcpPublic(row.registration, _redirect),
      refreshToken,
    );
    switch (reply) {
      case CcpExchangeFailure.rejected:
        return const VaultRefreshInvalidGrant();
      case CcpExchangeFailure.unavailable:
        return const VaultRefreshTemporaryFailure();
      case CcpGrant():
        final checked = await _verifier.verify(
          reply.accessToken,
          clientId: row.registration,
        );
        switch (checked) {
          case CcpJwtFailure.unavailable:
            return const VaultRefreshTemporaryFailure();
          case CcpJwtFailure.invalid:
            return const VaultRefreshUnverifiedGrant();
          case CcpVerifiedIdentity():
            if (checked.characterId == auth.character &&
                checked.owner != row.owner) {
              _store.save(_change(row, phase: DevicePhase.blocked));
              return const VaultRefreshUnverifiedGrant();
            }
            if (checked.characterId != auth.character ||
                !matchesGrantedScopes(_scopes(row), checked.scopes)) {
              return const VaultRefreshUnverifiedGrant();
            }
            return VaultRefreshSuccess(
              VaultBearer(reply.accessToken, checked.expiresAt),
              replacementRefreshToken: reply.refreshToken,
            );
        }
    }
  }

  static Set<String> _scopes(DeviceCharacter row) {
    final policy = ScopePolicy.personalSkills;
    return policy.scopesFor(
      row.characterId,
      row.owner,
      optIn: row.optInRevision.isEven
          ? null
          : ScopeOptIn(
              characterId: row.characterId,
              owner: row.owner,
              policyFingerprint: policy.fingerprint,
              scopeClass: ScopeClass.characterSkills,
            ),
    );
  }

  void _select(DeviceCharacter row) {
    _store.save(row);
    _store.setSetting(
      DeviceStore.selectedCharacterSetting,
      row.characterId.toString(),
    );
  }

  Future<AccountNotice> _act(Future<AccountNotice> Function() action) =>
      _one(AccountNotice.pending, action, onError: AccountNotice.unavailable);

  Future<T> _one<T>(
    T unready,
    Future<T> Function() action, {
    T? onError,
  }) async {
    if (_running != null || _closing) return unready;
    final current = Future<T>.sync(action);
    _running = current;
    try {
      return await current;
    } on Object {
      return onError ?? unready;
    } finally {
      _running = null;
    }
  }

  @override
  void cancel() {
    _authorizationCancelled = true;
    _pkce.cancel();
  }

  @override
  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    cancel();
    _esi.close();
    _http.close();
    try {
      await _running;
    } on Object {
      // The command owner observes the fixed outcome.
    } finally {
      await _store.close();
    }
  }

  static String _owner(int character, String owner) =>
      sha256.convert(utf8.encode('$character:$owner')).toString();

  static AccountNotice _failed(NativePkceResult result) => switch (result) {
    NativePkceFailure.cancelled => AccountNotice.cancelled,
    NativePkceFailure.rejected => AccountNotice.blocked,
    _ => AccountNotice.unavailable,
  };
}

DeviceCharacter _newRow(
  int id,
  String owner,
  String name,
  String registration,
) => (
  characterId: id,
  owner: owner,
  name: name,
  registration: registration,
  optInRevision: 0,
  grantRevision: null,
  phase: DevicePhase.identified,
  serverOrigin: null,
  assignment: null,
  proofDigest: null,
  vaultGeneration: null,
  ownerFingerprint: null,
);

DeviceCharacter _change(
  DeviceCharacter source, {
  String? owner,
  String? name,
  DevicePhase? phase,
  String? serverOrigin,
  int? assignment,
  String? proofDigest,
  int? vaultGeneration,
  String? ownerFingerprint,
  int? optInRevision,
  int? grantRevision,
}) => (
  characterId: source.characterId,
  owner: owner ?? source.owner,
  name: name ?? source.name,
  registration: source.registration,
  optInRevision: optInRevision ?? source.optInRevision,
  grantRevision: grantRevision ?? source.grantRevision,
  phase: phase ?? source.phase,
  serverOrigin: serverOrigin ?? source.serverOrigin,
  assignment: assignment ?? source.assignment,
  proofDigest: proofDigest ?? source.proofDigest,
  vaultGeneration: vaultGeneration ?? source.vaultGeneration,
  ownerFingerprint: ownerFingerprint ?? source.ownerFingerprint,
);
