import 'package:flutter/material.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

/// A centred empty state: a [title] and a [message] beneath it.
class EmptyState extends StatelessWidget {
  /// Creates an empty state.
  const EmptyState({
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  /// What the empty area is, for example a slot's name.
  final String title;

  /// Why it is empty.
  final String message;

  /// An optional control beneath the message, such as a way out.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = EmberColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(EmberSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: EmberType.title.copyWith(color: colors.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: EmberSpace.sm),
            Text(
              message,
              style: EmberType.body.copyWith(color: colors.inkSecondary),
              textAlign: TextAlign.center,
            ),
            if (action case final action?) ...[
              const SizedBox(height: EmberSpace.lg),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
