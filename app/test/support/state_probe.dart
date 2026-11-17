import 'package:flutter/material.dart';
import 'package:kaname_app/shell/logic/slot_registry.dart';

/// A stateful widget that counts taps, to prove a subtree stays mounted.
class StateProbe extends StatefulWidget {
  /// Creates a probe.
  const StateProbe({super.key});

  @override
  State<StateProbe> createState() => StateProbeState();
}

/// The probe's state, compared by identity across layout changes.
class StateProbeState extends State<StateProbe> {
  /// How many times the probe was tapped.
  int taps = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    key: const Key('probe.tap'),
    onTap: () => setState(() => taps++),
    child: Center(child: Text('probe $taps')),
  );
}

ModuleSlot _slot(String id, WidgetBuilder builder, String label) => ModuleSlot(
  id: id,
  path: '/$id',
  label: (_) => label,
  icon: Icons.circle_outlined,
  builder: builder,
);

/// A registry like M0's whose Home screen is a [StateProbe].
SlotRegistry probeRegistry() => SlotRegistry(
  slots: [
    _slot('home', (_) => const StateProbe(), 'Home'),
    _slot('personal', (_) => const SizedBox(), 'Personal'),
    _slot('organisation', (_) => const SizedBox(), 'Organisation'),
  ],
  settings: _slot('settings', (_) => const SizedBox(), 'Settings'),
);
