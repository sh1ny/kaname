import 'dart:collection';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../generated/static_data/admin_key_result.dart';
import '../workers/worker_messages.dart';
import '../workers/worker_supervisor.dart';

/// Validates the configured key and enforces the global D6 pause.
///
/// Only a digest is retained. Logs describe decisions, never submitted or
/// configured keys (C7).
final class AdminGate {
  /// Reports missing or short configuration once, before serving requests.
  AdminGate({required String? key, required this.log, DateTime Function()? now})
    : _now = now ?? DateTime.now {
    if (key == null) {
      log(WorkerLogLevel.info, 'static data: admin key not configured');
    } else if (key.runes.length < 32) {
      log(WorkerLogLevel.warning, 'static data: admin key shorter than 32');
    } else {
      _expected = _digest(key);
    }
  }

  static const _window = Duration(seconds: 60);
  static const _maxRejections = 10;

  /// Receives credential-free gate decisions.
  final WorkerLogSink log;
  final DateTime Function() _now;
  final Queue<DateTime> _rejected = Queue();
  List<int>? _expected;
  DateTime? _pausedUntil;

  /// Whether the server has a usable key. A pause does not change this.
  bool get configured => _expected != null;

  /// When a `tooManyAttempts` answer permits the next key check.
  DateTime? get pausedUntil => _pausedUntil;

  /// Answers the configured, paused and key checks in that order.
  AdminKeyResult check(String supplied) {
    final expected = _expected;
    if (expected == null) return AdminKeyResult.notConfigured;
    final now = _now();
    if (_pausedUntil case final until?) {
      if (now.isBefore(until)) return AdminKeyResult.tooManyAttempts;
      _pausedUntil = null;
    }

    final given = _digest(supplied);
    var difference = 0;
    for (var index = 0; index < expected.length; index++) {
      difference |= expected[index] ^ given[index];
    }
    if (difference == 0) return AdminKeyResult.accepted;

    final cutoff = now.subtract(_window);
    while (_rejected.isNotEmpty && _rejected.first.isBefore(cutoff)) {
      _rejected.removeFirst();
    }
    _rejected.addLast(now);
    log(WorkerLogLevel.warning, 'static data: admin key rejected');
    if (_rejected.length == _maxRejections) {
      _pausedUntil = now.add(_window);
      _rejected.clear();
      log(WorkerLogLevel.warning, 'static data: admin actions paused for 60 s');
      return AdminKeyResult.tooManyAttempts;
    }
    return AdminKeyResult.rejected;
  }

  // Hash exact code units, not UTF-8's replacement of lone surrogates. Both
  // encodings are local to this process. Only the public input length affects
  // comparison time; the configured digest always has 32 bytes.
  static List<int> _digest(String key) => sha256
      .convert(Uint16List.fromList(key.codeUnits).buffer.asUint8List())
      .bytes;
}
