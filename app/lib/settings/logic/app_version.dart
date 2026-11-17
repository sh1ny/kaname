import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app version text shown in About.
///
/// Has no default: `main()` reads it before the first frame and overrides
/// this; tests override it too.
final appVersionProvider = Provider<String>(
  (ref) => throw UnimplementedError('appVersionProvider must be overridden'),
);
