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
}
