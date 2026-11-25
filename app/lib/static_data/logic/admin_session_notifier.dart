import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaname_client/kaname_client.dart';

import '../../esi_sso/logic/account.dart';
import '../../server/data/secure_for_admin.dart';
import '../../server/data/server_address.dart';
import '../../server/logic/server_status.dart' show serverTargetProvider;
import '../data/admin_client.dart';
import '../data/rpc_call.dart';
import 'admin_session_state.dart';
import 'admin_setting_tracker.dart';
import 'server_static_data_status_notifier.dart';
import 'static_data_notifier.dart' show staticDataTimersProvider;

/// The generated admin API for the resolved target, including public progress.
final staticDataAdminClientProvider = Provider<StaticDataAdminClient?>((ref) {
  return switch (ref.watch(serverTargetProvider)) {
    ConfiguredServer(:final uri) => _adminClient(ref, uri),
    NoServer() || InvalidServer() => null,
  };
});

ClientStaticDataAdmin _adminClient(Ref ref, Uri uri) {
  final client = ClientStaticDataAdmin(uri);
  ref.onDispose(client.close);
  return client;
}

/// Current verified admin bearer for the exact target; null is read-only.
final staticDataAdminBearerProvider = Provider<String?>((ref) {
  final session = ref.watch(connectedAccountSessionProvider);
  if (session == null || !session.pilot.admin) return null;
  return switch (ref.watch(serverTargetProvider)) {
    ConfiguredServer(:final uri) => session.bearerFor(uri),
    _ => null,
  };
});

/// Monotonic time since an arbitrary origin, used for job limits (D18).
final adminSessionElapsedProvider = Provider<Duration Function()>((ref) {
  final watch = Stopwatch()..start();
  return () => watch.elapsed;
});

/// Supplies fresh operation and setting-write IDs.
final adminRequestIdProvider = Provider<String Function()>(
  (ref) => newStaticDataRequestId,
);

/// The in-memory admin state of this app run.
final adminSessionProvider =
    NotifierProvider<AdminSessionNotifier, AdminSessionState>(
      AdminSessionNotifier.new,
    );

/// Owns static-data actions separately from identity and the public job follow.
///
/// A denial affects only the exact session generation that sent the request.
/// Losing authority does not drop a submitted public job (ADR 0018).
///
/// C33: only fencing evidence clears a pending, unconfirmed auto-update
/// write: a confirmed answer, "setting changed", or a status read above the
/// write's revision (D3, D8). A refused retry does not clear the write.
final class AdminSessionNotifier extends Notifier<AdminSessionState> {
  static const _followLimit = Duration(minutes: 10);
  static const _readInterval = Duration(seconds: 5);
  static const _noRecordAfter = Duration(seconds: 30);

  StaticDataAdminClient? _client;
  late AdminSettingTracker _setting;
  late Duration Function() _elapsed;
  String? _connectedBearer;
  late String Function() _newId;
  late Timer Function(Duration, void Function()) _timer;
  bool _built = false;
  bool _secure = false;
  bool _visible = false;
  bool? _configured;
  StaticDataStatus? _snapshot;
  int _lifetime = 0;
  int _authorityEpoch = 0;
  String? _bearer;
  Timer? _pollTimer;
  _Job? _job;
  AdminJobMessage? _message;
  Future<RpcResult<AdminOperationAnswer>>? _operationRead;

  @override
  AdminSessionState build() {
    _built = false;
    final lifetime = ++_lifetime;
    _client = ref.watch(staticDataAdminClientProvider);
    _secure = switch (ref.watch(serverTargetProvider)) {
      ConfiguredServer(:final uri) => isSecureForAdmin(uri),
      NoServer() || InvalidServer() => false,
    };
    _elapsed = ref.read(adminSessionElapsedProvider);
    _connectedBearer = ref.read(staticDataAdminBearerProvider);
    _bearer = _connectedBearer;
    _newId = ref.read(adminRequestIdProvider);
    _timer = ref.read(staticDataTimersProvider);
    _visible = ref.read(staticDataSettingsVisibleProvider);
    _setting = AdminSettingTracker(
      newId: _newId,
      onChanged: _publish,
      onRefusal: _applyDenial,
    );
    ref.onDispose(() {
      if (lifetime != _lifetime) return;
      _lifetime++;
      _built = false;
      _authorityEpoch++;
      _connectedBearer = null;
      _bearer = null;
      _setting.dispose();
      _pollTimer?.cancel();
      _pollTimer = null;
      _operationRead = null;
      _job = null;
      _message = null;
      _snapshot = null;
      _configured = null;
    });
    ref.listen(staticDataAdminBearerProvider, (_, next) {
      if (_connectedBearer == next) return;
      _connectedBearer = next;
      _bearer = next;
      _authorityEpoch++;
      _publish();
    });
    ref.listen(staticDataSettingsVisibleProvider, (_, shown) {
      _visible = shown;
      if (shown) {
        _advanceFollow();
      } else {
        _pollTimer?.cancel();
        _pollTimer = null;
      }
    });
    ref.listen(serverStaticDataStatusProvider, (_, next) {
      if (next case StatusShown(:final status)) _observeStatus(status);
    });
    if (ref.read(serverStaticDataStatusProvider) case StatusShown(
      :final status,
    )) {
      _observeStatus(status);
    }
    _built = true;
    return _compose();
  }

  void _observeStatus(StaticDataStatus status) {
    if (identical(_snapshot, status)) return;
    _snapshot = status;
    _configured = status.adminConfigured;
    _setting.observe(status.autoUpdate, status.settingRevision);
    _publish();
  }

  bool get _accepted => _secure && _configured == true && _bearer != null;

  AdminSessionState _compose() {
    final job = _job;
    final AdminSessionView view = (
      authority: _accepted ? _authorityEpoch : null,
      configured: _configured,
      secure: _secure,
      serverBusy: _snapshot?.busy ?? false,
      job: job == null
          ? null
          : (
              id: job.id,
              kind: job.kind,
              following: job.following,
              sending: job.sending,
              noRecord: job.noRecord,
              canRetry: _accepted && job.noRecord && !job.sending,
            ),
      message: _message,
      setting: _setting.view,
    );
    return _accepted ? Admin(view) : ReadOnlyAdmin(view);
  }

  void _publish() {
    if (_built && ref.mounted) state = _compose();
  }

  void _applyDenial(AdminAnswer answer, int session) {
    if (_applyDenialAnswer(answer, session)) _publish();
  }

  bool _applyDenialAnswer(AdminAnswer answer, int session) {
    if (session != _authorityEpoch ||
        _bearer == null ||
        answer.outcome != AdminAnswerOutcome.notAuthorized) {
      return false;
    }
    _authorityEpoch++;
    _bearer = null;
    return true;
  }

  /// Reserves a fresh update-now ID synchronously before the request is sent.
  void updateNow() => _press(SdeAdminOperationKind.updateNow);

  /// Reserves a rollback against the build revision the user confirmed.
  void rollBack(int expectedRevision) => _press(
    SdeAdminOperationKind.rollback,
    expectedRevision: expectedRevision,
  );

  void _press(SdeAdminOperationKind kind, {int? expectedRevision}) {
    if (!_accepted ||
        _client == null ||
        _job != null ||
        _snapshot?.busy == true) {
      return;
    }
    if (kind == SdeAdminOperationKind.rollback &&
        _snapshot?.previousBuild == null) {
      return;
    }
    final job = _Job(_newId(), kind, _elapsed(), expectedRevision);
    _job = job;
    _message = AdminJobSending(kind);
    _send(job);
  }

  /// Resends this same press and ID after the server reports no record.
  void retryJob() {
    final job = _job;
    if (job == null ||
        !_accepted ||
        !job.following ||
        !job.noRecord ||
        job.sending) {
      return;
    }
    _send(job);
  }

  void _send(_Job job) {
    final bearer = _bearer!;
    final client = _client!;
    job.sending = true;
    final send = ++job.send;
    final session = _authorityEpoch;
    final alreadyFollowing = job.following;
    _publish();
    final call = switch (job.kind) {
      SdeAdminOperationKind.updateNow => client.updateNow(bearer, job.id),
      SdeAdminOperationKind.rollback => client.rollBack(
        bearer,
        job.id,
        job.expectedRevision!,
      ),
    };
    unawaited(_waitForSend(job, send, session, alreadyFollowing, call));
  }

  Future<void> _waitForSend(
    _Job job,
    int send,
    int session,
    bool alreadyFollowing,
    RpcCall<AdminAnswer> call,
  ) async {
    final result = await call.answer;
    if (!identical(_job, job) || job.send != send) return;
    _handleSend(job, session, alreadyFollowing, result);
    if (result is RpcUnanswered<AdminAnswer> &&
        !identical(call.answer, call.settled)) {
      final late = await call.settled;
      if (late is RpcAnswered<AdminAnswer> &&
          identical(_job, job) &&
          job.send == send) {
        _handleSend(job, session, true, late);
      }
    }
  }

  void _handleSend(
    _Job job,
    int session,
    bool alreadyFollowing,
    RpcResult<AdminAnswer> result,
  ) {
    job.sending = false;
    final answer = switch (result) {
      RpcAnswered(:final value) => value,
      RpcUnanswered() => AdminAnswer(outcome: AdminAnswerOutcome.noAnswerYet),
    };
    _applyDenialAnswer(answer, session);
    _message = AdminJobAnswered(job.kind, answer);
    switch (answer.outcome) {
      case AdminAnswerOutcome.started:
      case AdminAnswerOutcome.noAnswerYet:
      case AdminAnswerOutcome.outcomeUnknown:
        if (!job.following) {
          job.following = true;
          _advanceFollow();
        }
      case AdminAnswerOutcome.ended when answer.operation != null:
        _ended(job, answer.operation!);
      case AdminAnswerOutcome.rolledBack:
      case AdminAnswerOutcome.rollbackFailed:
      case AdminAnswerOutcome.buildsChanged:
      case AdminAnswerOutcome.noPrevious:
      case AdminAnswerOutcome.updateFailed:
        if (!alreadyFollowing ||
            answer.outcome == AdminAnswerOutcome.rolledBack) {
          _clearJob();
        }
        if (answer.outcome == AdminAnswerOutcome.buildsChanged ||
            answer.outcome == AdminAnswerOutcome.rolledBack) {
          _refreshStatus();
        }
      default:
        // A resend refusal says nothing about the original send's outcome.
        if (!alreadyFollowing) _clearJob();
    }
    _publish();
  }

  void _refreshStatus() =>
      ref.read(serverStaticDataStatusProvider.notifier).refresh();

  void _clearJob() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _job = null;
  }

  void _ended(_Job job, AdminOperationView operation) {
    _message = AdminJobEnded(job.kind, operation);
    _clearJob();
    if (operation.changedBuilds ||
        operation.outcome == SdeAdminOperationOutcome.buildsChanged) {
      _refreshStatus();
    }
  }

  void _unknown() {
    _message = const AdminJobUnknown();
    _clearJob();
    _publish();
  }

  Duration _remaining(_Job job) => _followLimit - (_elapsed() - job.pressedAt);

  void _advanceFollow() {
    _pollTimer?.cancel();
    _pollTimer = null;
    final job = _job;
    final client = _client;
    if (!_visible ||
        job == null ||
        !job.following ||
        client == null ||
        _operationRead != null) {
      return;
    }
    if (_remaining(job) <= Duration.zero) {
      _unknown();
      return;
    }
    final read = client.operation(job.id).settled;
    _operationRead = read;
    unawaited(
      read.then<void>((answer) => _operationAnswered(job, read, answer)),
    );
  }

  void _operationAnswered(
    _Job job,
    Future<RpcResult<AdminOperationAnswer>> read,
    RpcResult<AdminOperationAnswer> answer,
  ) {
    if (!identical(_operationRead, read)) return;
    _operationRead = null;
    if (!identical(_job, job)) {
      _advanceFollow();
      return;
    }
    if (answer case RpcAnswered(
      value: AdminOperationAnswer(
        state: AdminOperationReadState.ended,
        operation: final operation?,
      ),
    )) {
      _ended(job, operation);
      _publish();
      return;
    }
    final remaining = _remaining(job);
    if (remaining <= Duration.zero) {
      _unknown();
      return;
    }
    if (answer case RpcAnswered(:final value)) {
      switch (value.state) {
        case AdminOperationReadState.unknownOperation:
          final now = _elapsed();
          job.firstUnknown ??= now;
          job.noRecord = now - job.firstUnknown! >= _noRecordAfter;
        case AdminOperationReadState.waiting:
        case AdminOperationReadState.running:
          job.firstUnknown = null;
          job.noRecord = false;
        case AdminOperationReadState.ended:
        case AdminOperationReadState.operationReadBusy:
          break;
      }
    }
    _publish();
    if (_visible) {
      _pollTimer = _timer(
        remaining < _readInterval ? remaining : _readInterval,
        _advanceFollow,
      );
    }
  }

  /// Writes the desired setting using the latest known revision.
  void setAutoUpdate(bool value) {
    if (!_accepted || _client == null) return;
    _setting.write(
      value,
      authorityEpoch: _authorityEpoch,
      send: _sendSetting(),
    );
  }

  /// Resends the pending setting value, revision and write ID.
  void retryAutoUpdate() {
    if (!_accepted || _client == null) return;
    _setting.retry(authorityEpoch: _authorityEpoch, send: _sendSetting());
  }

  SendAutoUpdate _sendSetting() {
    final bearer = _bearer!;
    final client = _client!;
    return (value, revision, id) =>
        client.setAutoUpdate(bearer, value, revision, id);
  }
}

final class _Job {
  _Job(this.id, this.kind, this.pressedAt, this.expectedRevision);

  final String id;
  final SdeAdminOperationKind kind;
  final Duration pressedAt;
  final int? expectedRevision;
  int send = 0;
  bool sending = false;
  bool following = false;
  Duration? firstUnknown;
  bool noRecord = false;
}
