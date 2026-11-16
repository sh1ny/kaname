import 'dart:io';
import 'dart:typed_data';

import 'package:kaname_ember_ui/kaname_ember_ui.dart';

/// An asset source backed by the package's real files.
///
/// Keys look like `packages/kaname_ember_ui/fonts/...`; any key listed in
/// [without], or outside the package, fails the way a missing bundle asset
/// does. Tests run with the package root as the working directory.
AssetLoader diskAssets({Set<String> without = const {}}) {
  const prefix = 'packages/kaname_ember_ui/';
  return (key) async {
    if (without.contains(key) || !key.startsWith(prefix)) {
      throw StateError('Unable to load asset: "$key".');
    }
    final bytes = File(key.substring(prefix.length)).readAsBytesSync();
    return ByteData.sublistView(Uint8List.fromList(bytes));
  };
}
