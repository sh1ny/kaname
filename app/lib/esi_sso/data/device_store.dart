import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:kaname_esi_sso/kaname_esi_sso.dart';
import 'package:kaname_esi_vault/kaname_esi_vault.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Desktop keyring boundary; SQLite never stores either of these secrets.
abstract interface class DeviceSecrets {
  /// Returns a stored secret, or null when it has not been provisioned.
  Future<String?> read(String name);

  /// Saves a new secret. Callers require read-back before relying on it.
  Future<void> write(String name, String secret);

  /// Removes a secret after the journal no longer references it.
  Future<void> delete(String name);
}

/// Durable phase of a desktop authorization or transition (ADR 0017).
enum DevicePhase {
  /// Signed in with no committed ESI credential.
  identified,

  /// Proof saved locally; source has not confirmed parking.
  taking,

  /// Source has confirmed parking; this device has not yet activated.
  deviceReserved,

  /// Locally active with a matching vault generation.
  solo,

  /// No future native dispatch; finish parking and send the release proof.
  returning,

  /// No future native dispatch; finish parking and ask a new server to join.
  joining,

  /// This device has released the holder.
  returned,

  /// A signed owner mismatch or local trust failure blocks this identity.
  blocked,
}

/// Non-secret desktop credentials metadata and holder journal.
typedef DeviceCharacter = ({
  int characterId,
  String owner,
  String name,
  String registration,
  int optInRevision,
  int? grantRevision,
  DevicePhase phase,
  String? serverOrigin,
  int? assignment,
  String? proofDigest,
  int? vaultGeneration,
  String? ownerFingerprint,
});

/// The installation's exclusive credential database and device journal.
final class DeviceStore implements VaultStore {
  DeviceStore._(
    this._db,
    this._lock,
    this._path,
    this._secrets,
    this.installKey,
  );

  /// The setting that names the selected native character.
  static const selectedCharacterSetting = 'selected-character';

  static final _opened = <String>{};
  static final _random = Random.secure();
  final Database _db;
  final RandomAccessFile _lock;
  final String _path;
  final DeviceSecrets _secrets;
  bool _writing = false;
  bool _closed = false;

  /// The dedicated install key read from OS secure storage.
  final String installKey;

  /// Opens with an OS lock for the life of the vault and a verified keyring.
  ///
  /// Missing keys for an existing database, unavailable storage, and a second
  /// process fail closed. A partially initialized database is never reset.
  static Future<DeviceStore> open(
    Directory directory,
    DeviceSecrets secrets,
  ) async {
    await directory.create(recursive: true);
    final path = await directory.resolveSymbolicLinks();
    if (!_opened.add(path)) {
      throw StateError('Device credential store already open');
    }
    RandomAccessFile? lock;
    Database? db;
    try {
      lock = await File(p.join(path, 'esi-holder.lock'))
          .open(mode: FileMode.append);
      await lock.lock(FileLock.exclusive);
      final file = p.join(path, 'esi-credentials.sqlite');
      final existing = await File(file).exists();
      var key = await secrets.read('kaname/esi-install-key');
      if (key == null && !existing) {
        final created = base64Encode(
          List.generate(32, (_) => _random.nextInt(256)),
        );
        await secrets.write('kaname/esi-install-key', created);
        key = await secrets.read('kaname/esi-install-key');
        if (key != created) throw StateError('Cannot verify secure storage');
      }
      if (key == null || !_validKey(key)) {
        throw StateError('Device credential key unavailable');
      }
      db = sqlite3.open(file);
      db.execute('PRAGMA synchronous=FULL');
      db.execute('PRAGMA fullfsync=ON');
      final digest = sha256.convert(utf8.encode(key)).toString();
      if (!existing) {
        db.execute('BEGIN IMMEDIATE');
        db.execute('''
CREATE TABLE setting(name TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL);
CREATE TABLE character(character INTEGER PRIMARY KEY, owner TEXT NOT NULL,
 name TEXT NOT NULL, registration TEXT NOT NULL, opt_in INTEGER NOT NULL,
 grant_revision INTEGER, phase TEXT NOT NULL, origin TEXT, assignment INTEGER,
 proof_digest TEXT, vault_generation INTEGER, owner_fingerprint TEXT);
CREATE TABLE vault(character INTEGER PRIMARY KEY, holder TEXT NOT NULL,
 generation INTEGER NOT NULL, status TEXT NOT NULL, ciphertext TEXT,
 fence INTEGER NOT NULL, lease_ms INTEGER);
PRAGMA user_version=1;
''');
        db.execute('INSERT INTO setting VALUES (?,?)', [
          'key-verifier',
          digest,
        ]);
        db.execute('COMMIT');
      }
      if (db.select('PRAGMA user_version').single.values.single != 1 ||
          db
                  .select("SELECT value FROM setting WHERE name='key-verifier'")
                  .single['value'] !=
              digest) {
        throw StateError('Device credential store does not match this key');
      }
      return DeviceStore._(db, lock, path, secrets, key);
    } on Object {
      db?.close();
      await lock?.close();
      _opened.remove(path);
      rethrow;
    }
  }

  static bool _validKey(String key) {
    try {
      final bytes = base64Decode(key);
      return bytes.length == 32 && base64Encode(bytes) == key;
    } on FormatException {
      return false;
    }
  }

  /// Reads a non-secret setting such as the public client ID.
  String? setting(String name) =>
      _db.select('SELECT value FROM setting WHERE name=?', [
            name,
          ]).firstOrNull?['value']
          as String?;

  /// Commits a non-secret setting. Do not use this for tokens or device proof.
  void setSetting(String name, String value) => _db.execute(
    '''
INSERT INTO setting VALUES (?,?) ON CONFLICT(name) DO UPDATE SET value=excluded.value
''',
    [name, value],
  );

  /// Reads durable state before any local dispatch or transition.
  DeviceCharacter? character(int id) {
    final row = _db.select('SELECT * FROM character WHERE character=?', [
      id,
    ]).firstOrNull;
    if (row == null) return null;
    return (
      characterId: id,
      owner: row['owner'] as String,
      name: row['name'] as String,
      registration: row['registration'] as String,
      optInRevision: row['opt_in'] as int,
      grantRevision: row['grant_revision'] as int?,
      phase: DevicePhase.values.byName(row['phase'] as String),
      serverOrigin: row['origin'] as String?,
      assignment: row['assignment'] as int?,
      proofDigest: row['proof_digest'] as String?,
      vaultGeneration: row['vault_generation'] as int?,
      ownerFingerprint: row['owner_fingerprint'] as String?,
    );
  }

  /// Commits a journal transition before network work can observe it.
  void save(DeviceCharacter row) => _db.execute(
    '''
INSERT INTO character VALUES(?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(character) DO UPDATE SET
 owner=excluded.owner, name=excluded.name, registration=excluded.registration,
 opt_in=excluded.opt_in, grant_revision=excluded.grant_revision, phase=excluded.phase,
 origin=excluded.origin, assignment=excluded.assignment, proof_digest=excluded.proof_digest,
 vault_generation=excluded.vault_generation, owner_fingerprint=excluded.owner_fingerprint
''',
    [
      row.characterId,
      row.owner,
      row.name,
      row.registration,
      row.optInRevision,
      row.grantRevision,
      row.phase.name,
      row.serverOrigin,
      row.assignment,
      row.proofDigest,
      row.vaultGeneration,
      row.ownerFingerprint,
    ],
  );

  /// Restores the state saved before a fresh take that the server refused.
  ///
  /// The caller must not use this on a resumed journal. Commit the row and
  /// selection together before touching the keyring, so an interrupted
  /// rollback cannot destroy the proof of a still-pending journal.
  Future<void> restoreRefusedTake(
    int character,
    String digest, {
    required DeviceCharacter? previous,
    required String? selection,
  }) async {
    _db.execute('BEGIN IMMEDIATE');
    try {
      if (previous == null) {
        _db.execute('DELETE FROM character WHERE character=?', [character]);
      } else {
        save(previous);
      }
      if (selection == null) {
        _db.execute('DELETE FROM setting WHERE name=?', [
          selectedCharacterSetting,
        ]);
      } else {
        setSetting(selectedCharacterSetting, selection);
      }
      _db.execute('COMMIT');
    } on Object {
      _db.execute('ROLLBACK');
      rethrow;
    }

    try {
      await _secrets.delete(_proofKey(character, digest));
    } on Object {
      // The rollback committed. A keyring failure can only leave an unused proof.
    }
  }

  /// Stores a new random transition proof in the keyring and returns its digest.
  Future<String> newProof(int character) async {
    final proof = newOAuthProof();
    final digest = sha256.convert(utf8.encode(proof)).toString();
    final key = _proofKey(character, digest);
    await _secrets.write(key, proof);
    if (await _secrets.read(key) != proof) {
      throw StateError('Cannot verify device proof');
    }
    return digest;
  }

  /// Reads a saved proof only when it still matches the journal. No fallback.
  Future<String?> proof(DeviceCharacter row) async {
    final expected = row.proofDigest;
    if (expected == null) return null;
    final value = await _secrets.read(_proofKey(row.characterId, expected));
    return value != null &&
            sha256.convert(utf8.encode(value)).toString() == expected
        ? value
        : null;
  }

  static String _proofKey(int character, String digest) =>
      'kaname/esi-proof/$character/$digest';

  @override
  Future<VaultRecord?> read(int character) async => _read(character);

  VaultRecord? _read(int character) {
    final row = _db.select('SELECT * FROM vault WHERE character=?', [
      character,
    ]).firstOrNull;
    if (row == null) return null;
    final lease = row['lease_ms'] as int?;
    return VaultRecord(
      authorization: (
        character: character,
        holder: (kind: VaultHolderKind.device, id: row['holder'] as String),
        generation: row['generation'] as int,
      ),
      status: VaultStatus.values.byName(row['status'] as String),
      sealedCredential: row['ciphertext'] as String?,
      fence: row['fence'] as int,
      leaseUntil: lease == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lease, isUtc: true),
    );
  }

  @override
  Future<T?> withCharacter<T extends Object>(
    int character, {
    required bool wait,
    required Future<VaultWrite<T>> Function(VaultRecord?) update,
  }) async {
    if (_writing) return null;
    _writing = true;
    try {
      _db.execute('BEGIN IMMEDIATE');
      try {
        final result = await update(_read(character));
        if (result.next case final next?) {
          _db.execute(
            '''
INSERT INTO vault VALUES (?,?,?,?,?,?,?) ON CONFLICT(character) DO UPDATE SET
 holder=excluded.holder, generation=excluded.generation, status=excluded.status,
 ciphertext=excluded.ciphertext, fence=excluded.fence, lease_ms=excluded.lease_ms
''',
            [
              character,
              next.authorization.holder.id,
              next.authorization.generation,
              next.status.name,
              next.sealedCredential,
              next.fence,
              next.leaseUntil?.millisecondsSinceEpoch,
            ],
          );
        }
        _db.execute('COMMIT');
        return result.value;
      } on Object {
        _db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      _writing = false;
    }
  }

  /// Closes the store after the owning runtime drains its last operation.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _db.close();
    try {
      await _lock.close();
    } finally {
      _opened.remove(_path);
    }
  }
}
