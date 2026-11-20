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
import 'package:kaname_server/src/generated/future_calls.dart' as _ibdqg5o2;
import 'package:serverpod/serverpod.dart' as _is;

import '../health/health_endpoint.dart' as _id9paj9q;
import '../static_data/static_data_endpoint.dart' as _ije194qr;
export 'future_calls.dart' show ServerpodFutureCallsGetter;

class Endpoints extends _is.EndpointDispatch {
  @override
  void initializeEndpoints(_is.Server server) {
    initializeOwnEndpoints(server);
  }

  @override
  void initializeOwnEndpoints(_is.Server server) {
    var endpoints = <String, _is.Endpoint>{
      'health': _id9paj9q.HealthEndpoint()..initialize(server, 'health', null),
      'staticData': _ije194qr.StaticDataEndpoint()
        ..initialize(server, 'staticData', null),
    };
    connectors['health'] = _is.EndpointConnector(
      name: 'health',
      endpoint: endpoints['health']!,
      methodConnectors: {
        'check': _is.MethodConnector(
          name: 'check',
          params: {},
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['health'] as _id9paj9q.HealthEndpoint).check(session),
        ),
      },
    );
    connectors['staticData'] = _is.EndpointConnector(
      name: 'staticData',
      endpoint: endpoints['staticData']!,
      methodConnectors: {
        'bundleAnnouncements': _is.MethodStreamConnector(
          name: 'bundleAnnouncements',
          params: {},
          streamParams: {},
          returnType: _is.MethodStreamReturnType.streamType,
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) => (endpoints['staticData'] as _ije194qr.StaticDataEndpoint)
                  .bundleAnnouncements(session),
        ),
      },
    );
  }

  @override
  _is.FutureCallDispatch? get futureCalls {
    return _ibdqg5o2.FutureCalls();
  }
}
