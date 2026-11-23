import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import 'l10n/generated/app_localizations.dart';
import 'server/ui/server_indicator.dart';
import 'settings/logic/theme_choice_notifier.dart';
import 'shell/logic/router.dart';
import 'shell/logic/slot_registry.dart';
import 'static_data/logic/server_static_data_status_notifier.dart';

/// The Kaname app: the shell over the registry's destinations.
///
/// Carried constraint C5: `themeAnimationDuration: Duration.zero` stays on the
/// app's `MaterialApp`. Ember switches themes instantly, so a theme change
/// shows on the next frame with no animated blend of surfaces.
///
/// The router is created once, when the state is created, never per build. The
/// theme mode follows [themeChoiceProvider]; the server and theme providers
/// are overridden by `main()` and by tests.
class KanameApp extends ConsumerStatefulWidget {
  /// Creates the app over [registry] (the M0 registry when omitted), starting
  /// at [initialLocation].
  const KanameApp({this.registry, this.initialLocation = '/home', super.key});

  /// The module slots to show; the M0 registry when null.
  final SlotRegistry? registry;

  /// The location the router starts at.
  final String initialLocation;

  @override
  ConsumerState<KanameApp> createState() => _KanameAppState();
}

class _KanameAppState extends ConsumerState<KanameApp> {
  late final GoRouter _router = buildRouter(
    registry: widget.registry ?? SlotRegistry.m0(),
    initialLocation: widget.initialLocation,
    statusBarTrailing: const ServerStatusIndicator(),
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final choice = ref.watch(themeChoiceProvider);
    return StaticDataSettingsVisibilityBinding(
      router: _router,
      child: MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        routerConfig: _router,
        theme: EmberTheme.light(),
        darkTheme: EmberTheme.dark(),
        themeMode: choice.themeMode,
        themeAnimationDuration: Duration.zero,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}
