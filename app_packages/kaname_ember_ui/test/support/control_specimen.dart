import 'package:flutter/material.dart';

/// Every styled control at rest, selected and disabled where it applies, laid
/// out on a 720 by 640 logical-pixel page for the golden test.
///
/// After its first frame the page opens one menu, shows one tooltip and shows
/// one snackbar, so the specimen also covers those layers.
final class ControlSpecimen extends StatefulWidget {
  /// Creates the specimen.
  const ControlSpecimen({super.key});

  /// The size the specimen is laid out in.
  static const Size size = Size(720, 640);

  @override
  State<ControlSpecimen> createState() => _SpecimenState();
}

class _SpecimenState extends State<ControlSpecimen> {
  final _menu = MenuController();
  final _tooltip = GlobalKey<TooltipState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  void _reveal() {
    _menu.open();
    _tooltip.currentState?.ensureTooltipVisible();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Saved to your notebook'),
        action: SnackBarAction(label: 'Undo', onPressed: () {}),
        duration: const Duration(days: 1),
        width: 320,
      ),
    );
  }

  Widget _row(
    String label,
    List<Widget> children, {
    CrossAxisAlignment align = CrossAxisAlignment.center,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: align,
      children: [
        SizedBox(
          width: 96,
          child: Padding(
            padding: EdgeInsets.only(
              top: align == CrossAxisAlignment.start ? 8 : 0,
            ),
            child: Text(label, style: Theme.of(context).textTheme.labelSmall),
          ),
        ),
        for (final child in children)
          Padding(padding: const EdgeInsets.only(right: 12), child: child),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Buttons', [
              OutlinedButton(onPressed: () {}, child: const Text('Default')),
              FilledButton(onPressed: () {}, child: const Text('Primary')),
              TextButton(onPressed: () {}, child: const Text('Quiet')),
            ]),
            _row('Disabled', [
              const OutlinedButton(onPressed: null, child: Text('Default')),
              const FilledButton(onPressed: null, child: Text('Primary')),
              const TextButton(onPressed: null, child: Text('Quiet')),
            ]),
            _row('Icon buttons', [
              IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
              IconButton(
                onPressed: () {},
                isSelected: true,
                icon: const Icon(Icons.star_border),
                selectedIcon: const Icon(Icons.star),
              ),
              const IconButton(onPressed: null, icon: Icon(Icons.add)),
            ]),
            _row('Chips', [
              FilterChip(
                label: const Text('Filter'),
                selected: false,
                onSelected: (_) {},
              ),
              FilterChip(
                label: const Text('Selected'),
                selected: true,
                onSelected: (_) {},
              ),
              const FilterChip(
                label: Text('Disabled'),
                selected: false,
                onSelected: null,
              ),
            ]),
            _row('Fields', [
              const SizedBox(
                width: 160,
                child: TextField(
                  decoration: InputDecoration(labelText: 'Name'),
                ),
              ),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: TextEditingController(text: 'Aria Vale'),
                  decoration: const InputDecoration(labelText: 'Pilot'),
                ),
              ),
              const SizedBox(
                width: 160,
                child: TextField(
                  enabled: false,
                  decoration: InputDecoration(labelText: 'Locked'),
                ),
              ),
            ]),
            _row('Layers', [
              SizedBox(
                height: 128,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Tooltip(
                    key: _tooltip,
                    message: 'Pins this note',
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.push_pin_outlined, size: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 48),
              SizedBox(
                height: 128,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: MenuAnchor(
                    controller: _menu,
                    alignmentOffset: const Offset(0, 2),
                    menuChildren: [
                      MenuItemButton(
                        onPressed: () {},
                        child: const Text('Rename'),
                      ),
                      MenuItemButton(
                        onPressed: () {},
                        child: const Text('Duplicate'),
                      ),
                      const MenuItemButton(
                        onPressed: null,
                        child: Text('Archive'),
                      ),
                    ],
                    child: const SizedBox(width: 40, height: 1),
                  ),
                ),
              ),
            ], align: CrossAxisAlignment.start),
          ],
        ),
      ),
    );
  }
}
