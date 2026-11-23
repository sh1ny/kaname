import 'dart:convert';

import 'package:kaname_esi/kaname_esi.dart';

/// A transport that answers every request with one recorded outcome and
/// keeps the requests it was given. It opens no connection.
final class FixtureTransport implements EsiTransport {
  /// Answers with [outcome].
  FixtureTransport(this.outcome);

  /// Answers with a response of [status], [headers] and a UTF-8 [body].
  FixtureTransport.respond(
    int status, {
    Map<String, String> headers = const {},
    String body = '',
  }) : outcome = EsiResponse(
         status: status,
         headers: headers,
         body: utf8.encode(body),
       );

  /// The outcome every request gets.
  final EsiTransportOutcome outcome;

  /// The requests sent so far, in order.
  final List<EsiRequest> requests = [];

  @override
  Future<EsiTransportOutcome> send(EsiRequest request) async {
    requests.add(request);
    return outcome;
  }
}
