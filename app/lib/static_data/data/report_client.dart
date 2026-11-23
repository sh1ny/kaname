import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kaname_client/kaname_client.dart';

import '../../server/data/server_address.dart';
import 'bundle_http_client.dart';

/// Reads the public change report from a configured server.
abstract interface class StaticDataReportClient {
  /// Returns the report answer, or an unavailable result on failure.
  Future<ReportRead> read();
}

/// The result of reading a change report.
sealed class ReportRead {
  const ReportRead();
}

/// A typed report answer was received.
final class ReportReceived extends ReportRead {
  /// Creates a received report result.
  const ReportReceived(this.report);

  /// The server's public report answer.
  final StaticDataChangeReport report;
}

/// The report could not be obtained or decoded.
final class ReportUnavailable extends ReportRead {
  /// Creates an unavailable report result.
  const ReportUnavailable();
}

/// Reads reports over HTTP using the resolved API base address.
final class HttpStaticDataReportClient implements StaticDataReportClient {
  /// Creates a client for [server], with a deadline for the whole transfer.
  HttpStaticDataReportClient({
    required this.server,
    this.timeout = const Duration(seconds: 30),
  });

  /// The server from which reports are read.
  final ConfiguredServer server;

  /// The maximum time allowed for headers and body together.
  final Duration timeout;

  @override
  Future<ReportRead> read() {
    final abort = Completer<void>();
    final result = Completer<ReportRead>();
    final client = abortableBundleClient(abort.future);
    late final Timer timer;

    void finish(ReportRead answer) {
      if (result.isCompleted) return;
      timer.cancel();
      result.complete(answer);
      abort.complete();
      client.close();
    }

    timer = Timer(timeout, () => finish(const ReportUnavailable()));
    unawaited(() async {
      try {
        final request = http.AbortableRequest(
          'GET',
          server.uri.resolve('static-data/report'),
          abortTrigger: abort.future,
        );
        final response = await client.send(request);
        if (result.isCompleted) {
          unawaited(response.stream.listen(null).cancel());
          return;
        }
        if (response.statusCode != 200) {
          finish(const ReportUnavailable());
          return;
        }
        final body = await response.stream.bytesToString();
        final decoded = jsonDecode(body);
        if (decoded is! Map<String, Object?>) {
          finish(const ReportUnavailable());
          return;
        }
        final report = StaticDataChangeReport.fromJson(decoded);
        if (report.outcome == StaticDataReportOutcome.reportReady &&
            (report.activeBuild == null ||
                report.fromBuild == null ||
                report.toBuild == null ||
                report.files == null)) {
          finish(const ReportUnavailable());
          return;
        }
        finish(ReportReceived(report));
      } on Object {
        finish(const ReportUnavailable());
      }
    }());
    return result.future;
  }
}
