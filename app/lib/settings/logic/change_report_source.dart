import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../server/data/server_address.dart';
import '../../server/logic/server_status.dart';
import '../../static_data/data/report_client.dart';

/// The injectable client used to read the server's change report.
final changeReportClientProvider = Provider<StaticDataReportClient?>((ref) {
  return switch (ref.watch(serverTargetProvider)) {
    final ConfiguredServer server => HttpStaticDataReportClient(server: server),
    NoServer() || InvalidServer() => null,
  };
});
