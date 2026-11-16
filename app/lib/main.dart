import 'package:flutter/material.dart';
import 'package:kaname_ember_ui/kaname_ember_ui.dart';

/// Starts the app after registering the bundled font licences.
///
/// Registration reads the licence assets, so it completes before the first
/// frame; a missing asset fails startup instead of shipping unlicensed fonts.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EmberFonts.registerLicences();
  runApp(const KanameApp());
}

/// The Kaname app: a placeholder screen until the app shell lands.
class KanameApp extends StatelessWidget {
  /// Creates the app.
  const KanameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kaname',
      theme: EmberTheme.light(),
      darkTheme: EmberTheme.dark(),
      themeMode: ThemeMode.system,
      // Ember switches themes instantly; the app shell must keep this.
      themeAnimationDuration: Duration.zero,
      home: const Scaffold(body: Center(child: Text('Kaname'))),
    );
  }
}
