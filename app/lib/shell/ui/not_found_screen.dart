import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import 'empty_state.dart';

/// The not-found state, shown inside the frame, with a way back to Home.
///
/// It names no internal detail: not the location, not an error.
class NotFoundScreen extends StatelessWidget {
  /// Creates the screen.
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      title: l10n.notFoundTitle,
      message: l10n.notFoundBody,
      action: TextButton(
        onPressed: () => context.go('/home'),
        child: Text(l10n.notFoundHome),
      ),
    );
  }
}
