/// Who a connection's client is, without sign-in (D1, D3, D7).
///
/// Pure Dart with no Serverpod dependency: the endpoint turns its session's
/// request into a peer address and raw `X-Forwarded-For` lines and calls
/// [clientKeyFor].
library;

import 'dart:io';

import 'ip_address.dart';
import 'trusted_proxies.dart';

/// How many characters, separators included, [clientKeyFor] reads from the
/// end of the `X-Forwarded-For` lines (C8).
const int forwardedBudget = 2048;

/// How many `X-Forwarded-For` entries, from the right, [clientKeyFor] reads
/// at most (C8).
const int maxForwardedEntries = 20;

/// The key a client's announcement streams are counted under.
///
/// An IPv4 address counts whole and an IPv6 address by its /64 prefix; an
/// IPv4-mapped address counts as its IPv4 address (D3). Every connection
/// whose peer is not known shares [unknown].
final class ClientKey {
  const ClientKey._(this.value);

  /// The key of [address].
  factory ClientKey.forAddress(InternetAddress address) {
    final bytes = normaliseIpAddress(address).rawAddress;
    if (bytes.length == 4) return ClientKey._(formatIpBytes(bytes));
    return ClientKey._('${formatIpBytes(maskBytes(bytes, 64))}/64');
  }

  /// The one key of every connection whose peer address is not known.
  static const ClientKey unknown = ClientKey._('unknown');

  /// The key as text: an IPv4 address, an IPv6 /64 prefix or `unknown`.
  final String value;

  @override
  bool operator ==(Object other) => other is ClientKey && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Why a trusted proxy's `X-Forwarded-For` named no client.
enum ForwardedFallback {
  /// The header is missing, or every line of it is blank.
  missing,

  /// An entry that is not an IP address comes before any untrusted one.
  notAnAddress,

  /// Every entry read is a trusted proxy: the whole header, or the
  /// complete entries within [forwardedBudget] and [maxForwardedEntries].
  noUntrustedEntry,
}

/// Who a connection's client is, and how it was found.
sealed class ClientIdentity {
  const ClientIdentity(this.key);

  /// The key the client's streams count under.
  final ClientKey key;
}

/// A connection whose peer is not a trusted proxy, or is not known: its
/// own address is the client, and any forwarded header is ignored.
final class DirectClient extends ClientIdentity {
  /// The client [key] of a connection that is not a trusted proxy's.
  const DirectClient(super.key);

  @override
  String toString() => 'DirectClient($key)';
}

/// A trusted proxy's connection whose `X-Forwarded-For` names the client.
final class ForwardedClient extends ClientIdentity {
  /// The client at [address], read from a trusted proxy's header.
  ForwardedClient(this.address) : super(ClientKey.forAddress(address));

  /// The client's address, normalised (an IPv4-mapped address as IPv4).
  final InternetAddress address;

  @override
  String toString() => 'ForwardedClient(${address.address})';
}

/// A trusted proxy's connection whose `X-Forwarded-For` gave no usable
/// address: the proxy's own address is the client, and the caller warns,
/// naming [proxy].
final class ProxyFallback extends ClientIdentity {
  /// Counts the stream under [proxy], for [reason].
  ProxyFallback(this.proxy, this.reason) : super(ClientKey.forAddress(proxy));

  /// The trusted proxy's address, normalised.
  final InternetAddress proxy;

  /// Why its header named no client.
  final ForwardedFallback reason;

  @override
  String toString() => 'ProxyFallback(${proxy.address}, ${reason.name})';
}

/// Identifies the client of a connection from [peer], its remote address
/// (`null` when not known), and [forwardedFor], the raw lines of its
/// `X-Forwarded-For` header in arrival order (`null` when it has none).
///
/// A peer that is not in [trusted] is the client, and its header is
/// ignored. A peer that is not known, or is the unspecified address, is
/// never trusted: every such connection is [ClientKey.unknown].
///
/// Behind a trusted proxy the header is read from right to left, because
/// each trusted proxy appends the address it received the connection from:
/// the rightmost untrusted entry is the one a trusted hop wrote, while
/// entries further left were written by the client itself, so reading the
/// leftmost entry, or trusting private ranges, would let a client choose
/// its own key (C1). Trusted entries are skipped, and the first untrusted
/// entry is the client. Only proxies that append their peer's address may
/// be trusted.
///
/// The lines are joined by a virtual comma, and the walk reads only the
/// last [forwardedBudget] characters of them, separators included, and at
/// most the rightmost [maxForwardedEntries] entries, so the work per
/// subscription stays constant however long the header is. An entry counts
/// only when both of its ends lie within that budget: a fragment cut by it
/// is never parsed as an entry (C8). Accepted entries are bare IPv4,
/// `IPv4:port`, bare IPv6, `[IPv6]` and `[IPv6]:port`; a bare IPv6 entry
/// never has a port.
///
/// When the header gives no untrusted address, the proxy's own address is
/// the client, as a [ProxyFallback] with its reason.
ClientIdentity clientKeyFor({
  required InternetAddress? peer,
  required Iterable<String>? forwardedFor,
  required TrustedProxies trusted,
}) {
  if (peer == null || isUnspecified(peer)) {
    return const DirectClient(ClientKey.unknown);
  }
  final proxy = normaliseIpAddress(peer);
  if (!trusted.trusts(proxy)) return DirectClient(ClientKey.forAddress(proxy));

  final lines = switch (forwardedFor) {
    null => const <String>[],
    final List<String> list => list,
    final Iterable<String> other => other.toList(),
  };
  final (:entries, :wholeHeader) = _rightmostEntries(lines);
  final trimmed = [for (final entry in entries) entry.trim()];
  if (wholeHeader && trimmed.every((entry) => entry.isEmpty)) {
    return ProxyFallback(proxy, ForwardedFallback.missing);
  }
  for (final entry in trimmed) {
    final address = _parseEntry(entry);
    if (address == null) {
      return ProxyFallback(proxy, ForwardedFallback.notAnAddress);
    }
    if (!trusted.trusts(address)) return ForwardedClient(address);
  }
  return ProxyFallback(proxy, ForwardedFallback.noUntrustedEntry);
}

/// The complete entries within the budget, rightmost first, at most
/// [maxForwardedEntries] of them, and whether they are the whole header.
({List<String> entries, bool wholeHeader}) _rightmostEntries(
  List<String> lines,
) {
  if (lines.isEmpty) return (entries: const [], wholeHeader: true);
  // Collect the tail of the virtually joined lines, last part first.
  final parts = <String>[];
  var used = 0;
  var reachedStart = false;
  for (var i = lines.length - 1; i >= 0; i--) {
    if (i < lines.length - 1) {
      if (used == forwardedBudget) break;
      parts.add(',');
      used++;
    }
    final line = lines[i];
    final room = forwardedBudget - used;
    if (line.length > room) {
      parts.add(line.substring(line.length - room));
      used = forwardedBudget;
      break;
    }
    parts.add(line);
    used += line.length;
    if (i == 0) reachedStart = true;
  }
  final segments = parts.reversed.join().split(',');
  // Unless the budget reached the start of the first line, the leftmost
  // segment's left end lies outside it, so it may be a cut fragment.
  if (!reachedStart) segments.removeAt(0);
  return (
    entries: segments.reversed.take(maxForwardedEntries).toList(),
    wholeHeader: reachedStart && segments.length <= maxForwardedEntries,
  );
}

final RegExp _port = RegExp(r'^[0-9]{1,5}$');

/// The address of one trimmed `X-Forwarded-For` entry, normalised, or
/// `null` when it is not one of the accepted forms.
InternetAddress? _parseEntry(String entry) {
  bool validPort(String text) =>
      _port.hasMatch(text) && int.parse(text) <= 0xffff;

  final InternetAddress? address;
  if (entry.startsWith('[')) {
    final close = entry.indexOf(']');
    if (close < 0) return null;
    final rest = entry.substring(close + 1);
    if (rest.isNotEmpty &&
        !(rest.startsWith(':') && validPort(rest.substring(1)))) {
      return null;
    }
    final inner = parseIpAddress(entry.substring(1, close));
    if (inner == null || inner.type != InternetAddressType.IPv6) return null;
    address = inner;
  } else if (':'.allMatches(entry).length == 1) {
    final colon = entry.indexOf(':');
    if (!validPort(entry.substring(colon + 1))) return null;
    final host = parseIpAddress(entry.substring(0, colon));
    if (host == null || host.type != InternetAddressType.IPv4) return null;
    address = host;
  } else {
    // A bare IPv4 address, or a bare IPv6 address, whose last group is
    // never read as a port.
    address = parseIpAddress(entry);
  }
  return address == null ? null : normaliseIpAddress(address);
}
