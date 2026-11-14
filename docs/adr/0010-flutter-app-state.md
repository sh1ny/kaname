# 0010. Flutter app state: Riverpod in the presentation layer

- Status: accepted (2026-11-14)
- Date: 2026-11-14
- Supersedes: none
- Chosen by: user (2026-11-14, after discussing the trade-offs)

## Context
The app has many screens over async server data that is cached, refreshed and invalidated live (ADR 0008). Project rules require constructor-injected dependencies, sealed domain states with exhaustive switches, domain logic independent of widgets, and hand-written fakes with no mocking package.

## Decision
- **flutter_riverpod 3**, confined to the app's presentation layer:
  - providers construct and expose repositories and services, and hold view state;
  - `AsyncValue` (sealed) at the edge;
  - tests use `ProviderContainer.test` with overrides and hand-written fakes.
- **No code generation** (no `riverpod_generator` or `build_runner`) and **no experimental `persist`**: the local store and sync layer (ADR 0005, ADR 0008) are the only offline cache.
- Domain, repositories and services are plain Dart with constructor injection and never import Riverpod. The server and solo engine never depend on it.
- Routing uses go_router.
- The `app-shell` change writes a short project-owned guide for these rules.
- This ADR takes precedence over the state-management and DI steps of the installed `flutter-apply-architecture-best-practices` skill (ChangeNotifier ViewModels, `freezed`). That skill's layering (UI, logic, data) still applies.

## Consequences
- Loading, error, refresh, dispose and invalidation glue comes from one library instead of being hand-written per screen.
- Riverpod majors can be breaking, so upgrades are deliberate changes.
- **Rejected:**
  - ChangeNotifier ViewModels (fewest dependencies, but hand-written async and cache glue on every screen);
  - Riverpod with code generation (a second generator next to Serverpod's);
  - Bloc (more ceremony per screen).
- **Reversal cost:** high once many screens exist. Domain and data layers stay portable because they do not import Riverpod.
