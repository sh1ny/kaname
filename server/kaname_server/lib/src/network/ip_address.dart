/// Strict parsing and normalisation of IP addresses, shared by the
/// trusted-proxy list and client identity (D1, D3).
library;

import 'dart:io';
import 'dart:typed_data';

final RegExp _addressCharacters = RegExp(r'^[0-9A-Fa-f.:]+$');

/// Parses [text] as a bare IPv4 or IPv6 address, or returns `null`.
///
/// Only hexadecimal digits, dots and colons are accepted, so a host name, a
/// zone index (`fe80::1%eth0`), a port or a prefix length is never read as
/// part of an address.
InternetAddress? parseIpAddress(String text) {
  if (!_addressCharacters.hasMatch(text)) return null;
  final address = InternetAddress.tryParse(text);
  return switch (address?.type) {
    InternetAddressType.IPv4 || InternetAddressType.IPv6 => address,
    _ => null,
  };
}

/// Whether [address] is an IPv4-mapped IPv6 address (`::ffff:a.b.c.d`).
bool isIpv4Mapped(InternetAddress address) {
  if (address.type != InternetAddressType.IPv6) return false;
  final bytes = address.rawAddress;
  for (var i = 0; i < 10; i++) {
    if (bytes[i] != 0) return false;
  }
  return bytes[10] == 0xff && bytes[11] == 0xff;
}

/// [address], or the IPv4 address it maps when it is IPv4-mapped IPv6 (D3).
InternetAddress normaliseIpAddress(InternetAddress address) {
  if (!isIpv4Mapped(address)) return address;
  return InternetAddress.fromRawAddress(
    Uint8List.fromList(address.rawAddress.sublist(12)),
  );
}

/// Whether [address] is the unspecified address (`0.0.0.0` or `::`), which
/// a connection reports when its peer is not known.
bool isUnspecified(InternetAddress address) =>
    address.rawAddress.every((byte) => byte == 0);

/// The first [prefixLength] bits of [bytes], with the rest cleared.
Uint8List maskBytes(List<int> bytes, int prefixLength) {
  final masked = Uint8List(bytes.length);
  for (var i = 0; i < bytes.length; i++) {
    final bitsLeft = prefixLength - i * 8;
    if (bitsLeft >= 8) {
      masked[i] = bytes[i];
    } else if (bitsLeft > 0) {
      masked[i] = bytes[i] & (0xff << (8 - bitsLeft)) & 0xff;
    }
  }
  return masked;
}

/// [bytes] as text: dotted IPv4, or IPv6 in the RFC 5952 form (lower-case
/// groups without leading zeros, the longest run of two or more zero groups
/// written as `::`).
String formatIpBytes(List<int> bytes) {
  if (bytes.length == 4) return bytes.join('.');
  final groups = [
    for (var i = 0; i < 16; i += 2) (bytes[i] << 8) | bytes[i + 1],
  ];
  var bestStart = -1;
  var bestLength = 1;
  for (var start = 0; start < 8;) {
    if (groups[start] != 0) {
      start++;
      continue;
    }
    var end = start;
    while (end < 8 && groups[end] == 0) {
      end++;
    }
    if (end - start > bestLength) {
      bestStart = start;
      bestLength = end - start;
    }
    start = end;
  }
  String hex(Iterable<int> part) =>
      part.map((group) => group.toRadixString(16)).join(':');
  if (bestStart < 0) return hex(groups);
  return '${hex(groups.take(bestStart))}::'
      '${hex(groups.skip(bestStart + bestLength))}';
}
