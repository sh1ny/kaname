/// The resource bounds of an import.
library;

/// The caps and timeouts that keep an untrusted download and zip in check.
///
/// The defaults are the bounds of the `sde-import` design ("Resource
/// Bounds"). Tests pass tiny values to reach a bound without moving
/// gigabytes.
final class SdeLimits {
  /// Creates limits; every parameter defaults to the production bound.
  const SdeLimits({
    this.maxDownloadBytes = gibibyte,
    this.downloadTimeout = const Duration(minutes: 30),
    this.downloadIdleTimeout = const Duration(seconds: 60),
    this.maxEntryBytes = 4 * gibibyte,
    this.maxTotalBytes = 8 * gibibyte,
    this.maxLineBytes = 16 * mebibyte,
    this.importTimeout = const Duration(hours: 2),
  });

  /// One kibibyte-based mebibyte, in bytes.
  static const int mebibyte = 1024 * 1024;

  /// One gibibyte, in bytes.
  static const int gibibyte = 1024 * mebibyte;

  /// The most bytes a download may write to disk.
  final int maxDownloadBytes;

  /// The longest a whole download may take.
  final Duration downloadTimeout;

  /// The longest a download may go without receiving a byte.
  final Duration downloadIdleTimeout;

  /// The most bytes one zip entry may hold once unpacked.
  final int maxEntryBytes;

  /// The most bytes all unpacked entries of one zip may hold together.
  final int maxTotalBytes;

  /// The longest line, in bytes, that is parsed; a longer one is a bad record.
  final int maxLineBytes;

  /// The longest a whole import may take, from lock to commit.
  final Duration importTimeout;

  /// Describes [bytes] for a failure reason, for example `1 GiB` or `10 bytes`.
  ///
  /// Whole gibibytes and mebibytes read as such; anything else is in bytes.
  static String describeBytes(int bytes) {
    if (bytes >= gibibyte && bytes % gibibyte == 0) {
      return '${bytes ~/ gibibyte} GiB';
    }
    if (bytes >= mebibyte && bytes % mebibyte == 0) {
      return '${bytes ~/ mebibyte} MiB';
    }
    return '$bytes bytes';
  }

  /// Describes [duration] for a failure reason, for example `30 min`.
  static String describeDuration(Duration duration) {
    if (duration.inMilliseconds < 1000) {
      return '${duration.inMilliseconds} ms';
    }
    if (duration.inSeconds < 120) return '${duration.inSeconds} s';
    if (duration.inMinutes < 120) return '${duration.inMinutes} min';
    return '${duration.inHours} h';
  }
}
