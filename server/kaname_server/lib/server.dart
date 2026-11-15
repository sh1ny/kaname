import 'src/generated/serverpod.dart';

/// Starts the Serverpod server with the generated protocol and endpoints.
Future<void> run(List<String> args) async {
  final pod = Serverpod(args);
  await pod.start();
}
