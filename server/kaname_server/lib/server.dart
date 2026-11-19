import 'src/generated/serverpod.dart';
import 'src/static_data/static_data_start.dart';

/// Starts the Serverpod server with the generated protocol and endpoints.
///
/// After the server has started, the monolith role in the development,
/// staging and production run modes starts its static-data work: the compute
/// worker and, with no active build, the first import (design D8). The
/// import runs detached, so requests are served meanwhile.
Future<void> run(List<String> args) async {
  final pod = Serverpod(args);
  await pod.start();
  startStaticData(pod);
}
