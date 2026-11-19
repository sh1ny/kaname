/// Where an import reads one SDE build from.
library;

/// The name prefix of every temporary directory a source creates.
///
/// A killed process leaves its directory behind (the download and the
/// unpacked entry), so the import job removes the directories with this
/// prefix from its per-database scratch root once it holds the static-data
/// lock, when no other import of that database can be running. Sources get
/// that root from the caller (the system temp directory when none is given)
/// and create the root if it is missing. Nothing else may use the prefix.
const String sdeScratchPrefix = 'kaname_sde_import_';

/// Where a build came from; recorded on the import record.
enum SdeSourceKind {
  /// Downloaded from CCP's static data service.
  ccp,

  /// Read from a zip file on this machine.
  local,
}

/// Why a source could not hand over a build.
///
/// The [reason] is written to the import record, so it names the source and
/// the cause and holds no credential or local path.
final class SdeSourceException implements Exception {
  /// Creates the exception with [reason].
  const SdeSourceException(this.reason);

  /// The recordable reason.
  final String reason;

  @override
  String toString() => 'SdeSourceException: $reason';
}

/// One line of a JSON Lines file, or the reason it cannot be read.
sealed class SdeLine {
  /// Creates a line at [number], counted from 1 in its file.
  const SdeLine(this.number);

  /// The 1-based line number in the file.
  final int number;
}

/// A line of text that is ready to be parsed as JSON.
final class SdeTextLine extends SdeLine {
  /// Creates a text line.
  const SdeTextLine(super.number, this.text);

  /// The line without its line break.
  final String text;
}

/// A line that cannot be parsed at all, such as one over the line cap.
final class SdeUnreadableLine extends SdeLine {
  /// Creates an unreadable line with the [reason] it is skipped.
  const SdeUnreadableLine(super.number, this.reason);

  /// Why the line is skipped.
  final String reason;
}

/// One opened SDE build: a set of JSON Lines files.
///
/// A file is read as a stream of lines, one entry at a time. Close the
/// archive to free what it holds on disk, whatever the outcome.
abstract interface class SdeArchive {
  /// The names of the build's `.jsonl` files, for example `types.jsonl`,
  /// sorted. Directories and other kinds of entry are not listed.
  List<String> get fileNames;

  /// Reads the lines of [fileName], which must be in [fileNames].
  ///
  /// Blank lines are skipped but still counted. Throws an
  /// [SdeSourceException] from the stream when the entry cannot be unpacked
  /// within the limits or is corrupt.
  Stream<SdeLine> lines(String fileName);

  /// Releases the archive and deletes every temporary file it owns.
  Future<void> close();
}

/// One place an SDE build can be read from.
///
/// ## Findings behind the implementations
///
/// - **A4 (checked against `archive` 4.7.1's documentation and source):**
///   `ZipDecoder.decodeStream` over an `InputFileStream` reads the zip's
///   central directory only; entries are not loaded. But an entry unpacks
///   into an `OutputStream`, never into a line stream, so the reader takes
///   the design's fallback: each entry is unpacked on demand into the
///   source's temporary directory, through an output stream that stops at the
///   entry cap, and read from there line by line. The unpacked file is
///   deleted as soon as its lines are consumed.
/// - **A4, `package:postgres` 3.x:** `Session.execute` takes positional
///   (`$1`) and named parameters, so a multi-row `INSERT ... VALUES (...),
///   (...)` with one flat parameter list works, and `runTx` commits when its
///   callback completes and rolls back when it throws. Postgres allows 65535
///   parameters per statement, far above 500 rows of the widest table.
/// - **A9 (checked against build 3714173):** the zip holds `_sde.jsonl`
///   with one record `{"_key": "sde", "buildNumber": 3714173,
///   "releaseDate": "..."}`, the same record as the `sde` entry of
///   `https://developers.eveonline.com/static-data/tranquility/latest.jsonl`.
///   The build number is its `buildNumber` field, an integer. The zip is
///   `eve-online-static-data-<build>-jsonl.zip` next to `latest.jsonl`.
abstract interface class SdeSource {
  /// Where this source's builds come from.
  SdeSourceKind get kind;

  /// The build number the source announces before any download, or `null`
  /// when only the build itself holds it.
  ///
  /// Throws an [SdeSourceException] when the announcement cannot be read.
  Future<int?> announcedBuild();

  /// Opens the build for reading, downloading it first when needed.
  ///
  /// Throws an [SdeSourceException] when the build cannot be fetched or is
  /// not a readable zip. The caller must close the result.
  Future<SdeArchive> open();
}
