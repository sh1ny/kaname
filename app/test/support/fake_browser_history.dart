import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaname_app/shell/data/browser_history.dart';

/// A browser's session history for widget tests.
///
/// It records the entries the router reports on the navigation channel (a
/// push adds an entry and drops those ahead of it, a replace rewrites the
/// current one) and steps back as a browser does: it moves to the previous
/// entry and tells the app through `pushRouteInformation`, the message
/// Flutter web sends on the browser's Back.
final class FakeBrowserHistory implements BrowserHistory {
  /// Creates the history and starts recording on [tester]'s navigation
  /// channel, until the test ends.
  FakeBrowserHistory(this._tester) {
    final messenger = _tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.navigation, _record);
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.navigation, null),
    );
  }

  final WidgetTester _tester;
  final List<({String uri, Object? state})> _entries = [];
  int _index = -1;

  /// How many times the app stepped back through [back].
  int backCalls = 0;

  /// The entries, oldest first.
  List<String> get entries => [for (final entry in _entries) entry.uri];

  /// The current entry.
  String get current => _entries[_index].uri;

  Future<Object?> _record(MethodCall call) async {
    if (call.method != 'routeInformationUpdated') return null;
    final arguments = call.arguments as Map<Object?, Object?>;
    final entry = (uri: arguments['uri']! as String, state: arguments['state']);
    if (arguments['replace'] == true && _index >= 0) {
      _entries[_index] = entry;
    } else {
      _entries
        ..removeRange(_index + 1, _entries.length)
        ..add(entry);
      _index++;
    }
    return null;
  }

  @override
  void back() {
    backCalls++;
    // The browser answers after the current event, as a popstate does.
    Future<void>(pressBack);
  }

  /// The browser's Back button.
  Future<void> pressBack() async {
    _index--;
    final entry = _entries[_index];
    await _tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.navigation.name,
      SystemChannels.navigation.codec.encodeMethodCall(
        MethodCall('pushRouteInformation', {
          'location': entry.uri,
          'state': entry.state,
        }),
      ),
      (_) {},
    );
  }
}
