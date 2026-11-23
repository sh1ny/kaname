/// The trusted-proxy list, read from `KANAME_TRUSTED_PROXIES` at start-up
/// (D2).
library;

import 'dart:io';
import 'dart:typed_data';

import 'ip_address.dart';

/// The environment variable that holds the trusted proxies.
const String trustedProxiesVariable = 'KANAME_TRUSTED_PROXIES';

/// Reads the trusted proxies from [environment]'s [trustedProxiesVariable].
///
/// `serve()` calls it with the process environment before the pod starts,
/// so an invalid entry stops start-up with the [TrustedProxiesError] that
/// names it.
TrustedProxies readTrustedProxies(Map<String, String> environment) =>
    TrustedProxies.parse(environment[trustedProxiesVariable]);

/// An entry of [trustedProxiesVariable] that is not an IP address or CIDR
/// range, or is an IPv4-mapped range in IPv6 form.
final class TrustedProxiesError extends Error {
  /// Reports [entry], the first invalid entry, with [problem].
  TrustedProxiesError(this.entry, this.problem);

  /// The invalid entry, trimmed.
  final String entry;

  /// What is wrong with [entry].
  final String problem;

  @override
  String toString() => '$trustedProxiesVariable: "$entry" $problem';
}

/// The addresses and ranges whose connections are trusted to report their
/// client in `X-Forwarded-For` (D1, D2).
///
/// Trust matches the whole normalised address (an IPv4-mapped address as
/// IPv4) against a listed address or range. The /64 grouping of client keys
/// never applies here, so a trusted IPv6 host does not make its neighbours
/// trusted.
final class TrustedProxies {
  const TrustedProxies._(this._ranges);

  /// Trusts nobody: the default when the setting is unset or empty.
  static const TrustedProxies none = TrustedProxies._([]);

  /// Parses [setting], a comma-separated list of IP addresses and CIDR
  /// ranges, with whitespace around each entry ignored.
  ///
  /// A `null`, empty or blank setting trusts nobody. Throws a
  /// [TrustedProxiesError] naming the first entry that is not an address or
  /// range (an empty entry included), or that is an IPv4-mapped range
  /// written in IPv6 form.
  factory TrustedProxies.parse(String? setting) {
    if (setting == null || setting.trim().isEmpty) return none;
    return TrustedProxies._([
      for (final entry in setting.split(',')) _IpRange.parse(entry.trim()),
    ]);
  }

  final List<_IpRange> _ranges;

  /// Whether nobody is trusted.
  bool get isEmpty => _ranges.isEmpty;

  /// Whether [address] is a trusted proxy.
  bool trusts(InternetAddress address) {
    final bytes = normaliseIpAddress(address).rawAddress;
    return _ranges.any((range) => range.contains(bytes));
  }
}

/// One listed address (a full-length range) or CIDR range, normalised.
final class _IpRange {
  _IpRange(List<int> bytes, this.prefixLength)
    : network = maskBytes(bytes, prefixLength);

  factory _IpRange.parse(String entry) {
    final slash = entry.indexOf('/');
    final parsed = parseIpAddress(
      slash < 0 ? entry : entry.substring(0, slash),
    );
    if (parsed == null) throw _invalid(entry);
    if (slash < 0) {
      // A single address; an IPv4-mapped one is trusted as its IPv4 address.
      final address = normaliseIpAddress(parsed).rawAddress;
      return _IpRange(address, address.length * 8);
    }
    final prefixText = entry.substring(slash + 1);
    if (!RegExp(r'^[0-9]{1,3}$').hasMatch(prefixText)) throw _invalid(entry);
    final prefixLength = int.parse(prefixText);
    if (prefixLength > parsed.rawAddress.length * 8) throw _invalid(entry);
    if (isIpv4Mapped(parsed)) {
      throw TrustedProxiesError(
        entry,
        'is an IPv4-mapped range in IPv6 form; write the range as IPv4 '
        '(for example 172.30.0.0/24)',
      );
    }
    return _IpRange(parsed.rawAddress, prefixLength);
  }

  static TrustedProxiesError _invalid(String entry) =>
      TrustedProxiesError(entry, 'is not an IP address or CIDR range');

  final Uint8List network;
  final int prefixLength;

  bool contains(List<int> bytes) {
    if (bytes.length != network.length) return false;
    final masked = maskBytes(bytes, prefixLength);
    for (var i = 0; i < masked.length; i++) {
      if (masked[i] != network[i]) return false;
    }
    return true;
  }
}
