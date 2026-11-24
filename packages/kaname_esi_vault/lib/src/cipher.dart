import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'contract.dart';

const _tokenLimit = 16384;
const _version = 1;
const _header = 10;

/// Indicates malformed input without retaining the value.
bool validToken(String token) =>
    token.isNotEmpty &&
    token.length <= _tokenLimit &&
    token.codeUnits.every((unit) => unit >= 0x21 && unit <= 0x7e);

/// Plaintext, confined to the vault and never supplied to a store.
typedef Credential = ({String refresh, VaultBearer? bearer});

/// Versioned AEAD envelope bound to a single holder authorization.
final class VaultCipher {
  /// Loads the dedicated key or fails before any vault operation.
  VaultCipher(String? base64Key) : _key = _readKey(base64Key);

  final SecretKey _key;
  final Xchacha20 _cipher = Xchacha20.poly1305Aead();

  static SecretKey _readKey(String? encoded) {
    if (encoded?.length != 44) throw const VaultKeyConfigurationException();
    try {
      final key = base64Decode(encoded!);
      if (key.length == 32 && base64Encode(key) == encoded) {
        return SecretKey(key);
      }
    } on FormatException {
      throw const VaultKeyConfigurationException();
    }
    throw const VaultKeyConfigurationException();
  }

  static List<int> _aad(VaultAuthorization auth) => utf8.encode(
    jsonEncode([
      'kaname-esi-vault',
      _version,
      auth.character,
      auth.holder.kind.name,
      auth.holder.id,
      auth.generation,
    ]),
  );

  /// Seals a bounded payload with a fresh random nonce and an authenticated binding.
  Future<String> seal(VaultAuthorization auth, Credential credential) async {
    final (:refresh, :bearer) = credential;
    final access = bearer?.token;
    final bytes = Uint8List(_header + refresh.length + (access?.length ?? 0));
    ByteData.sublistView(bytes)
      ..setUint16(0, refresh.length)
      ..setInt64(2, bearer?.expiresAt.microsecondsSinceEpoch ?? 0);
    bytes.setRange(_header, _header + refresh.length, refresh.codeUnits);
    if (access != null)
      bytes.setRange(_header + refresh.length, bytes.length, access.codeUnits);
    final box = await _cipher.encrypt(bytes, secretKey: _key, aad: _aad(auth));
    final cipherStart = 1 + box.nonce.length;
    final macStart = cipherStart + box.cipherText.length;
    final envelope = Uint8List(macStart + box.mac.bytes.length)
      ..[0] = _version
      ..setRange(1, cipherStart, box.nonce)
      ..setRange(cipherStart, macStart, box.cipherText)
      ..setRange(macStart, macStart + box.mac.bytes.length, box.mac.bytes);
    return base64Encode(envelope);
  }

  /// Opens only bounded, authenticated data for [row]'s own authorization.
  Future<Credential> open(VaultRecord row) async {
    final encoded = row.sealedCredential;
    final nonceLength = _cipher.nonceLength;
    final macLength = _cipher.macAlgorithm.macLength;
    final overhead = 1 + nonceLength + macLength + _header;
    if (encoded == null ||
        encoded.length > ((overhead + 2 * _tokenLimit + 2) ~/ 3) * 4) {
      throw const FormatException('Invalid vault envelope');
    }
    final bytes = base64Decode(encoded);
    if (bytes.length <= overhead ||
        bytes.length > overhead + 2 * _tokenLimit ||
        bytes[0] != _version) {
      throw const FormatException('Invalid vault envelope');
    }
    final clear = await _cipher.decrypt(
      SecretBox.fromConcatenation(
        Uint8List.sublistView(bytes, 1),
        nonceLength: nonceLength,
        macLength: macLength,
        copy: false,
      ),
      secretKey: _key,
      aad: _aad(row.authorization),
    );
    final header = ByteData.sublistView(
      clear is Uint8List
          ? clear
          : Uint8List.fromList(clear.take(_header).toList()),
      0,
      _header,
    );
    final split = _header + header.getUint16(0);
    if (split <= _header || split > clear.length)
      throw const FormatException('Invalid vault payload');
    final refresh = String.fromCharCodes(clear, _header, split);
    final access = split == clear.length
        ? null
        : String.fromCharCodes(clear, split);
    if (!validToken(refresh) || (access != null && !validToken(access))) {
      throw const FormatException('Invalid vault payload');
    }
    return (
      refresh: refresh,
      bearer: access == null
          ? null
          : VaultBearer(
              access,
              DateTime.fromMicrosecondsSinceEpoch(
                header.getInt64(2),
                isUtc: true,
              ),
            ),
    );
  }
}
