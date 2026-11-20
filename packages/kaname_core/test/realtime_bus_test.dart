import 'package:kaname_core/kaname_core.dart';
import 'package:test/test.dart';

final class _Changed {
  const _Changed(this.build);
  final int build;
}

const _staticData = Topic<_Changed>(
  name: 'static-data',
  version: 1,
  visibility: TopicVisibility.public,
);

const _other = Topic<_Changed>(
  name: 'other',
  version: 1,
  visibility: TopicVisibility.public,
);

const _private = Topic<_Changed>(
  name: 'private',
  version: 1,
  visibility: TopicVisibility.scoped,
);

void main() {
  group('Given an in-memory bus', () {
    late InMemoryRealtimeBus bus;
    setUp(() => bus = InMemoryRealtimeBus());

    test('subscriber receives its topic once as the typed model', () async {
      final received = <_Changed>[];
      final subscription = bus.subscribe(_staticData).listen(received.add);
      addTearDown(subscription.cancel);

      final changed = const _Changed(7);
      await bus.publish(_staticData, changed);
      await bus.publish(_other, const _Changed(8));
      await pumpEventQueue();

      expect(received, hasLength(1));
      expect(received.single, same(changed));
    });
  });

  group('Given a public topic', () {
    test('public topic scope passes every message', () {
      final resolution = resolveDeliveryScope(_staticData);

      final scope = switch (resolution) {
        DeliveryScopeAccepted(:final scope) => scope,
        DeliveryScopeRefused(:final reason) => fail('refused: $reason'),
      };
      for (final build in [-1, 0, 7, 1 << 40]) {
        expect(scope.passes(_Changed(build)), isTrue, reason: '$build');
      }
    });
  });

  group('Given a scoped topic', () {
    test('scoped topic subscription is refused', () {
      final resolution = resolveDeliveryScope(_private);

      expect(
        resolution,
        isA<DeliveryScopeRefused<_Changed>>().having(
          (refused) => refused.reason,
          'reason',
          'topic needs the privacy scope',
        ),
      );
    });
  });
}
