/// The web seam of the benchmark: everything that touches the browser.
///
/// `logic/` and the widgets see only [BenchHost]. `main()` overrides
/// `benchHostProvider` with the implementation the conditional import in
/// `bench_host_create.dart` picks: the web one on web builds, an inert one
/// elsewhere. VM tests use a fake. Nothing here imports Riverpod.
library;

/// How the page asked the benchmark to start.
final class BenchLaunch {
  /// Creates a launch request.
  const BenchLaunch({this.autostart = false, this.smoke = false});

  /// No autostart: the user starts the benchmark with the toolbar.
  static const BenchLaunch none = BenchLaunch();

  /// Whether the benchmark starts by itself once the grid is ready.
  final bool autostart;

  /// Whether the run uses the scaled-down script instead of the full one.
  final bool smoke;
}

/// What the benchmark records about where it ran.
final class BenchEnvironment {
  /// Creates the environment record.
  const BenchEnvironment({
    required this.renderer,
    required this.requestedRenderer,
    required this.threadMode,
    required this.wasm,
    required this.userAgent,
    required this.windowWidth,
    required this.windowHeight,
    required this.devicePixelRatio,
  });

  /// The environment of a host that cannot tell, for example the VM.
  static const BenchEnvironment unknown = BenchEnvironment(
    renderer: 'unknown',
    requestedRenderer: null,
    threadMode: 'unknown',
    wasm: false,
    userAgent: 'unknown',
    windowWidth: 0,
    windowHeight: 0,
    devicePixelRatio: 1,
  );

  /// The renderer the app is believed to run on: `CanvasKit`, `skwasm`, or
  /// `unknown`. See the web host for how it is probed.
  final String renderer;

  /// The renderer the page asked for with `?renderer=`, or `null`.
  final String? requestedRenderer;

  /// `multi` or `single` for skwasm, `n/a` for CanvasKit, or `unknown`.
  final String threadMode;

  /// Whether the app is compiled to WebAssembly.
  final bool wasm;

  /// The browser's user agent string.
  final String userAgent;

  /// The window's inner width in logical pixels.
  final double windowWidth;

  /// The window's inner height in logical pixels.
  final double windowHeight;

  /// The device pixel ratio.
  final double devicePixelRatio;

  /// The record as JSON.
  Map<String, Object?> toJson() => {
    'renderer': renderer,
    'requestedRenderer': requestedRenderer,
    'threadMode': threadMode,
    'wasm': wasm,
    'userAgent': userAgent,
    'window': {'width': windowWidth, 'height': windowHeight},
    'devicePixelRatio': devicePixelRatio,
  };
}

/// Everything the benchmark needs from the browser.
abstract interface class BenchHost {
  /// Whether this host can run and report a benchmark. The Benchmark button
  /// stays disabled when it cannot.
  bool get available;

  /// How the page asked the benchmark to start.
  BenchLaunch get launch;

  /// Reads the environment now; the window size can change between runs.
  BenchEnvironment readEnvironment();

  /// Publishes a result document where the runner polls for it: the web host
  /// sets `window.gridBenchResult`. Each call replaces the previous document.
  void publish(Map<String, Object?> document);
}

/// A host that cannot benchmark: the default on the VM.
final class InertBenchHost implements BenchHost {
  /// Creates the inert host.
  const InertBenchHost();

  @override
  bool get available => false;

  @override
  BenchLaunch get launch => BenchLaunch.none;

  @override
  BenchEnvironment readEnvironment() => BenchEnvironment.unknown;

  @override
  void publish(Map<String, Object?> document) {}
}
