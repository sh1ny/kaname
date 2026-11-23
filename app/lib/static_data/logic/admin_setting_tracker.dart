import 'package:kaname_client/kaname_client.dart';

import '../data/rpc_call.dart';

/// Sends one attempt of an auto-update write.
typedef SendAutoUpdate = RpcCall<AdminAnswer> Function(
  bool value,
  SettingRevision expectedRevision,
  String writeId,
);

/// An immutable snapshot of the setting and its pending write.
final class AdminSettingView {
  /// Creates a snapshot of the setting.
  const AdminSettingView({
    required this.storedValue,
    required this.revision,
    required this.value,
    required this.saving,
    required this.notConfirmed,
    required this.canRetry,
    required this.notice,
  });

  /// Whether the latest known committed value enables auto-update.
  final bool storedValue;

  /// The greatest known committed revision.
  final SettingRevision revision;

  /// Whether the switch is displayed as enabled.
  final bool value;

  /// Whether the current attempt is awaiting its answer.
  final bool saving;

  /// Whether the pending write has an unknown outcome.
  final bool notConfirmed;

  /// Whether the pending write can be retried without overlapping transport.
  final bool canRetry;

  /// The most recent definite refusal or setting-changed outcome.
  final AdminAnswerOutcome? notice;
}

/// Tracks one auto-update write independently of the admin key session.
final class AdminSettingTracker {
  /// Creates a tracker with callbacks for changes and authentication refusals.
  AdminSettingTracker({
    required this._newId,
    required this._onChanged,
    required this._onRefusal,
  });

  final String Function() _newId;
  final void Function() _onChanged;
  final void Function(AdminAnswer, int) _onRefusal;
  SettingRevision? _revision;
  bool _storedValue = false;
  _SettingWrite? _pending;
  AdminAnswerOutcome? _notice;
  bool _disposed = false;

  /// The current snapshot, or `null` until a setting has been observed.
  AdminSettingView? get view {
    final revision = _revision;
    if (revision == null) return null;
    final pending = _pending;
    return AdminSettingView(
      storedValue: _storedValue,
      revision: revision.copyWith(),
      value: pending == null || pending.showStored
          ? _storedValue
          : pending.value,
      saving: pending?.saving ?? false,
      notConfirmed: pending?.uncertain ?? false,
      canRetry: pending != null && pending.uncertain && !pending.inFlight,
      notice: _notice,
    );
  }

  /// Incorporates a status observation without regressing the revision.
  void observe(bool value, SettingRevision revision) {
    if (_disposed) return;
    final previous = _revision;
    if (previous != null && _compare(revision, previous) < 0) return;
    _storedValue = value;
    _revision = revision.copyWith();
    final pending = _pending;
    if (pending != null) {
      if (_compare(revision, pending.revision) > 0) {
        _pending = null;
      } else if (pending.uncertain) {
        pending.showStored = true;
      }
    }
    _onChanged();
  }

  /// Starts a fresh write using the greatest known committed revision.
  void write(
    bool value, {
    required int keySession,
    required SendAutoUpdate send,
  }) {
    final revision = _revision;
    if (_disposed || revision == null || _pending != null) return;
    final pending = _SettingWrite(value, revision.copyWith(), _newId());
    _pending = pending;
    _notice = null;
    _send(pending, keySession, send, retry: false);
  }

  /// Resends the uncertain write without changing its identity or revision.
  void retry({required int keySession, required SendAutoUpdate send}) {
    final pending = _pending;
    if (_disposed ||
        pending == null ||
        !pending.uncertain ||
        pending.inFlight) {
      return;
    }
    _notice = null;
    _send(pending, keySession, send, retry: true);
  }

  void _send(
    _SettingWrite pending,
    int keySession,
    SendAutoUpdate send, {
    required bool retry,
  }) {
    pending.inFlight = true;
    pending.saving = true;
    _onChanged();
    if (_disposed) return;
    final call = send(pending.value, pending.revision.copyWith(), pending.id);
    var definitive = false;
    call.answer.then((result) {
      if (_disposed || definitive) return;
      if (result is RpcAnswered<AdminAnswer>) {
        definitive = true;
        _answer(pending, result.value, keySession, retry);
      } else if (identical(_pending, pending)) {
        pending.saving = false;
        pending.uncertain = true;
        _onChanged();
      }
    });
    call.settled.then((result) {
      if (_disposed) return;
      pending.inFlight = false;
      if (!definitive && result is RpcAnswered<AdminAnswer>) {
        definitive = true;
        _answer(pending, result.value, keySession, retry);
      } else if (identical(_pending, pending)) {
        _onChanged();
      }
    });
  }

  void _answer(
    _SettingWrite pending,
    AdminAnswer answer,
    int keySession,
    bool retry,
  ) {
    final outcome = answer.outcome;
    final revision = answer.settingRevision;
    final value = answer.autoUpdate;
    if ((outcome == AdminAnswerOutcome.settingConfirmed ||
            outcome == AdminAnswerOutcome.settingChanged) &&
        revision != null &&
        value != null &&
        (_revision == null || _compare(revision, _revision!) > 0)) {
      _revision = revision.copyWith();
      _storedValue = value;
    }
    if (!identical(_pending, pending)) {
      _onChanged();
      return;
    }
    pending.saving = false;
    if (outcome == AdminAnswerOutcome.settingConfirmed ||
        outcome == AdminAnswerOutcome.settingChanged) {
      _pending = null;
      _notice = outcome == AdminAnswerOutcome.settingChanged ? outcome : null;
    } else if (outcome == AdminAnswerOutcome.settingNotConfirmed) {
      pending.uncertain = true;
      _notice = null;
    } else {
      _notice = outcome;
      if (retry) {
        pending.uncertain = true;
      } else {
        _pending = null;
      }
      if (outcome == AdminAnswerOutcome.keyRejected ||
          outcome == AdminAnswerOutcome.tooManyAttempts ||
          outcome == AdminAnswerOutcome.notConfigured) {
        _onRefusal(answer, keySession);
        if (_disposed) return;
      }
    }
    _onChanged();
  }

  /// Stops all notifications and ignores outstanding answers.
  void dispose() {
    _disposed = true;
  }
}

int _compare(SettingRevision a, SettingRevision b) {
  return switch ((a, b)) {
    (NoWrites(), NoWrites()) => 0,
    (NoWrites(), WriteRevision()) => -1,
    (WriteRevision(), NoWrites()) => 1,
    (WriteRevision(:final id), WriteRevision(id: final other)) => id.compareTo(
      other,
    ),
  };
}

final class _SettingWrite {
  _SettingWrite(this.value, this.revision, this.id);

  final bool value;
  final SettingRevision revision;
  final String id;
  bool inFlight = false;
  bool saving = false;
  bool uncertain = false;
  bool showStored = false;
}
