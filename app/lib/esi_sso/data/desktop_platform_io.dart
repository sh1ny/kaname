import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'account_types.dart';
import 'device_store.dart';
import 'native_account.dart';

/// The supported desktop runtimes have a separate credential-only store.
bool get hasDesktopHolder =>
    Platform.isLinux || Platform.isWindows || Platform.isMacOS;

/// Opens the OS-backed credential runtime and fails closed if it is locked.
Future<DesktopAccount?> openDesktopHolder() async {
  if (!hasDesktopHolder) return null;
  DeviceStore? store;
  http.Client? client;
  try {
    final support = await getApplicationSupportDirectory();
    store = await DeviceStore.open(
      Directory(p.join(support.path, 'esi-credentials')),
      const _Keyring(),
      diagnostic: (message) => developer.log(message, name: 'kaname.esi_sso'),
    );
    client = http.Client();
    return NativeAccount(
      store: store,
      httpClient: client,
      launch: (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
    );
  } on Object {
    client?.close();
    await store?.close();
    return null;
  }
}

/// Adapts secure storage to exact-name operations for the desktop journal.
///
/// Windows cannot reliably confirm that a key is absent. Its legacy lookup
/// can treat an inaccessible file as missing, so a failed delete stays
/// tracked until a later delete succeeds.
final class _Keyring implements DeviceSecrets {
  const _Keyring();
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String name) => _storage.read(key: name);

  @override
  Future<void> write(String name, String secret) =>
      _storage.write(key: name, value: secret);

  @override
  Future<void> delete(String name) => _storage.delete(key: name);

  @override
  Future<bool> contains(String name) async {
    if (Platform.isWindows) {
      throw StateError('Cannot confirm secure storage entry is absent');
    }
    return _storage.containsKey(key: name);
  }
}
