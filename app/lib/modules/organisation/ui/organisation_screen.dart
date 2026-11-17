import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shell/ui/empty_state.dart';

/// The Organisation module's placeholder screen: an empty state naming the slot.
class OrganisationScreen extends StatelessWidget {
  /// Creates the screen.
  const OrganisationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(title: l10n.navOrganisation, message: l10n.emptySlotBody);
  }
}
