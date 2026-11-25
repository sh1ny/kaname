import 'account_types.dart';
import 'desktop_platform_web.dart'
    if (dart.library.io) 'desktop_platform_io.dart'
    as platform;

/// Whether this runtime supports a local credential holder (ADR 0017).
bool get hasDesktopHolder => platform.hasDesktopHolder;

/// Opens the desktop credential runtime, or null if storage is unavailable.
Future<DesktopAccount?> openDesktopHolder() => platform.openDesktopHolder();
