import 'account_types.dart';

/// Web and browser sessions are connected-only.
const hasDesktopHolder = false;

/// No native credential runtime is available on the web.
Future<DesktopAccount?> openDesktopHolder() async => null;
