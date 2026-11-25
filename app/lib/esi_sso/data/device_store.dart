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

  // A null owner means no prior row; a present row may have an empty owner.
  static const _takeRecoverySchema = '''
CREATE TABLE take_recovery(
 character INTEGER PRIMARY KEY, pending_digest TEXT NOT NULL,
 source_epoch INTEGER, prior_selection TEXT,
 owner TEXT, name TEXT, registration TEXT, opt_in INTEGER, grant_revision INTEGER,
 phase TEXT, origin TEXT, assignment INTEGER, proof_digest TEXT,
 vault_generation INTEGER, owner_fingerprint TEXT);
PRAGMA user_version=2;
''';

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
$_takeRecoverySchema
''');
        db.execute('INSERT INTO setting VALUES (?,?)', [
          'key-verifier',
          digest,
        ]);
        db.execute('COMMIT');
      }
      final version = db.select('PRAGMA user_version').single.values.single;
      if ((version != 1 && version != 2) ||
          db
                  .select("SELECT value FROM setting WHERE name='key-verifier'")
                  .single['value'] !=
              digest) {
        throw StateError('Device credential store does not match this key');
      }
      if (version == 1) {
        final opened = db;
        _transaction(opened, () => opened.execute(_takeRecoverySchema));
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

  /// Commits a take and its rollback snapshot before the caller sends it.
  ///
  /// `taking` references the new proof; the snapshot may also reference the
  /// prior proof until reservation or rollback commits. No proof is in SQLite.
  void beginTake(DeviceCharacter taking, int? sourceEpoch) {
    _transaction(_db, () {
      _db.execute(
        '''
INSERT INTO take_recovery
SELECT ?, ?, ?, ?, owner, name, registration, opt_in, grant_revision,
 phase, origin, assignment, proof_digest, vault_generation, owner_fingerprint
FROM (SELECT 1)
LEFT JOIN character ON character.character = ?
''',
        [
          taking.characterId,
          taking.proofDigest!,
          sourceEpoch,
          setting(selectedCharacterSetting),
          taking.characterId,
        ],
      );
      _saveSelected(taking);
    });
  }

  /// Returns the rollback snapshot's identity, not the prior row.
  ///
  /// No row means the take predates recovery. A null epoch in a present row
  /// means the source supported only the legacy take route.
  ({String digest, int? epoch})? takeRecovery(int id) {
    final row = _db.select(
      'SELECT pending_digest, source_epoch FROM take_recovery WHERE character=?',
      [id],
    ).firstOrNull;
    return row == null
        ? null
        : (
            digest: row['pending_digest'] as String,
            epoch: row['source_epoch'] as int?,
          );
  }

  /// Commits the reservation and drops only the rollback snapshot.
  void finishTake(DeviceCharacter taking, DeviceCharacter reserved) {
    _transaction(_db, () {
      if (character(taking.characterId) != taking) {
        throw StateError('Pending take changed');
      }
      _saveSelected(reserved);
      _deleteTakeRecovery(taking.characterId);
    });
  }

  /// Restores a definitively refused take after proof of non-acceptance.
  ///
  /// Commit before removing the rejected proof. Neither an unsuccessful
  /// transaction nor a reservation may delete the proof of a pending holder.
  Future<void> restoreRefusedTake(DeviceCharacter taking) async {
    final id = taking.characterId;
    final digest = taking.proofDigest!;
    _transaction(_db, () {
      final snapshot = _db.select(
        'SELECT pending_digest, prior_selection, owner FROM take_recovery WHERE character=?',
        [id],
      ).single;
      if (character(id) != taking ||
          taking.phase != DevicePhase.taking ||
          snapshot['pending_digest'] != digest) {
        throw StateError('Pending take changed');
      }
      if (snapshot['owner'] == null) {
        _db.execute('DELETE FROM character WHERE character=?', [id]);
      } else {
        _db.execute(
          '''
INSERT OR REPLACE INTO character
SELECT character, owner, name, registration, opt_in, grant_revision,
 phase, origin, assignment, proof_digest, vault_generation, owner_fingerprint
FROM take_recovery WHERE character=?
''',
          [id],
        );
      }
      if (setting(selectedCharacterSetting) == id.toString()) {
        final selection = snapshot['prior_selection'] as String?;
        final selectedId = selection == null ? null : int.tryParse(selection);
        if (selection != null &&
            selectedId != null &&
            character(selectedId) != null) {
          setSetting(selectedCharacterSetting, selection);
        } else {
          _db.execute('DELETE FROM setting WHERE name=?', [
            selectedCharacterSetting,
          ]);
        }
      }
      _deleteTakeRecovery(id);
    });

    try {
      await _secrets.delete(_proofKey(id, digest));
    } on Object {
      // The rollback committed. A keyring failure can only leave an unused proof.
    }
  }

  void _saveSelected(DeviceCharacter row) {
    save(row);
    setSetting(selectedCharacterSetting, row.characterId.toString());
  }

  void _deleteTakeRecovery(int character) =>
      _db.execute('DELETE FROM take_recovery WHERE character=?', [character]);

  static void _transaction(Database db, void Function() write) {
    db.execute('BEGIN IMMEDIATE');
    try {
      write();
      db.execute('COMMIT');
    } on Object {
      db.execute('ROLLBACK');
      rethrow;
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
