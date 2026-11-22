import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/app_frame.dart';
import '../ui/not_found_screen.dart';
import 'slot_registry.dart';

/// The path of the hidden not-found branch.
const String notFoundPath = '/not-found';

/// The sub-path of the licences page under Settings.
const String licencesSubPath = 'licences';

NoTransitionPage<void> _page(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(key: state.pageKey, child: child);

/// Builds the app's router: the shell, one branch per [registry] destination,
/// and a hidden not-found branch.
///
/// The routes are one `StatefulShellRoute.indexedStack` whose branch `i` is
/// the registry's destination `i` (the Settings branch also owns
/// `/settings/licences`), followed by a branch for [notFoundPath] that the
/// registry does not list, so the rail and the bottom bar select nothing
/// there. `/` redirects to the first destination (`/home`) and any location
/// no route matches redirects to [notFoundPath], which renders inside the
/// frame; there is no `errorBuilder`. Destination pages use no transition:
/// only panels move (DESIGN.md, the One Motion Rule).
///
/// C10: the shell stays a `StatefulShellRoute`, never a plain `ShellRoute`,
/// so each destination keeps its state when the user switches away and back
/// (DESIGN.md, the Centre Holds rule). A plain `ShellRoute` was rejected
/// because it rebuilds the destination on every switch.
///
/// C11: branches build lazily; no branch sets `preload`, so the cost grows
/// only with the destinations the user visits, not with the registry's size.
///
/// [statusBarTrailing] fills the status bar's trailing slot.
GoRouter buildRouter({
  required SlotRegistry registry,
  String initialLocation = '/home',
  Widget? statusBarTrailing,
}) {
  final destinations = registry.destinations;
  return GoRouter(
    initialLocation: initialLocation,
    redirect: (context, state) {
      if (state.uri.path == '/') return destinations.first.path;
      if (state.error != null) return notFoundPath;
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppFrame(
          registry: registry,
          navigationShell: navigationShell,
          statusBarTrailing: statusBarTrailing,
        ),
        branches: [
          for (final slot in destinations)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: slot.path,
                  pageBuilder: (context, state) =>
                      _page(state, Builder(builder: slot.builder)),
                  routes: [
                    if (identical(slot, registry.settings))
                      GoRoute(
                        path: licencesSubPath,
                        pageBuilder: (context, state) =>
                            _page(state, const LicensePage()),
                      ),
                  ],
                ),
              ],
            ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: notFoundPath,
                pageBuilder: (context, state) =>
                    _page(state, const NotFoundScreen()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// The query parameter that marks a location where the narrow quick search
/// is open (design D22). It gives the open search its own browser history
/// entry, so the browser's Back closes it before it leaves the page.
const String searchMarker = 'search';

/// Whether [location] carries the [searchMarker].
bool hasSearchMarker(Uri location) =>
    location.queryParameters.containsKey(searchMarker);

/// [location] with the [searchMarker] added; its path, other query
/// parameters and fragment are kept.
String withSearchMarker(Uri location) => Uri(
  path: location.path,
  queryParameters: {...location.queryParametersAll, searchMarker: ''},
  fragment: location.hasFragment ? location.fragment : null,
).toString();

/// [location] without the [searchMarker]; its path, other query parameters
/// and fragment are kept.
String withoutSearchMarker(Uri location) {
  final rest = {...location.queryParametersAll}..remove(searchMarker);
  return Uri(
    path: location.path,
    queryParameters: rest.isEmpty ? null : rest,
    fragment: location.hasFragment ? location.fragment : null,
  ).toString();
}
