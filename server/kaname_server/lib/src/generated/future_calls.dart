/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: depend_on_referenced_packages

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _ida;

import 'package:clock/clock.dart' as _io0w16m8;
import 'package:kaname_server/src/generated/affiliation/affiliation_first_known_args.dart'
    as _id0q6syb;
import 'package:kaname_server/src/generated/affiliation/affiliation_sweep_args.dart'
    as _ibelcfu3;
import 'package:serverpod/serverpod.dart' as _is;

import '../affiliation/affiliation_call.dart' as _i4ka63n8;
import '../esi/esi_call_log_prune_call.dart' as _iowjp61k;
import '../esi/sso_session_prune_call.dart' as _isn4qq34;
import '../static_data/static_data_check_call.dart' as _i66h21ix;

/// Invokes a future call.
typedef _InvokeFutureCall = Future<void> Function(
  String name,
  _is.SerializableModel? object,
);

extension ServerpodFutureCallsGetter on _is.Serverpod {
  /// Generated future calls.
  FutureCalls get futureCalls => FutureCalls();
}

class FutureCalls extends _is.FutureCallDispatch<_FutureCallRef> {
  FutureCalls._();

  factory FutureCalls() {
    return _instance;
  }

  static final FutureCalls _instance = FutureCalls._();

  _is.FutureCallManager? _futureCallManager;

  String? _serverId;

  String get _effectiveServerId {
    if (_serverId == null) {
      throw StateError('FutureCalls is not initialized.');
    }
    return _serverId!;
  }

  _is.FutureCallManager get _effectiveFutureCallManager {
    if (_futureCallManager == null) {
      throw StateError('FutureCalls is not initialized.');
    }
    return _futureCallManager!;
  }

  @override
  void initialize(_is.FutureCallManager futureCallManager, String serverId) {
    var registeredFutureCalls = <String, _is.InvokableFutureCall>{
      'AffiliationCallSweepFutureCall': AffiliationCallSweepFutureCall(),
      'AffiliationCallFirstKnownFutureCall':
          AffiliationCallFirstKnownFutureCall(),
      'EsiCallLogPruneCallRunFutureCall': EsiCallLogPruneCallRunFutureCall(),
      'SsoSessionPruneCallRunFutureCall': SsoSessionPruneCallRunFutureCall(),
      'StaticDataCheckCallRunFutureCall': StaticDataCheckCallRunFutureCall(),
    };
    _futureCallManager = futureCallManager;
    _serverId = serverId;
    for (final entry in registeredFutureCalls.entries) {
      _futureCallManager?.registerFutureCall(entry.value, entry.key);
    }
  }

  @override
  _FutureCallRef callAtTime(DateTime time, {String? identifier}) {
    return _FutureCallRef((name, object) {
      return _effectiveFutureCallManager.scheduleFutureCall(
        name,
        object,
        time,
        _effectiveServerId,
        identifier,
      );
    });
  }

  @override
  _FutureCallRef callWithDelay(Duration delay, {String? identifier}) {
    return _FutureCallRef((name, object) {
      return _effectiveFutureCallManager.scheduleFutureCall(
        name,
        object,
        DateTime.now().toUtc().add(delay),
        _effectiveServerId,
        identifier,
      );
    });
  }

  @override
  _is.RecurringFutureCallDispatch<_FutureCallRef> callRecurring({
    String? identifier,
  }) {
    return _RecurringFutureCallDispatchImpl(
      _effectiveFutureCallManager,
      _effectiveServerId,
      identifier,
    );
  }

  @override
  Future<void> cancel(String identifier) async {
    await _effectiveFutureCallManager.cancelFutureCall(identifier);
  }
}

class _RecurringFutureCallDispatchImpl
    extends _is.RecurringFutureCallDispatch<_FutureCallRef> {
  _RecurringFutureCallDispatchImpl(
    this._futureCallManager,
    this._serverId,
    this._identifier,
  );

  final _is.FutureCallManager _futureCallManager;

  final String _serverId;

  final String? _identifier;

  @override
  _FutureCallRef cron(String cronExpression) {
    return _FutureCallRef((name, object) {
      return _futureCallManager.scheduleFutureCall(
        name,
        object,
        _is.Cron.parse(cronExpression).nextTime(),
        _serverId,
        _identifier,
        scheduling: _is.CronFutureCallScheduling(cron: cronExpression),
      );
    });
  }

  @override
  _FutureCallRef every(Duration interval, {DateTime? start}) {
    final now = _io0w16m8.clock.now().toUtc();
    return _FutureCallRef((name, object) {
      return _futureCallManager.scheduleFutureCall(
        name,
        object,
        start ?? now.add(interval),
        _serverId,
        _identifier,
        scheduling: _is.IntervalFutureCallScheduling(
          interval: interval,
          start: start,
        ),
      );
    });
  }
}

class _FutureCallRef {
  _FutureCallRef(this._invokeFutureCall);

  final _InvokeFutureCall _invokeFutureCall;

  late final affiliationCall = _AffiliationCallFutureCallDispatcher(
    _invokeFutureCall,
  );

  late final esiCallLogPruneCall = _EsiCallLogPruneCallFutureCallDispatcher(
    _invokeFutureCall,
  );

  late final ssoSessionPruneCall = _SsoSessionPruneCallFutureCallDispatcher(
    _invokeFutureCall,
  );

  late final staticDataCheckCall = _StaticDataCheckCallFutureCallDispatcher(
    _invokeFutureCall,
  );
}

class _AffiliationCallFutureCallDispatcher {
  _AffiliationCallFutureCallDispatcher(this._invokeFutureCall);

  final _InvokeFutureCall _invokeFutureCall;

  Future<void> sweep(_ibelcfu3.AffiliationSweepArgs args) {
    return _invokeFutureCall('AffiliationCallSweepFutureCall', args);
  }

  Future<void> firstKnown(_id0q6syb.AffiliationFirstKnownArgs args) {
    return _invokeFutureCall('AffiliationCallFirstKnownFutureCall', args);
  }
}

class _EsiCallLogPruneCallFutureCallDispatcher {
  _EsiCallLogPruneCallFutureCallDispatcher(this._invokeFutureCall);

  final _InvokeFutureCall _invokeFutureCall;

  Future<void> run() {
    return _invokeFutureCall('EsiCallLogPruneCallRunFutureCall', null);
  }
}

class _SsoSessionPruneCallFutureCallDispatcher {
  _SsoSessionPruneCallFutureCallDispatcher(this._invokeFutureCall);

  final _InvokeFutureCall _invokeFutureCall;

  Future<void> run() {
    return _invokeFutureCall('SsoSessionPruneCallRunFutureCall', null);
  }
}

class _StaticDataCheckCallFutureCallDispatcher {
  _StaticDataCheckCallFutureCallDispatcher(this._invokeFutureCall);

  final _InvokeFutureCall _invokeFutureCall;

  Future<void> run() {
    return _invokeFutureCall('StaticDataCheckCallRunFutureCall', null);
  }
}

/// Executes a sweep only if this boot still expects its logical slot.
class AffiliationCallSweepFutureCall
    extends _is.FutureCall<_ibelcfu3.AffiliationSweepArgs>
    implements _is.InvokableFutureCall<_ibelcfu3.AffiliationSweepArgs> {
  @override
  _ida.Future<void> invoke(
    _is.Session session,
    _ibelcfu3.AffiliationSweepArgs? args,
  ) async {
    await _i4ka63n8.AffiliationCall().sweep(session, args!);
  }
}

/// Refreshes an identity that committed before this call was registered.
class AffiliationCallFirstKnownFutureCall
    extends _is.FutureCall<_id0q6syb.AffiliationFirstKnownArgs>
    implements _is.InvokableFutureCall<_id0q6syb.AffiliationFirstKnownArgs> {
  @override
  _ida.Future<void> invoke(
    _is.Session session,
    _id0q6syb.AffiliationFirstKnownArgs? args,
  ) async {
    await _i4ka63n8.AffiliationCall().firstKnown(session, args!);
  }
}

/// Sweeps old rows without overlapping another local sweep.
class EsiCallLogPruneCallRunFutureCall extends _is.FutureCall
    implements _is.InvokableFutureCall {
  @override
  _ida.Future<void> invoke(
    _is.Session session,
    _is.SerializableModel? object,
  ) async {
    await _iowjp61k.EsiCallLogPruneCall().run(session);
  }
}

/// Removes one indexed batch. The next run handles any backlog.
class SsoSessionPruneCallRunFutureCall extends _is.FutureCall
    implements _is.InvokableFutureCall {
  @override
  _ida.Future<void> invoke(
    _is.Session session,
    _is.SerializableModel? object,
  ) async {
    await _isn4qq34.SsoSessionPruneCall().run(session);
  }
}

/// Sends the check to the worker and returns without waiting for it.
class StaticDataCheckCallRunFutureCall extends _is.FutureCall
    implements _is.InvokableFutureCall {
  @override
  _ida.Future<void> invoke(
    _is.Session session,
    _is.SerializableModel? object,
  ) async {
    await _i66h21ix.StaticDataCheckCall().run(session);
  }
}
