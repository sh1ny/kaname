import 'dart:async';
import 'dart:io';

import 'package:kaname_server/src/network/client_identity.dart';
import 'package:kaname_server/src/realtime/server_clock.dart';
import 'package:kaname_server/src/static_data/bundle_announcement_runtime.dart';
import 'package:test/test.dart';

void main() {
  late _Clock clock;
  late BundleAnnouncementRuntime runtime;
  final limit = AnnouncementRefusal.clientLimit.label;

  setUp(() {
    clock = _Clock();
    runtime = BundleAnnouncementRuntime()..clock = clock;
  });

  ClientKey client(int n) => ClientKey.forAddress(
    InternetAddress('10.${n >> 16 & 255}.${n >> 8 & 255}.${n & 255}'),
  );

  /// Refuses [key] once and returns the warning, or `null`.
  String? refuse(ClientKey key) => runtime.noteRefusal(key, limit);

  test('500 refusals in a minute log one warning', () {
    final looping = client(1);
    final warnings = [
      for (var i = 0; i < 500; i++)
        ?(() {
          clock.advance(const Duration(milliseconds: 100));
          return refuse(looping);
        })(),
    ];

    expect(warnings, hasLength(1));
    expect(warnings.single, contains('client $looping'));
    expect(warnings.single, contains(limit));
    expect(warnings.single, contains('1 since the last warning'));
  });

  test('the next warning after a minute gives the count since the last', () {
    final looping = client(1);
    expect(refuse(looping), isNotNull);
    for (var i = 0; i < 41; i++) {
      clock.advance(const Duration(seconds: 1));
      expect(refuse(looping), isNull);
    }

    clock.advance(const Duration(seconds: 20));
    final warning = refuse(looping);
    expect(warning, contains('client $looping'));
    expect(warning, contains('42 since the last warning'));
  });

  test('no second warning within the minute', () {
    final looping = client(1);
    expect(refuse(looping), isNotNull);
    clock.advance(const Duration(seconds: 1));
    expect(refuse(looping), isNull);
    clock.advance(const Duration(seconds: 58));
    expect(refuse(looping), isNull);

    // Each reason of the same client is its own pair.
    expect(
      runtime.noteRefusal(looping, AnnouncementRefusal.serverLimit.label),
      isNotNull,
    );
  });

  test('a full map evicts the oldest warning on elapsed time, despite a '
      'wall-clock step back', () {
    for (var i = 0; i < refusalLogPairs; i++) {
      expect(refuse(client(i)), contains('client ${client(i)}'));
    }
    expect(runtime.trackedRefusals, hasLength(refusalLogPairs));

    clock.advance(const Duration(minutes: 1, seconds: 1));
    for (var i = 0; i < 10; i++) {
      final warning = refuse(client(i));
      expect(warning, contains('client ${client(i)}'));
      expect(warning, contains('1 since the last warning'));
    }

    // Setting the wall clock back an hour moves no interval.
    clock.setWallClock(clock.now().subtract(const Duration(hours: 1)));
    final newcomer = client(refusalLogPairs);
    final warning = refuse(newcomer);

    expect(warning, contains('client $newcomer'));
    expect(warning, isNot(contains('other clients')));
    final tracked = runtime.trackedRefusals.toList();
    expect(tracked, hasLength(refusalLogPairs));
    expect(tracked, isNot(contains((client(10), limit))));
    expect(tracked.last, (newcomer, limit));
    for (var i = 0; i < 10; i++) {
      expect(tracked, contains((client(i), limit)));
    }
  });

  test('a warning can name an address other than its key, which still '
      'counts the pair', () {
    final key = ClientKey.forAddress(InternetAddress('2001:db8:1:2::10'));
    final first = runtime.noteRefusal(
      key,
      noUsableForwardedHeader,
      shown: '2001:db8:1:2::10',
    );
    expect(first, contains('client 2001:db8:1:2::10,'));
    expect(first, isNot(contains('/64')));
    // A neighbour in the same /64 shares the pair's cooldown.
    expect(
      runtime.noteRefusal(
        ClientKey.forAddress(InternetAddress('2001:db8:1:2::11')),
        noUsableForwardedHeader,
        shown: '2001:db8:1:2::11',
      ),
      isNull,
    );
  });

  test('5,000 clients log at most 4,096 named warnings and one '
      'other-clients warning', () {
    final warnings = <String>[];
    for (var i = 0; i < 5000; i++) {
      clock.advance(const Duration(milliseconds: 10));
      if (refuse(client(i)) case final warning?) warnings.add(warning);
    }

    final named = warnings.where((w) => w.contains(', client '));
    final others = warnings.where((w) => w.contains('other clients'));
    expect(named.length, lessThanOrEqualTo(refusalLogPairs));
    expect(named, hasLength(refusalLogPairs));
    expect(others, hasLength(1));
    expect(warnings, hasLength(named.length + others.length));
    expect(runtime.trackedRefusals, hasLength(refusalLogPairs));
  });
}

/// A clock whose wall time and monotonic elapsed time a test moves apart.
final class _Clock implements ServerClock {
  DateTime _wall = DateTime.utc(2026, 1, 1);
  Duration _elapsed = const Duration(hours: 5);

  /// Moves both the wall clock and the elapsed time by [duration].
  void advance(Duration duration) {
    _wall = _wall.add(duration);
    _elapsed += duration;
  }

  /// Sets the wall clock only.
  void setWallClock(DateTime time) => _wall = time;

  @override
  DateTime now() => _wall;

  @override
  Duration elapsed() => _elapsed;

  @override
  Timer once(Duration duration, void Function() callback) =>
      throw UnsupportedError('the refusal log arms no timer');

  @override
  Timer periodic(Duration duration, void Function() callback) =>
      throw UnsupportedError('the refusal log arms no timer');
}
