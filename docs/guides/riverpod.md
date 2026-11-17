# Riverpod in the Kaname app

How the app uses Riverpod, following [ADR 0010](../adr/0010-flutter-app-state.md). The ADR has the decision and the rejected alternatives. This guide covers the day-to-day rules.

Pinned versions (from `pubspec.lock`): `flutter_riverpod` 3.5.0 and `riverpod` 3.5.0, with `go_router` 18.1.4 for routing. A Riverpod major upgrade is its own change, because majors can break.

## Where things live

Each feature is a folder under `app/lib/` (`shell/`, `settings/`, `server/`, and `modules/<module>/` for modules, ADR 0003). Inside it, code splits by layer where the feature has that layer:

| Folder | Holds | Imports Riverpod? |
|---|---|---|
| `ui/` | Widgets. They read providers with `ref.watch` and call notifier methods. | yes (`ConsumerWidget`, `ConsumerStatefulWidget`) |
| `logic/` | Providers and notifiers: the only place a provider is declared. | yes |
| `data/` | Plain Dart: interfaces, their implementations (HTTP client, `shared_preferences`, `package_info_plus`) and value types. | **never** |

**Invariant (C4, restated from ADR 0010):** domain and data code in `app/lib/**/data/` never imports Riverpod; providers live in `logic/` only. Data code takes its dependencies through its constructor, so it can be created in `main()` before `runApp`, used outside the app, and tested without a container.

Examples in the code:
- `server/data/server_address.dart` and `server/data/server_health.dart` are plain Dart. `server/logic/server_status.dart` declares the providers and `ServerStatusNotifier`.
- `settings/data/theme_preference_store.dart` is plain Dart. The settings notifier in `settings/logic/` wraps it.

## What we do not use

- **No code generation:** no `riverpod_annotation`, `riverpod_generator` or `build_runner`. Providers are declared by hand (`Provider`, `NotifierProvider`). Serverpod is the only code generator in the repository.
- **No `persist`:** Riverpod's experimental offline persistence is not used. The theme choice is the only thing the app keeps on the device in M0, through `shared_preferences` with an allow-list. The future local store and sync layer (ADR 0005, ADR 0008) are the only offline cache.

## State: a `Notifier` with a sealed state

Model state that has more than "loading, data, error" as a sealed class, and own it with one `Notifier`. `ServerStatusNotifier` is the reference:

```dart
sealed class ServerStatus { const ServerStatus(); }
final class NotConfigured extends ServerStatus { const NotConfigured(); }
final class InvalidAddress extends ServerStatus { const InvalidAddress(); }
final class Checking extends ServerStatus { const Checking({this.previous}); final Connected? previous; }
final class Connected extends ServerStatus { const Connected(this.report); final HealthReport report; }
final class Unreachable extends ServerStatus { const Unreachable(); }

final serverStatusProvider =
    NotifierProvider<ServerStatusNotifier, ServerStatus>(ServerStatusNotifier.new);
```

Rules:
- The notifier is the **only writer** of its state. Widgets call its methods (`check()`), never set state.
- Widgets **switch exhaustively** over the sealed state, so a new state is a compile error until every widget handles it.
- **Map failures to typed states.** A notifier never rethrows: Riverpod 3 retries a provider that throws, and the UI must not show exception text. `ServerStatusNotifier` turns every failure into `Unreachable`, which has no fields, and logs the cause with `debugPrint` in debug builds only.
- Dependencies come from other providers that `main()` overrides (`serverTargetProvider`, `serverHealthProvider`). Their defaults throw `UnimplementedError`, so a missing override fails loudly. A value with a sensible default, such as `serverCheckTimeoutProvider` (10 seconds), keeps it and tests override it.
- `AsyncValue` is fine at the edge for a simple one-shot read. Prefer a sealed state once there are states such as "not configured" that are neither loading nor error.

## Single-flight

When a user action can start the same async call twice, the notifier keeps the running future and hands it back:

```dart
Future<void>? _inFlight;

Future<void> check() {
  final running = _inFlight;
  if (running != null) return running;
  state = Checking(previous: /* last answer */);
  return _inFlight = _run(); // _run clears _inFlight and sets state when done
}
```

Two presses of "Check again" then share one call, and the button shows the busy state from `Checking`. Before setting state after an `await`, check `ref.mounted`: the provider may have been disposed or rebuilt meanwhile.

## Tests

Test at the cheapest layer that covers the behaviour:
- **`data/`:** plain unit tests with no container.
- **`logic/`:** `ProviderContainer.test(overrides: [...])`. It disposes itself at the end of the test.
- **`ui/`:** widget tests that wrap the widget in `ProviderScope(overrides: [...])`.

Use **hand-written fakes**, not a mocking package. A fake implements the plain-Dart interface from `data/` and lets the test control timing, as `test/server/fake_server_health.dart` does with one completer per call:

```dart
final health = FakeServerHealth();
final container = ProviderContainer.test(
  overrides: [
    serverTargetProvider.overrideWithValue(ConfiguredServer(Uri.parse('http://127.0.0.1:8080/'))),
    serverHealthProvider.overrideWithValue(health),
    serverCheckTimeoutProvider.overrideWithValue(const Duration(milliseconds: 20)),
  ],
);
```

## Adding a module

1. Create `app/lib/modules/<module>/` with `ui/`, `logic/` and `data/` as the module needs them.
2. Register one slot in the registry (`app/lib/shell/logic/slot_registry.dart`): a unique id and route path, a label from `AppLocalizations`, an icon, and the builder of its root screen. The registry refuses duplicates at startup.
3. Put the module's routes under its own branch: the router builds one `StatefulShellBranch` per slot, so the module keeps its state when the user switches away.
4. Put every user-visible string in `app/lib/l10n/app_en.arb` and regenerate (`mise exec -- flutter gen-l10n` in `app/`; `mise run l10n:check` checks it).
5. Server data comes through a plain-Dart interface in `data/` and a notifier in `logic/`, as the server status does.
