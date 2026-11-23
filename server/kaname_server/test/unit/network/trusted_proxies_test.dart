import 'dart:io';

import 'package:kaname_server/src/network/trusted_proxies.dart';
import 'package:test/test.dart';

void main() {
  InternetAddress ip(String text) => InternetAddress(text);

  test('unset or empty setting trusts nobody', () {
    for (final setting in [null, '', '   ']) {
      final trusted = TrustedProxies.parse(setting);
      expect(trusted.isEmpty, isTrue, reason: 'setting: $setting');
      expect(trusted.trusts(ip('127.0.0.1')), isFalse);
      expect(trusted.trusts(ip('172.30.0.10')), isFalse);
      expect(trusted.trusts(ip('::1')), isFalse);
    }
    expect(readTrustedProxies(const {}).isEmpty, isTrue);
  });

  test('addresses and ranges with spaces parse', () {
    final trusted = TrustedProxies.parse('172.30.0.0/24, 10.0.0.5');

    expect(trusted.isEmpty, isFalse);
    expect(trusted.trusts(ip('172.30.0.0')), isTrue);
    expect(trusted.trusts(ip('172.30.0.7')), isTrue);
    expect(trusted.trusts(ip('172.30.0.255')), isTrue);
    expect(trusted.trusts(ip('172.30.1.1')), isFalse);
    expect(trusted.trusts(ip('10.0.0.5')), isTrue);
    expect(trusted.trusts(ip('10.0.0.6')), isFalse);
    expect(
      trusted.trusts(ip('::ffff:172.30.0.7')),
      isTrue,
      reason: 'a mapped address matches as IPv4',
    );

    final v6 = TrustedProxies.parse(' 2001:db8:1:2::10 ,2001:db8:9::/48 ');
    expect(v6.trusts(ip('2001:db8:1:2::10')), isTrue);
    expect(
      v6.trusts(ip('2001:db8:1:2::11')),
      isFalse,
      reason: 'trust matches the whole address, never its /64',
    );
    expect(v6.trusts(ip('2001:db8:9:ffff::1')), isTrue);
    expect(v6.trusts(ip('2001:db8:a::1')), isFalse);
  });

  test('the parser names the first invalid entry', () {
    Matcher namesEntry(String entry) => throwsA(
      isA<TrustedProxiesError>()
          .having((error) => error.entry, 'entry', entry)
          .having((error) => error.toString(), 'message', contains(entry))
          .having(
            (error) => error.toString(),
            'message',
            contains(trustedProxiesVariable),
          ),
    );

    expect(
      () => TrustedProxies.parse('172.30.0.0/33,caddy'),
      namesEntry('172.30.0.0/33'),
    );
    expect(() => TrustedProxies.parse('10.0.0.5, caddy'), namesEntry('caddy'));
    expect(() => TrustedProxies.parse('10.0.0.5/x'), namesEntry('10.0.0.5/x'));
    expect(() => TrustedProxies.parse('::1/129'), namesEntry('::1/129'));
    expect(() => TrustedProxies.parse('10.0.0.5,'), namesEntry(''));

    // The start-up check reads the process environment through the same
    // parser, so `serve()` stops before the pod starts (D2).
    expect(
      () => readTrustedProxies({trustedProxiesVariable: '172.30.0.0/33,caddy'}),
      namesEntry('172.30.0.0/33'),
    );
  });

  test('a mapped IPv6-form range is refused with a write-as-IPv4 hint', () {
    expect(
      () => TrustedProxies.parse('::ffff:172.30.0.0/120'),
      throwsA(
        isA<TrustedProxiesError>()
            .having((error) => error.entry, 'entry', '::ffff:172.30.0.0/120')
            .having(
              (error) => error.toString(),
              'message',
              allOf(contains('::ffff:172.30.0.0/120'), contains('as IPv4')),
            ),
      ),
    );
  });
}
