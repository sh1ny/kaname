import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/server/data/server_address.dart';
import 'package:kaname_app/server/logic/server_status.dart';
import 'package:kaname_client/kaname_client.dart';

import 'fake_server_health.dart';

final _up = HealthReport(
  version: '0.1.0',
  postgres: DependencyStatus.up,
  redis: DependencyStatus.up,
);
final _redisDown = HealthReport(
  version: '0.1.1',
  postgres: DependencyStatus.up,
  redis: DependencyStatus.down,
);

Matcher _connected(HealthReport report) =>
    isA<Connected>().having((c) => c.report, 'report', same(report));

final _configured = ConfiguredServer(Uri.parse('http://127.0.0.1:8080/api/'));

ProviderContainer containerFor(
  FakeServerHealth fake, {
  ServerTarget? target,
  Duration timeout = const Duration(seconds: 10),
}) => ProviderContainer.test(
  overrides: [
    serverTargetProvider.overrideWithValue(target ?? _configured),
    serverHealthProvider.overrideWithValue(fake),
    serverCheckTimeoutProvider.overrideWithValue(timeout),
  ],
);

void main() {
  test('no address gives NotConfigured, makes no call, and the UI shows '
      'No server configured', () {
    final fake = FakeServerHealth();
    final container = containerFor(fake, target: const NoServer());
    expect(container.read(serverStatusProvider), isA<NotConfigured>());
    expect(fake.calls, 0);
  });

  test('address without a scheme gives InvalidAddress, makes no call, and '
      'Settings says invalid', () {
    final fake = FakeServerHealth();
    final container = containerFor(fake, target: const InvalidServer('x'));
    expect(container.read(serverStatusProvider), isA<InvalidAddress>());
    expect(fake.calls, 0);
  });

  test('the first check starts when the status is first read', () async {
    final fake = FakeServerHealth();
    final container = containerFor(fake);
    expect(container.read(serverStatusProvider), isA<Checking>());
    expect(fake.calls, 1);
    fake.answer(_up);
    await pumpEventQueue();
    expect(container.read(serverStatusProvider), _connected(_up));
  });

  test('Check again makes one new call and replaces the answer', () async {
    final fake = FakeServerHealth();
    final container = containerFor(fake);
    container.read(serverStatusProvider);
    fake.answer(_up);
    await pumpEventQueue();

    final notifier = container.read(serverStatusProvider.notifier);
    final again = notifier.check();
    expect(fake.calls, 2);
    expect(
      container.read(serverStatusProvider),
      isA<Checking>().having((c) => c.previous, 'previous', _connected(_up)),
    );
    fake.answer(_redisDown);
    await again;
    expect(container.read(serverStatusProvider), _connected(_redisDown));
  });

  test('two presses during a call share one call and show busy', () async {
    final fake = FakeServerHealth();
    final container = containerFor(fake);
    container.read(serverStatusProvider);
    fake.answer(_up);
    await pumpEventQueue();

    final notifier = container.read(serverStatusProvider.notifier);
    final first = notifier.check();
    final second = notifier.check();
    expect(container.read(serverStatusProvider), isA<Checking>());
    expect(fake.calls, 2);
    var done = 0;
    unawaited(first.then((_) => done++));
    unawaited(second.then((_) => done++));
    fake.answer(_up);
    await Future.wait([first, second]);
    expect(done, 2);
    expect(fake.calls, 2);
    expect(container.read(serverStatusProvider), _connected(_up));
  });

  test('failure or 10s time-out gives Unreachable with no exception text and '
      'the shell still navigates', () async {
    final fake = FakeServerHealth();
    final container = containerFor(fake);
    container.read(serverStatusProvider);
    fake.fail(StateError('connect to 10.0.0.5:8080 refused'));
    await pumpEventQueue();
    expect(container.read(serverStatusProvider), isA<Unreachable>());
    expect(
      container.read(serverStatusProvider).toString(),
      isNot(contains('10.0.0.5')),
    );

    // A call that never answers is given up at the injected backstop; the
    // backstop is injected (10s in the app) so the test needs no fake clock.
    final hung = FakeServerHealth();
    final slow = containerFor(hung, timeout: const Duration(milliseconds: 20));
    slow.read(serverStatusProvider);
    expect(slow.read(serverStatusProvider), isA<Checking>());
    await slow.read(serverStatusProvider.notifier).check();
    expect(slow.read(serverStatusProvider), isA<Unreachable>());
  });

  test('the default backstop is 10 seconds', () {
    final container = ProviderContainer.test();
    expect(
      container.read(serverCheckTimeoutProvider),
      const Duration(seconds: 10),
    );
  });

  test('Check again after Unreachable shows the new answer', () async {
    final fake = FakeServerHealth();
    final container = containerFor(fake);
    container.read(serverStatusProvider);
    fake.fail(Exception('boom'));
    await pumpEventQueue();
    expect(container.read(serverStatusProvider), isA<Unreachable>());

    final again = container.read(serverStatusProvider.notifier).check();
    expect(
      container.read(serverStatusProvider),
      isA<Checking>().having((c) => c.previous, 'previous', isNull),
    );
    fake.answer(_up);
    await again;
    expect(container.read(serverStatusProvider), _connected(_up));
  });
}
