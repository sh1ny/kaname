import 'package:flutter/material.dart';

void main() {
  runApp(const KanameApp());
}

/// The Kaname app: a placeholder screen until the app shell lands.
class KanameApp extends StatelessWidget {
  /// Creates the app.
  const KanameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Kaname',
      home: Scaffold(body: Center(child: Text('Kaname'))),
    );
  }
}
