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
import 'package:kaname_server/src/generated/esi/esi_call_log_cursor.dart'
    as _izoszn5i;
import 'package:kaname_server/src/generated/future_calls.dart' as _ibdqg5o2;
import 'package:kaname_server/src/generated/static_data/setting_revision.dart'
    as _isqu85ty;
import 'package:serverpod/serverpod.dart' as _is;

import '../esi/esi_call_log_endpoint.dart' as _icvsz6ul;
import '../health/health_endpoint.dart' as _id9paj9q;
import '../static_data/static_data_admin_endpoint.dart' as _i18bqoi9;
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
      'esiCallLog': _icvsz6ul.EsiCallLogEndpoint()
        ..initialize(server, 'esiCallLog', null),
      'health': _id9paj9q.HealthEndpoint()..initialize(server, 'health', null),
      'staticDataAdmin': _i18bqoi9.StaticDataAdminEndpoint()
        ..initialize(server, 'staticDataAdmin', null),
      'staticData': _ije194qr.StaticDataEndpoint()
        ..initialize(server, 'staticData', null),
    };
    connectors['esiCallLog'] = _is.EndpointConnector(
      name: 'esiCallLog',
      endpoint: endpoints['esiCallLog']!,
      methodConnectors: {
        'ownRows': _is.MethodConnector(
          name: 'ownRows',
          params: {
            'after': _is.ParameterDescription(
              name: 'after',
              type: _is.getType<_izoszn5i.EsiCallLogCursor?>(),
              nullable: true,
            ),
          },
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['esiCallLog'] as _icvsz6ul.EsiCallLogEndpoint).ownRows(
                session,
                params['after'],
              ),
        ),
        'routeCounts': _is.MethodConnector(
          name: 'routeCounts',
          params: {},
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['esiCallLog'] as _icvsz6ul.EsiCallLogEndpoint)
                  .routeCounts(session),
        ),
      },
    );
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
    connectors['staticDataAdmin'] = _is.EndpointConnector(
      name: 'staticDataAdmin',
      endpoint: endpoints['staticDataAdmin']!,
      methodConnectors: {
        'updateNow': _is.MethodConnector(
          name: 'updateNow',
          params: {
            'operationId': _is.ParameterDescription(
              name: 'operationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['staticDataAdmin']
                      as _i18bqoi9.StaticDataAdminEndpoint)
                  .updateNow(session, params['operationId']),
        ),
        'rollBack': _is.MethodConnector(
          name: 'rollBack',
          params: {
            'operationId': _is.ParameterDescription(
              name: 'operationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'expectedRevision': _is.ParameterDescription(
              name: 'expectedRevision',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['staticDataAdmin']
                      as _i18bqoi9.StaticDataAdminEndpoint)
                  .rollBack(
                    session,
                    params['operationId'],
                    params['expectedRevision'],
                  ),
        ),
        'setAutoUpdate': _is.MethodConnector(
          name: 'setAutoUpdate',
          params: {
            'value': _is.ParameterDescription(
              name: 'value',
              type: _is.getType<bool>(),
              nullable: false,
            ),
            'expectedRevision': _is.ParameterDescription(
              name: 'expectedRevision',
              type: _is.getType<_isqu85ty.SettingRevision>(),
              nullable: false,
            ),
            'writeId': _is.ParameterDescription(
              name: 'writeId',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['staticDataAdmin']
                      as _i18bqoi9.StaticDataAdminEndpoint)
                  .setAutoUpdate(
                    session,
                    params['value'],
                    params['expectedRevision'],
                    params['writeId'],
                  ),
        ),
      },
    );
    connectors['staticData'] = _is.EndpointConnector(
      name: 'staticData',
      endpoint: endpoints['staticData']!,
      methodConnectors: {
        'status': _is.MethodConnector(
          name: 'status',
          params: {},
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['staticData'] as _ije194qr.StaticDataEndpoint).status(
                session,
              ),
        ),
        'operation': _is.MethodConnector(
          name: 'operation',
          params: {
            'operationId': _is.ParameterDescription(
              name: 'operationId',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call: (_is.Session session, Map<String, dynamic> params) async =>
              (endpoints['staticData'] as _ije194qr.StaticDataEndpoint)
                  .operation(session, params['operationId']),
        ),
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
