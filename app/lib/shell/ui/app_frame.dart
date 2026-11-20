import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../logic/breakpoint.dart';
import '../logic/inspector_notifier.dart';
import '../logic/slot_registry.dart';
import 'bottom_bar.dart';
import 'drawer.dart';
import 'inspector_dock.dart';
import 'inspector_sheet.dart';
import 'rail.dart';
import 'shell_main.dart';
import 'sidebar.dart';
import 'slide_panel_host.dart';
import 'status_bar.dart';
import 'top_bar.dart';

/// The adaptive frame every destination plugs into.
///
/// Its regions follow the window's width ([ShellBreakpoint]): a top bar and a
/// status bar always; a rail, a docked sidebar and (wide only) a docked
/// inspector; or, on narrow windows, a bottom bar with the sidebar as a
/// drawer. The inspector is an overlay sheet at every width but wide.
///
/// The main column is one keyed subtree that stays mounted across all of
/// these, so a destination's state survives a breakpoint change or a panel
/// opening (DESIGN.md, the Centre Holds rule). The inspector's open state is
/// owned by [inspectorProvider]; the drawer's is local to this widget.
///
/// Panels animate over 200ms with Ember's panel easing; when the platform asks
/// for reduced motion they complete on the next frame.
class AppFrame extends ConsumerStatefulWidget {
  /// Creates the frame around [navigationShell], the current destination.
  const AppFrame({
    required this.registry,
    required this.navigationShell,
    this.statusBarTrailing,
    super.key,
  });

  /// The registry the rail, bottom bar and destinations come from.
  final SlotRegistry registry;

  /// The router's shell: the current branch and the way to switch branch.
  final StatefulNavigationShell navigationShell;

  /// What the status bar shows at its right end.
  final Widget? statusBarTrailing;

  @override
  ConsumerState<AppFrame> createState() => _AppFrameState();
}

class _AppFrameState extends ConsumerState<AppFrame> {
  final _toggleFocus = FocusNode(debugLabel: 'inspector toggle');
  final _closeFocus = FocusNode(debugLabel: 'inspector close');
  final _mainFocus = FocusNode(debugLabel: 'main column');
  final _mainKey = GlobalKey(debugLabel: 'main column');

  /// Who held focus when the inspector opened, to return focus there.
  FocusNode? _opener;

  /// The opener to record when the open state next flips, set by controls
  /// whose focus request has not been applied yet.
  FocusNode? _pendingOpener;

  bool _drawerOpen = false;
  ShellBreakpoint? _breakpoint;

  @override
  void dispose() {
    _toggleFocus.dispose();
    _closeFocus.dispose();
    _mainFocus.dispose();
    super.dispose();
  }

  void _onInspectorChanged(bool? previous, bool open) {
    if (open == (previous ?? false)) return;
    if (open) {
      _opener = _pendingOpener ?? FocusManager.instance.primaryFocus;
      _pendingOpener = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(inspectorProvider)) _closeFocus.requestFocus();
      });
    } else {
      final opener = _opener;
      _opener = null;
      // The opener can be gone (a breakpoint change removed it): then main.
      if (opener != null && opener.parent != null && opener.canRequestFocus) {
        opener.requestFocus();
      } else {
        _mainFocus.requestFocus();
      }
    }
  }

  void _toggleInspector() {
    if (!ref.read(inspectorProvider)) {
      _pendingOpener = _toggleFocus;
      _toggleFocus.requestFocus();
    }
    ref.read(inspectorProvider.notifier).toggle();
  }

  void _select(int index) {
    final shell = widget.navigationShell;
    setState(() => _drawerOpen = false);
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(inspectorProvider, _onInspectorChanged);
    final inspectorOpen = ref.watch(inspectorProvider);
    final l10n = AppLocalizations.of(context);
    final colors = EmberColors.of(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : EmberMotion.panel;
    final registry = widget.registry;
    final destinations = registry.destinations;
    final current = widget.navigationShell.currentIndex;
    // The hidden not-found branch comes after the destinations: none selected.
    final selected = current < destinations.length ? current : null;
    void closeInspector() => ref.read(inspectorProvider.notifier).close();

    return Scaffold(
      backgroundColor: colors.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final breakpoint = ShellBreakpoint.of(constraints.maxWidth);
          if (breakpoint != _breakpoint) {
            // A drawer open at narrow width closes when the window widens.
            if (breakpoint != ShellBreakpoint.narrow) _drawerOpen = false;
            _breakpoint = breakpoint;
          }
          final narrow = breakpoint == ShellBreakpoint.narrow;
          final sidebar = ShellSidebar(
            title: selected == null
                ? l10n.appTitle
                : destinations[selected].label(l10n),
          );
          // The frame keeps inside the system insets (status bar, cutout,
          // home indicator); the canvas fills the rest of the window.
          return SafeArea(
            child: Column(
              children: [
                ShellTopBar(
                  inlineSearch: breakpoint == ShellBreakpoint.wide,
                  inspectorOpen: inspectorOpen,
                  onInspectorToggle: _toggleInspector,
                  inspectorToggleFocus: _toggleFocus,
                  drawerOpen: _drawerOpen,
                  onDrawerToggle: narrow
                      ? () => setState(() => _drawerOpen = !_drawerOpen)
                      : null,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Row(
                          children: [
                            if (!narrow)
                              ShellRail(
                                registry: registry,
                                selectedIndex: selected,
                                onSelected: _select,
                              ),
                            if (!narrow) sidebar,
                            Expanded(
                              child: ShellMain(
                                key: _mainKey,
                                focusNode: _mainFocus,
                                child: widget.navigationShell,
                              ),
                            ),
                            if (breakpoint == ShellBreakpoint.wide)
                              InspectorDock(
                                open: inspectorOpen,
                                duration: duration,
                                onClose: closeInspector,
                                closeFocus: _closeFocus,
                              ),
                          ],
                        ),
                      ),
                      if (breakpoint.inspectorIsSheet)
                        Positioned.fill(
                          child: SlidePanelHost(
                            open: inspectorOpen,
                            duration: duration,
                            builder: (context, progress) => InspectorSheet(
                              progress: progress,
                              onClose: closeInspector,
                              closeFocus: _closeFocus,
                            ),
                          ),
                        ),
                      if (narrow)
                        Positioned.fill(
                          child: SlidePanelHost(
                            open: _drawerOpen,
                            duration: duration,
                            builder: (context, progress) => ShellDrawer(
                              progress: progress,
                              onClose: () =>
                                  setState(() => _drawerOpen = false),
                              child: sidebar,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (narrow)
                  ShellBottomBar(
                    registry: registry,
                    selectedIndex: selected,
                    onSelected: _select,
                  ),
                ShellStatusBar(trailing: widget.statusBarTrailing),
              ],
            ),
          );
        },
      ),
    );
  }
}
