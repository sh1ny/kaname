/// The benchmark host for web builds: the page URL in, `window` out.
///
/// Uses `dart:js_interop` and `dart:js_interop_unsafe` only; the spike takes no
/// `package:web` dependency.
///
/// **Renderer probe (A6).** `dart:ui_web` has no public way to ask which
/// renderer is active (`skwasmIsMultiThreaded` and the renderer type are
/// engine-internal). So the host records the renderer the page requested with
/// `?renderer=` and probes `window.flutterCanvasKit`, which the CanvasKit
/// renderer defines and skwasm does not: CanvasKit when it exists, skwasm when
/// it does not and the app is compiled to WebAssembly (`kIsWasm`), `unknown`
/// otherwise. Group 8 confirms the probe against the real builds.
///
/// **Thread mode.** Multi-threaded skwasm needs `crossOriginIsolated`, so a
/// skwasm run reports `multi` when the page is cross-origin isolated and
/// `?threads=single` is absent, and `single` otherwise. CanvasKit reports
/// `n/a`.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart' show kIsWasm;

import 'bench_host.dart';

/// Returns the host for this build: a [WebBenchHost] over [Uri.base].
BenchHost createBenchHost() => WebBenchHost(Uri.base);

/// The browser host.
final class WebBenchHost implements BenchHost {
  /// Creates a host that reads its settings from the query of [url].
  ///
  /// `?bench=1` autostarts the full script, `?bench=smoke` the scaled-down
  /// one, `?renderer=` names the requested renderer and `?threads=single`
  /// forces the single-threaded report.
  WebBenchHost(Uri url) : _query = url.queryParameters;

  final Map<String, String> _query;

  @override
  bool get available => true;

  @override
  BenchLaunch get launch => switch (_query['bench']) {
    '1' => const BenchLaunch(autostart: true),
    'smoke' => const BenchLaunch(autostart: true, smoke: true),
    _ => BenchLaunch.none,
  };

  @override
  BenchEnvironment readEnvironment() {
    final canvasKit = globalContext.has('flutterCanvasKit');
    final renderer = canvasKit ? 'CanvasKit' : (kIsWasm ? 'skwasm' : 'unknown');
    final isolated = globalContext['crossOriginIsolated'].dartify() == true;
    final threadMode = switch (renderer) {
      'CanvasKit' => 'n/a',
      'skwasm' =>
        isolated && _query['threads'] != 'single' ? 'multi' : 'single',
      _ => 'unknown',
    };
    return BenchEnvironment(
      renderer: renderer,
      requestedRenderer: _query['renderer'],
      threadMode: threadMode,
      wasm: kIsWasm,
      userAgent: _navigatorUserAgent(),
      windowWidth: _number('innerWidth'),
      windowHeight: _number('innerHeight'),
      devicePixelRatio: _number('devicePixelRatio', fallback: 1),
    );
  }

  @override
  void publish(Map<String, Object?> document) {
    globalContext['gridBenchResult'] = document.jsify();
  }

  static String _navigatorUserAgent() {
    final navigator = globalContext['navigator'];
    if (navigator.isA<JSObject>()) {
      final agent = (navigator as JSObject)['userAgent'].dartify();
      if (agent is String) return agent;
    }
    return 'unknown';
  }

  static double _number(String property, {double fallback = 0}) {
    final value = globalContext[property].dartify();
    return value is num ? value.toDouble() : fallback;
  }
}
