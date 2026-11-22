/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _ida;

import 'package:http/http.dart' as _i85jenna;
import 'package:kaname_client/src/protocol/health/health_report.dart'
    as _ipujyub9;
import 'package:kaname_client/src/protocol/static_data/bundle_announcement.dart'
    as _ibnxtke0;
import 'package:serverpod_client/serverpod_client.dart' as _isc;

import 'protocol.dart' as _il2as5qe;

/// Reports the server version and the status of its dependencies, to anyone.
///
/// The answer is a typed [HealthReport]. It never carries a host, a port, a
/// credential or the text of a dependency error: a failing check is logged on
/// the server and shows up as [DependencyStatus.down] only.
/// {@category Endpoint}
class EndpointHealth extends _isc.EndpointRef {
  EndpointHealth(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'health';

  /// Checks Postgres (`SELECT 1`) and Redis (`PING`) concurrently, each under
  /// a two-second timeout, and returns their status with the server version.
  ///
  /// A timeout or an exception from a dependency maps to
  /// [DependencyStatus.down] and is logged on the server only.
  _ida.Future<_ipujyub9.HealthReport> check() =>
      caller.callServerEndpoint<_ipujyub9.HealthReport>('health', 'check', {});
}

/// The static-data endpoint: the announcement stream of the client data
/// bundle.
/// {@category Endpoint}
class EndpointStaticData extends _isc.EndpointRef {
  EndpointStaticData(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'staticData';

  /// Streams the announcement of the bundle the app may download.
  ///
  /// The first event is the announcement the announcer has installed, sent
  /// once the announcer has installed its first one (a failed first refresh,
  /// or none that succeeded 19 seconds after its start, installs "none"); an
  /// event follows each change of the installed announcement. Needs no
  /// sign-in.
  ///
  /// ## Carried constraint
  ///
  /// - **C20:** The stream is bounded by count, rate and lifetime. The server
  ///   holds at most 2,000 of them (`BundleAnnouncementRuntime.maxStreams`)
  ///   and refuses more by ending the stream at once without an event. Each
  ///   ends after 30 minutes on the server's clock, also while its client
  ///   reads nothing, because Serverpod's endpoint streams have no
  ///   backpressure (A14): what the stream sends is bounded by rate, at most
  ///   one event per change of the installed announcement, never by the
  ///   client's reading. Whatever ends the stream (expiry, the client's
  ///   disconnect, an error) removes its bus listener and frees its place.
  ///   Every send carries the announcement installed at that moment, and
  ///   only when its revision is higher than the last one this stream sent
  ///   (C16): bus messages are wake-ups, never the payload, so a late or
  ///   buffered message cannot send a retired announcement. The handoff is
  ///   synchronous; Serverpod writes the value to the WebSocket one
  ///   microtask later, and an announcement installed in that microtask
  ///   follows at once.
  _ida.Stream<_ibnxtke0.BundleAnnouncement> bundleAnnouncements() =>
      caller.callStreamingServerEndpoint<
        _ida.Stream<_ibnxtke0.BundleAnnouncement>,
        _ibnxtke0.BundleAnnouncement
      >('staticData', 'bundleAnnouncements', {}, {});
}

class Client extends _isc.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(_isc.MethodCallContext, Object, StackTrace)? onFailedCall,
    Function(_isc.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
    _i85jenna.Client? httpClientOverride,
  }) : super(
         host,
         _il2as5qe.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
         httpClientOverride: httpClientOverride,
       ) {
    health = EndpointHealth(this);
    staticData = EndpointStaticData(this);
  }

  late final EndpointHealth health;

  late final EndpointStaticData staticData;

  @override
  Map<String, _isc.EndpointRef> get endpointRefLookup => {
    'health': health,
    'staticData': staticData,
  };

  @override
  Map<String, _isc.ModuleEndpointCaller> get moduleLookup => {};
}
