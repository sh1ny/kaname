import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shell/ui/empty_state.dart';

/// The Home module's placeholder screen: an empty state naming the slot.
class HomeScreen extends StatelessWidget {
  /// Creates the screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(title: l10n.navHome, message: l10n.emptySlotBody);
  }
}
