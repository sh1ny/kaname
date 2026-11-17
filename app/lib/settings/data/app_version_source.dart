import 'package:package_info_plus/package_info_plus.dart';

/// The text shown when the app version cannot be read.
const String unknownAppVersion = 'unknown';

/// Supplies the app version text shown in About.
abstract interface class AppVersionSource {
  /// Returns the version text, or [unknownAppVersion] when it cannot be read.
  ///
  /// Never throws.
  Future<String> read();
}

/// An [AppVersionSource] backed by `package_info_plus`.
///
/// The text is `version+build`, for example `0.0.1+1`; an empty build number
/// leaves just the version. The platform is queried once and the result is
/// reused.
final class PackageInfoAppVersionSource implements AppVersionSource {
  /// Creates the source, loading through [loader] or
  /// [PackageInfo.fromPlatform] when omitted.
  PackageInfoAppVersionSource({Future<PackageInfo> Function()? loader})
    : _loader = loader ?? PackageInfo.fromPlatform;

  final Future<PackageInfo> Function() _loader;
  Future<String>? _version;

  @override
  Future<String> read() => _version ??= _load();

  Future<String> _load() async {
    try {
      final PackageInfo(:version, :buildNumber) = await _loader();
      return buildNumber.isEmpty ? version : '$version+$buildNumber';
    } on Object {
      return unknownAppVersion;
    }
  }
}
