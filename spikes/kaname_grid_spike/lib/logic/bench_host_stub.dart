/// The benchmark host for builds without a browser.
library;

import 'bench_host.dart';

/// Returns the host for this build: an [InertBenchHost].
BenchHost createBenchHost() => const InertBenchHost();
