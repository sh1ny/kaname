/// The job that repairs the active build's client data bundle.
library;

import 'package:kaname_core/kaname_core.dart';

import 'static_data_store.dart';
import 'stored_bundle.dart';
import 'zip_sde_archive.dart' show describeFailure;

/// How a bundle repair ended.
sealed class BundleRepairResult {
  const BundleRepairResult();
}

/// The repair ran its bundle step on the active build; [step] says whether
/// the bundle was already current, built or failed.
final class BundleRepairRan extends BundleRepairResult {
  /// Creates the result of [step].
  const BundleRepairRan(this.step);

  /// The bundle step's result, naming the active build.
  final BundleStepResult step;
}

/// Another import, check or repair held the static-data lock; the repair did
/// nothing.
final class BundleRepairLockHeld extends BundleRepairResult {
  /// Creates the result.
  const BundleRepairLockHeld();
}

/// No build is active, so there is no bundle to repair.
final class BundleRepairNoActiveBuild extends BundleRepairResult {
  /// Creates the result.
  const BundleRepairNoActiveBuild();
}

/// The repair stopped on an error before its bundle step.
final class BundleRepairFailed extends BundleRepairResult {
  /// Creates the result with [reason].
  const BundleRepairFailed(this.reason);

  /// Why the repair stopped; holds no credentials.
  final String reason;
}

/// Builds the active build's bundle when it is missing, failed, of another
/// format version (D20), or stored with bytes that do not match its size and
/// hash.
///
/// The job takes the static-data lock without waiting; when another job
/// holds it, it does nothing and returns [BundleRepairLockHeld] (C7). Under
/// the lock it finds the active build and runs [ensureBundle] on it with
/// `verifyBytes`, so a bundle the announcer refused for its bytes is built
/// again. It
/// releases the lock and closes the store whatever the outcome, and never
/// throws: every failure is a [BundleRepairFailed] or a [BundleFailed] step.
/// A job and its store are used once.
final class BundleRepairJob implements Job<BundleRepairResult> {
  /// Creates a repair that works through [store], building with
  /// [buildBundle] and timing the stored bundle with [clock].
  BundleRepairJob({
    required this.store,
    this.buildBundle = buildStoredBundle,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// The job's storage.
  final StaticDataStore store;

  /// Builds a stored build's bundle; [buildStoredBundle] in production.
  final BuildBundle buildBundle;

  final DateTime Function() _clock;

  @override
  String get name => 'bundle-repair';

  @override
  Future<BundleRepairResult> run() async {
    var locked = false;
    try {
      locked = await store.tryLock();
      if (!locked) return const BundleRepairLockHeld();
      int? active;
      for (final stored in await store.storedBuilds()) {
        if (stored.state == BuildState.active) active = stored.build;
      }
      if (active == null) return const BundleRepairNoActiveBuild();
      return BundleRepairRan(
        await ensureBundle(
          store,
          active,
          buildBundle: buildBundle,
          clock: _clock,
          verifyBytes: true,
        ),
      );
    } on Object catch (error) {
      return BundleRepairFailed('unexpected error: ${describeFailure(error)}');
    } finally {
      if (locked) await _quietly(store.unlock);
      await _quietly(store.close);
    }
  }

  static Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // Cleanup must not replace the repair's own outcome.
    }
  }
}
