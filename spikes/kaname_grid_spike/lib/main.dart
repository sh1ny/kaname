/// The web grid spike: a 25-column grid over 200,000 seeded rows, used to
/// measure scrolling, filtering, grouping and sorting on Flutter web.
///
/// The spike is not product code. Nothing in `app/`, `app_packages/`,
/// `packages/` or `server/` may import `kaname_grid_spike`, and the first real
/// grid change reuses or replaces it and then deletes
/// `spikes/kaname_grid_spike`.
///
/// CI runs only the spike's VM tests. Web-only breakage shows up only in
/// `mise run build:spike` or `mise run bench:spike`, so a rerun or the first
/// real grid change must run them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import 'data/grid_source.dart';
import 'logic/bench_host_create.dart';
import 'logic/benchmark_notifier.dart';
import 'logic/grid_notifier.dart';
import 'ui/grid_screen.dart';

/// Starts the spike.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EmberFonts.registerLicences();
  runApp(
    ProviderScope(
      overrides: [
        gridSeederProvider.overrideWithValue(const GeneratedSeeder()),
        gridEngineProvider.overrideWithValue(const ColumnEngine()),
        benchHostProvider.overrideWithValue(createBenchHost()),
      ],
      child: const GridSpikeApp(),
    ),
  );
}

/// The spike's root widget, themed with Ember dark.
class GridSpikeApp extends StatelessWidget {
  /// Creates the root widget.
  const GridSpikeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Kaname grid spike',
    debugShowCheckedModeBanner: false,
    theme: EmberTheme.dark(),
    home: const GridScreen(),
  );
}
