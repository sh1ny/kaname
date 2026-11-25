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
import 'package:kaname_client/src/protocol/esi/esi_call_log_cursor.dart'
    as _isbxvgd1;
import 'package:kaname_client/src/protocol/esi/esi_call_log_page.dart'
    as _i0ohbe4c;
import 'package:kaname_client/src/protocol/esi/esi_route_count_page.dart'
    as _inqxx39c;
import 'package:kaname_client/src/protocol/health/health_report.dart'
    as _ipujyub9;
import 'package:kaname_client/src/protocol/static_data/admin_answer.dart'
    as _ix017a22;
import 'package:kaname_client/src/protocol/static_data/admin_operation_answer.dart'
    as _imdz7n5d;
import 'package:kaname_client/src/protocol/static_data/bundle_announcement.dart'
    as _ibnxtke0;
import 'package:kaname_client/src/protocol/static_data/setting_revision.dart'
    as _i4m0ll8r;
import 'package:kaname_client/src/protocol/static_data/static_data_status.dart'
    as _iewgw5zo;
import 'package:serverpod_client/serverpod_client.dart' as _isc;

import 'protocol.dart' as _il2as5qe;

/// Viewer-only receipts and fixed-window totals. Callers cannot choose a viewer.
/// {@category Endpoint}
class EndpointEsiCallLog extends _isc.EndpointRef {
  EndpointEsiCallLog(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'esiCallLog';

  /// Returns the current viewer's bounded page after an optional keyset cursor.
  _ida.Future<_i0ohbe4c.EsiCallLogPage> ownRows(
    _isbxvgd1.EsiCallLogCursor? after,
  ) => caller.callServerEndpoint<_i0ohbe4c.EsiCallLogPage>(
    'esiCallLog',
    'ownRows',
    {'after': after},
  );

  /// Returns released totals only to an authenticated admin.
  _ida.Future<_inqxx39c.EsiRouteCountPage> routeCounts() =>
      caller.callServerEndpoint<_inqxx39c.EsiRouteCountPage>(
        'esiCallLog',
        'routeCounts',
        {},
      );
}

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

/// Static-data mutations require live Kaname admin scope (ADR 0018).
///
/// C11: check the operation id before taking the slot and before dispatch.
/// C21: settlement owns an admin job from before its admission insert until
/// its durable row ends; an RPC timeout does not release the slot.
/// C27: each admin database call takes one of two work tokens through its
/// session cleanup; admission checks its deadline before the slot and insert.
/// {@category Endpoint}
class EndpointStaticDataAdmin extends _isc.EndpointRef {
  EndpointStaticDataAdmin(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'staticDataAdmin';

  /// Starts an admitted CCP check (D4). The row owns its terminal outcome.
  _ida.Future<_ix017a22.AdminAnswer> updateNow(String operationId) =>
      caller.callServerEndpoint<_ix017a22.AdminAnswer>(
        'staticDataAdmin',
        'updateNow',
        {'operationId': operationId},
      );

  /// Restores only the build revision confirmed by the caller (D5, C14).
  _ida.Future<_ix017a22.AdminAnswer> rollBack(
    String operationId,
    int expectedRevision,
  ) => caller.callServerEndpoint<_ix017a22.AdminAnswer>(
    'staticDataAdmin',
    'rollBack',
    {'operationId': operationId, 'expectedRevision': expectedRevision},
  );

  /// C31: applies a setting only at the confirmed revision. A replay of the
  /// exact write id confirms the current value and revision, never overwrites.
  _ida.Future<_ix017a22.AdminAnswer> setAutoUpdate(
    bool value,
    _i4m0ll8r.SettingRevision expectedRevision,
    String writeId,
  ) => caller.callServerEndpoint<_ix017a22.AdminAnswer>(
    'staticDataAdmin',
    'setAutoUpdate',
    {'value': value, 'expectedRevision': expectedRevision, 'writeId': writeId},
  );
}

/// The static-data endpoint: the announcement stream of the client data
/// bundle.
/// {@category Endpoint}
class EndpointStaticData extends _isc.EndpointRef {
  EndpointStaticData(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'staticData';

  /// Reads a bounded public status snapshot without requiring sign-in (D2).
  _ida.Future<_iewgw5zo.StaticDataStatus> status() =>
      caller.callServerEndpoint<_iewgw5zo.StaticDataStatus>(
        'staticData',
        'status',
        {},
      );

  /// Reads only the requested operation's durable progress (D9, D21).
  _ida.Future<_imdz7n5d.AdminOperationAnswer> operation(String operationId) =>
      caller.callServerEndpoint<_imdz7n5d.AdminOperationAnswer>(
        'staticData',
        'operation',
        {'operationId': operationId},
      );

  /// Streams the announcement of the bundle the app may download.
  ///
  /// The first event is the announcement the announcer has installed, sent
  /// once the announcer has installed its first one (a failed first refresh,
  /// or none that succeeded 19 seconds after its start, installs "none"); an
  /// event follows each change of the installed announcement. Needs no
  /// sign-in.
  ///
  /// The subscription is admitted, or refused, when this method is called:
  /// at most `BundleAnnouncementRuntime.maxStreamsPerClient` (16) streams
  /// per client and `maxStreams` (2,000) in all. A refused subscription ends
  /// at once, without an event or an error. An admitted stream holds its
  /// places and its 30-minute life runs from then; until Serverpod listens
  /// to it, it has no bus listener and receives nothing, and once listened
  /// to it first sends the announcement installed at that moment.
  ///
  /// ## Carried constraints
  ///
  /// - **C2:** Both bounds are taken in the same synchronous step as their
  ///   check (`BundleAnnouncementRuntime.admit`), and freed only by the
  ///   stream's single `end()`. A stream that has ended never subscribes to
  ///   the bus or sends, even if it is listened to later. Moving either
  ///   count to `onListen` reopens the concurrent overshoot.
  /// - **C20:** The stream is bounded by count, rate and lifetime. The server
  ///   refuses streams over its bounds by ending them at once without an
  ///   event. Each ends after 30 minutes on the server's clock, also while
  ///   its client reads nothing, because Serverpod's endpoint streams have no
  ///   backpressure (A14): what the stream sends is bounded by rate, at most
  ///   one event per change of the installed announcement, never by the
  ///   client's reading. Whatever ends the stream (expiry, the client's
  ///   disconnect, an error) removes its bus listener and frees its places.
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
    esiCallLog = EndpointEsiCallLog(this);
    health = EndpointHealth(this);
    staticDataAdmin = EndpointStaticDataAdmin(this);
    staticData = EndpointStaticData(this);
  }

  late final EndpointEsiCallLog esiCallLog;

  late final EndpointHealth health;

  late final EndpointStaticDataAdmin staticDataAdmin;

  late final EndpointStaticData staticData;

  @override
  Map<String, _isc.EndpointRef> get endpointRefLookup => {
    'esiCallLog': esiCallLog,
    'health': health,
    'staticDataAdmin': staticDataAdmin,
    'staticData': staticData,
  };

  @override
  Map<String, _isc.ModuleEndpointCaller> get moduleLookup => {};
}
