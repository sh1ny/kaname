import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_grid_spike/logic/bench_script.dart';
import 'package:kaname_grid_spike/logic/benchmark_notifier.dart';

import 'bench_fakes.dart';

void main() {
  test('result JSON v1 and abort publication', () async {
    final rig = await benchRig();
    rig.notifier.run(config: BenchConfig.smoke);

    // Calibration frames 16.7 ms apart give the refresh period.
    rig.finishScroll(frameCount: 11, intervalMs: 16.7);
    expect(rig.step, BenchStep.handSpeed);

    // Hand-speed frames: 95 on time and 5 late by one refresh, with work
    // timings of 4 ms build and 6 ms raster each.
    rig.frames(1);
    for (var i = 0; i < 95; i++) {
      rig.frames(1);
      rig.notifier.recordWork(buildMs: 4, rasterMs: 6);
    }
    for (var i = 0; i < 5; i++) {
      rig.frames(1, intervalMs: 33.0);
      rig.notifier.recordWork(buildMs: 4, rasterMs: 6);
    }
    rig.notifier.stepDone(BenchStep.handSpeed);
    while (rig.step!.isScroll) {
      rig.finishScroll();
    }

    // Operations: each takes 40 ms to the next frame; the filter's raster
    // time arrives afterwards.
    await rig.playAll(
      afterOp: (step) {
        if (step == BenchStep.filter) {
          rig.notifier.recordWork(buildMs: 1, rasterMs: 7);
        }
      },
    );
    final done = rig.state as Done;
    expect(rig.host.published, hasLength(1));
    final json = rig.host.published.single;
    expect(json, done.result.toJson());
    expect(jsonDecode(jsonEncode(json)), json, reason: 'plain JSON');

    expect(json['schemaVersion'], 1);
    expect(json['refreshPeriodMs'], closeTo(16.7, 1e-9));
    expect(json['seedMs'], 3.0);
    expect(json['droppedSamples'], 0);
    expect(json['environment'], fakeEnvironment.toJson());
    expect(json['config'], BenchConfig.smoke.toJson());

    final segments = json['segments'] as Map<String, Object?>;
    expect(segments.keys, [
      'handSpeed',
      'stressDown',
      'stressUp',
      'horizontalOut',
      'horizontalBack',
    ]);
    final hand = segments['handSpeed'] as Map<String, Object?>;
    expect(hand['judged'], isTrue);
    expect(hand['intervals'], 100);
    expect(hand['missedFrames'], 5);
    expect(hand['missedRatio'], closeTo(5 / 105, 1e-12));
    expect(hand['p50Ms'], closeTo(16.7, 1e-9));
    expect(hand['p99Ms'], closeTo(33.0, 1e-9));
    expect(hand['maxMs'], closeTo(33.0, 1e-9));
    expect(hand['work'], {'samples': 100, 'p90Ms': 10.0});
    expect((segments['stressDown'] as Map<String, Object?>)['judged'], isFalse);

    final operations = json['operations'] as List<Object?>;
    expect(
      [for (final op in operations) (op as Map)['step']],
      [
        for (final step in BenchStep.values)
          if (!step.isScroll) step.name,
      ],
    );
    final filter = operations.first as Map<String, Object?>;
    expect(filter['untilFrameMs'], 40.0);
    expect(filter['rasterMs'], 7.0);
    expect(filter['untilOnScreenMs'], 47.0);
    expect(filter['engineMs'], isA<double>());
    final category = operations[1] as Map<String, Object?>;
    expect(category['rasterMs'], isNull, reason: 'no frame timing reported');
    expect(category['untilOnScreenMs'], 40.0);
    final resize = operations.last as Map<String, Object?>;
    expect(resize['engineMs'], isNull, reason: 'a resize runs no query');

    expect(json['verdict'], {
      'missedOk': true,
      'p99Ok': true,
      'workOk': true,
      'operationsOk': true,
      'passed': true,
    });

    // Aborted publishes the abort document, so the runner fails fast.
    rig.notifier.run();
    rig.notifier.cancel();
    expect(rig.host.published.last, {
      'schemaVersion': 1,
      'aborted': 'cancelled',
    });
    rig.notifier.run();
    rig.clock.advance(const Duration(seconds: 14));
    expect(rig.host.published.last, {
      'schemaVersion': 1,
      'aborted': 'timeout:calibrate',
    });

    // Samples past the buffer are counted and dropped, and the result says so.
    final small = await benchRig(
      overrides: [benchSampleCapacityProvider.overrideWithValue(3)],
    );
    small.notifier.run(config: BenchConfig.smoke);
    small.finishScroll(frameCount: 3); // 2 intervals
    small.finishScroll(frameCount: 5); // 4 intervals, 1 fits
    await small.playAll(frameCount: 1);
    final dropped = small.host.published.single['droppedSamples'];
    expect(dropped, 3);
  });
}
