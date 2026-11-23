import 'dart:collection';
import 'dart:io';

import 'package:kaname_server/src/network/client_identity.dart';
import 'package:kaname_server/src/network/trusted_proxies.dart';
import 'package:test/test.dart';

void main() {
  InternetAddress ip(String text) => InternetAddress(text);
  ClientKey keyOf(String text) => ClientKey.forAddress(ip(text));

  final proxy = ip('10.0.0.1');
  final trusted = TrustedProxies.parse('10.0.0.0/8');

  ClientIdentity viaProxy(List<String>? lines) =>
      clientKeyFor(peer: proxy, forwardedFor: lines, trusted: trusted);

  void expectForwarded(ClientIdentity identity, String address) {
    switch (identity) {
      case ForwardedClient(address: final read, :final key):
        expect(read, ip(address));
        expect(key, keyOf(address));
      case DirectClient() || ProxyFallback():
        fail('expected the forwarded client $address, got $identity');
    }
  }

  void expectFallback(ClientIdentity identity, ForwardedFallback reason) {
    switch (identity) {
      case ProxyFallback(proxy: final peer, reason: final actual, :final key):
        expect(peer, proxy);
        expect(actual, reason);
        expect(key, keyOf('10.0.0.1'));
      case DirectClient() || ForwardedClient():
        fail('expected a fallback to the proxy ($reason), got $identity');
    }
  }

  test('trusted proxy: rightmost untrusted entry is the client', () {
    final identity = viaProxy(['198.51.100.1, 203.0.113.7']);

    expectForwarded(identity, '203.0.113.7');
    expect(identity.key, isNot(keyOf('198.51.100.1')));
    expect(identity.key, isNot(keyOf('10.0.0.1')));
  });

  test('chain of trusted proxies: walks past every trusted entry', () {
    expectForwarded(viaProxy(['203.0.113.7, 10.0.0.5']), '203.0.113.7');
    expectForwarded(
      viaProxy(['198.51.100.1, 203.0.113.7, 10.0.0.5, 10.9.9.9']),
      '203.0.113.7',
    );
  });

  test('repeated header lines are read in arrival order', () {
    expectForwarded(viaProxy(['198.51.100.1', '203.0.113.7']), '203.0.113.7');
    expectForwarded(viaProxy(['203.0.113.7', '198.51.100.1']), '198.51.100.1');
    expectForwarded(viaProxy(['203.0.113.7', '10.0.0.5']), '203.0.113.7');
  });

  test('ports and brackets are stripped; a bare IPv6 entry keeps every '
      'group', () {
    expectForwarded(viaProxy(['203.0.113.7:4711']), '203.0.113.7');
    expectForwarded(viaProxy(['[2001:db8:1:2::a]:4711']), '2001:db8:1:2::a');
    expectForwarded(viaProxy(['[2001:db8:1:2::a]']), '2001:db8:1:2::a');
    expectForwarded(viaProxy(['2001:db8:1:2::a']), '2001:db8:1:2::a');
    expectForwarded(viaProxy(['2001:db8:1:2::4711']), '2001:db8:1:2::4711');
    expectForwarded(
      viaProxy(['2001:db8:1:2:3:4:5:4711']),
      '2001:db8:1:2:3:4:5:4711',
    );
  });

  test('no usable header falls back to the proxy\'s own address with a '
      'fallback reason', () {
    expectFallback(viaProxy(null), ForwardedFallback.missing);
    expectFallback(viaProxy([]), ForwardedFallback.missing);
    expectFallback(viaProxy(['']), ForwardedFallback.missing);
    expectFallback(viaProxy([' ', '']), ForwardedFallback.missing);
    expectFallback(
      viaProxy(['10.0.0.5, 10.0.0.6']),
      ForwardedFallback.noUntrustedEntry,
    );
    expectFallback(
      viaProxy(['203.0.113.7, caddy, 10.0.0.5']),
      ForwardedFallback.notAnAddress,
    );
    expectFallback(
      viaProxy(['203.0.113.7, unknown']),
      ForwardedFallback.notAnAddress,
    );
    expectFallback(viaProxy(['203.0.113.7,']), ForwardedFallback.notAnAddress);
    expectFallback(
      viaProxy(['203.0.113.7:99999']),
      ForwardedFallback.notAnAddress,
    );
    expectFallback(viaProxy(['fe80::1%eth0']), ForwardedFallback.notAnAddress);
    // An entry that is not an address after an untrusted one is never
    // reached.
    expectForwarded(viaProxy(['caddy, 203.0.113.7']), '203.0.113.7');
  });

  test('a mapped peer matches its IPv4 trust entry', () {
    final identity = clientKeyFor(
      peer: ip('::ffff:172.30.0.10'),
      forwardedFor: ['203.0.113.7'],
      trusted: TrustedProxies.parse('172.30.0.10'),
    );

    expectForwarded(identity, '203.0.113.7');
  });

  test('a /64 neighbour of a trusted IPv6 host is not trusted', () {
    final identity = clientKeyFor(
      peer: ip('2001:db8:1:2::11'),
      forwardedFor: ['203.0.113.7'],
      trusted: TrustedProxies.parse('2001:db8:1:2::10'),
    );

    expect(identity, isA<DirectClient>());
    expect(identity.key, keyOf('2001:db8:1:2::10'));
    expect(identity.key.value, '2001:db8:1:2::/64');
  });

  test('an unknown peer is never trusted and counts as unknown', () {
    final everyone = TrustedProxies.parse('0.0.0.0/0, ::/0');
    for (final peer in <InternetAddress?>[
      null,
      InternetAddress.anyIPv6,
      InternetAddress.anyIPv4,
      InternetAddress('::ffff:0.0.0.0'),
    ]) {
      // An IPv4 range alone must not trust the mapped unspecified address.
      for (final trusted in [everyone, TrustedProxies.parse('0.0.0.0/0')]) {
        final identity = clientKeyFor(
          peer: peer,
          forwardedFor: ['203.0.113.7'],
          trusted: trusted,
        );
        expect(identity, isA<DirectClient>(), reason: 'peer: $peer');
        expect(identity.key, ClientKey.unknown, reason: 'peer: $peer');
      }
    }
    expect(ClientKey.unknown.value, 'unknown');
  });

  test('a fragment cut by the 2 KiB budget is ignored', () {
    // An untrusted entry, then trusted entries padded with spaces so that
    // fewer than 20 complete entries fit in the last 2 KiB, and the cut
    // falls two characters into 198.51.100.123: the fragment 8.51.100.123
    // would itself be a valid untrusted address.
    const untrusted = '198.51.100.123';
    const count = 12;
    final paddingTotal =
        forwardedBudget + 2 - untrusted.length - count * ',10.0.0.5'.length;
    final entries = [
      for (var i = 0; i < count; i++)
        '${' ' * (paddingTotal ~/ count + (i < paddingTotal % count ? 1 : 0))}'
            '10.0.0.5',
    ];
    final header = '$untrusted,${entries.join(',')}';
    expect(header.length, forwardedBudget + 2);
    expect(
      header.substring(header.length - forwardedBudget),
      startsWith('8.51.100.123,'),
    );

    expectFallback(viaProxy([header]), ForwardedFallback.noUntrustedEntry);

    // The same header split over two lines, cut in the same place.
    final split = header.indexOf(',');
    expectFallback(
      viaProxy([header.substring(0, split), header.substring(split + 1)]),
      ForwardedFallback.noUntrustedEntry,
    );

    // A whole untrusted entry inside the budget is read.
    expectForwarded(
      viaProxy(['8.51.100.123,${entries.skip(1).join(',')}']),
      '8.51.100.123',
    );
  });

  test('an oversized header is read only within 2 KiB and 20 entries', () {
    final huge = List.filled(100000, '10.0.0.5').join(',');
    expectFallback(
      viaProxy(['203.0.113.7,$huge']),
      ForwardedFallback.noUntrustedEntry,
    );
    expectFallback(
      viaProxy(['203.0.113.7', ...List.filled(100000, '')]),
      ForwardedFallback.notAnAddress,
    );
  });

  test('an untrusted 21st entry from the right is never read', () {
    final trustedHops = List.filled(maxForwardedEntries, '10.0.0.5');
    expectFallback(
      viaProxy(['203.0.113.7, ${trustedHops.join(', ')}']),
      ForwardedFallback.noUntrustedEntry,
    );
    expectForwarded(
      viaProxy(['203.0.113.7, ${trustedHops.skip(1).join(', ')}']),
      '203.0.113.7',
    );
  });

  test('the rightmost entry ends at the end of the header', () {
    expectForwarded(viaProxy(['10.0.0.9, 203.0.113.7']), '203.0.113.7');
    expectForwarded(
      clientKeyFor(
        peer: proxy,
        forwardedFor: ['10.0.0.9, 203.0.113.7'],
        trusted: TrustedProxies.parse('10.0.0.1'),
      ),
      '203.0.113.7',
    );
  });

  group('the walk reads only within its bounds (C8)', () {
    test('no code unit left of the last 2 KiB is read, and no entry is '
        'copied before it is known to fit', () {
      // Fifteen 200-unit entries: ten and their commas fit in 2 KiB, and
      // the budget ends inside the eleventh.
      final tail = List.filled(15, 'y' * 200).join(',');
      final line = _ReadLog('${'x' * 10000},$tail');
      final visited = <String>[];
      final whole = walkForwardedEntries(1, (_) => line, (entry) {
        visited.add(entry);
        return false;
      });
      expect(whole, isFalse);
      expect(visited, List.filled(10, 'y' * 200));
      expect(line.lowestRead, line.length - forwardedBudget);
      for (final (start, end) in line.copies) {
        expect(line.length - start, lessThanOrEqualTo(forwardedBudget));
        expect(end - start, lessThan(forwardedBudget));
      }
    });

    test('an entry longer than the budget is never copied', () {
      final line = _ReadLog('x' * 10000);
      final whole = walkForwardedEntries(1, (_) => line, (_) => false);
      expect(whole, isFalse);
      expect(line.copies, isEmpty);
      expect(line.lowestRead, line.length - forwardedBudget);
    });

    test('clientKeyFor asks for no line the walk does not reach', () {
      // 100,000 lines; the rightmost names an untrusted client.
      final lines = _LineLog([
        ...List.filled(99999, '10.0.0.5'),
        '203.0.113.7',
      ]);
      final identity = clientKeyFor(
        peer: InternetAddress('10.0.0.5'),
        forwardedFor: lines,
        trusted: TrustedProxies.parse('10.0.0.5'),
      );
      expect(
        identity,
        isA<ForwardedClient>().having(
          (client) => client.address.address,
          'address',
          '203.0.113.7',
        ),
      );
      expect(lines.read, [99999]);
    });

    test('nothing of a 21st entry is read', () {
      final entries = [for (var i = 1; i <= 30; i++) '10.0.0.$i'];
      final line = _ReadLog(entries.join(','));
      walkForwardedEntries(1, (_) => line, (_) => false);
      // The 20th entry from the right and the comma left of it.
      final twentieth = entries.reversed.take(20).join(',').length;
      expect(line.copies, hasLength(maxForwardedEntries));
      expect(line.lowestRead, line.length - twentieth - 1);
    });
  });

  test('the walk stops at the first untrusted entry and never reads the '
      'entries to its left', () {
    // Left of the client: more than 2 KiB of entries, none an address.
    final junk = List.filled(500, 'caddy').join(',');
    expectForwarded(viaProxy(['$junk, 203.0.113.7']), '203.0.113.7');
    expectForwarded(viaProxy([junk, '203.0.113.7, 10.0.0.5']), '203.0.113.7');
  });

  test('IPv6 clients in one /64 share a key', () {
    final a = clientKeyFor(
      peer: ip('2001:db8:1:2::a'),
      forwardedFor: null,
      trusted: TrustedProxies.none,
    );
    final b = clientKeyFor(
      peer: ip('2001:db8:1:2::b'),
      forwardedFor: null,
      trusted: TrustedProxies.none,
    );
    final other = clientKeyFor(
      peer: ip('2001:db8:1:3::a'),
      forwardedFor: null,
      trusted: TrustedProxies.none,
    );

    expect(a.key, b.key);
    expect(a.key.hashCode, b.key.hashCode);
    expect(a.key.value, '2001:db8:1:2::/64');
    expect(other.key, isNot(a.key));
    expect(keyOf('2001:db8::1').value, '2001:db8::/64');
  });

  test('a mapped client counts as its IPv4 address', () {
    final mapped = clientKeyFor(
      peer: ip('::ffff:203.0.113.7'),
      forwardedFor: null,
      trusted: TrustedProxies.none,
    );
    final plain = clientKeyFor(
      peer: ip('203.0.113.7'),
      forwardedFor: null,
      trusted: TrustedProxies.none,
    );

    expect(mapped, isA<DirectClient>());
    expect(mapped.key, plain.key);
    expect(mapped.key.value, '203.0.113.7');
    expectForwarded(viaProxy(['::ffff:203.0.113.7']), '203.0.113.7');
  });

  test('an untrusted peer\'s forwarded header is ignored', () {
    final identity = clientKeyFor(
      peer: ip('203.0.113.7'),
      forwardedFor: ['198.51.100.1'],
      trusted: trusted,
    );

    expect(identity, isA<DirectClient>());
    expect(identity.key, keyOf('203.0.113.7'));
  });
}

/// A [ForwardedLine] that records what the walk reads of it.
final class _ReadLog implements ForwardedLine {
  _ReadLog(this._text);

  final String _text;

  /// The lowest index read through [codeUnitAt], or [length] if none.
  late int lowestRead = _text.length;

  /// The ranges copied through [substring], in order.
  final List<(int, int)> copies = [];

  @override
  int get length => _text.length;

  @override
  int codeUnitAt(int index) {
    if (index < lowestRead) lowestRead = index;
    return _text.codeUnitAt(index);
  }

  @override
  String substring(int start, int end) {
    copies.add((start, end));
    return _text.substring(start, end);
  }
}

/// A list of header lines that records which of them were read.
final class _LineLog extends ListBase<String> {
  _LineLog(this._lines);

  final List<String> _lines;

  /// The indexes read, in order.
  final List<int> read = [];

  @override
  int get length => _lines.length;

  @override
  set length(int _) => throw UnsupportedError('read-only');

  @override
  String operator [](int index) {
    read.add(index);
    return _lines[index];
  }

  @override
  void operator []=(int index, String value) =>
      throw UnsupportedError('read-only');
}
