/// The deliberate fetch of ESI's spec for a compatibility-date bump
/// (design D8 of `esi-client-generator`).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'esi_pin.dart';
import 'file_system.dart';

/// What one download produced.
sealed class EsiDownload {
  const EsiDownload();
}

/// The server answered.
final class EsiDownloaded extends EsiDownload {
  /// Creates an answer with [status] and the body [bytes].
  const EsiDownloaded(this.status, this.bytes);

  /// The HTTP status.
  final int status;

  /// The body as served.
  final Uint8List bytes;
}

/// No answer: the request failed, timed out or was too large.
final class EsiDownloadFailed extends EsiDownload {
  /// Creates a failure explained by [reason].
  const EsiDownloadFailed(this.reason);

  /// What went wrong.
  final String reason;
}

/// Downloads the spec. The fetch is the only project task that does.
abstract interface class EsiDownloader {
  /// Downloads [url], sending [headers].
  Future<EsiDownload> download(Uri url, Map<String, String> headers);
}

/// A downloader for runs without network access: every download fails.
final class NoEsiDownloader implements EsiDownloader {
  /// Creates the downloader.
  const NoEsiDownloader();

  @override
  Future<EsiDownload> download(Uri url, Map<String, String> headers) async =>
      const EsiDownloadFailed('this run has no network access');
}

/// A downloader over `dart:io`'s [HttpClient], with a time limit and a size
/// limit.
final class HttpEsiDownloader implements EsiDownloader {
  /// Creates a downloader that gives up after [timeout] or past [maxBytes].
  const HttpEsiDownloader({
    this.timeout = const Duration(seconds: 60),
    this.maxBytes = 16 * 1024 * 1024,
  });

  /// The limit on the whole download.
  final Duration timeout;

  /// The largest body accepted.
  final int maxBytes;

  @override
  Future<EsiDownload> download(Uri url, Map<String, String> headers) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      return await _download(client, url, headers).timeout(timeout);
    } on TimeoutException {
      final limit = timeout.inMilliseconds % 1000 == 0
          ? '${timeout.inSeconds} s'
          : '${timeout.inMilliseconds} ms';
      return EsiDownloadFailed('timed out after $limit');
    } on IOException catch (e) {
      return EsiDownloadFailed('$e');
    } finally {
      client.close(force: true);
    }
  }

  Future<EsiDownload> _download(
    HttpClient client,
    Uri url,
    Map<String, String> headers,
  ) async {
    final request = await client.getUrl(url);
    headers.forEach(request.headers.set);
    final response = await request.close();
    final body = BytesBuilder(copy: false);
    await for (final chunk in response) {
      body.add(chunk);
      if (body.length > maxBytes) {
        return EsiDownloadFailed('the body is larger than $maxBytes bytes');
      }
    }
    return EsiDownloaded(response.statusCode, body.takeBytes());
  }
}

/// The points of a fetch a test can step in between.
enum EsiFetchStep {
  /// The snapshot was renamed into place; the pin is not yet written.
  snapshotInPlace,
}

/// The outcome of [EsiFetcher.fetch].
sealed class EsiFetchResult {
  const EsiFetchResult();
}

/// The snapshot and the pin were written and re-read as a matching pair.
final class EsiFetched extends EsiFetchResult {
  /// Creates the result for [pin].
  const EsiFetched(this.pin);

  /// The pin written.
  final EsiPin pin;
}

/// The fetch failed; [wroteFiles] says whether it got as far as writing.
final class EsiFetchFailed extends EsiFetchResult {
  /// Creates a failure.
  const EsiFetchFailed(this.problems, {this.wroteFiles = false});

  /// What went wrong.
  final List<String> problems;

  /// Whether the snapshot or the pin was replaced before the failure.
  final bool wroteFiles;
}

/// The source URL of ESI's spec for [date].
Uri esiSpecUrl(String date) => Uri.https(
  'esi.evetech.net',
  '/meta/openapi.json',
  {'compatibility_date': date},
);

/// Downloads ESI's spec for a date and replaces the snapshot and the pin.
///
/// The spec must report the requested date in both `info.version` and its
/// `X-Compatibility-Date` enum. Each file is written to its own uniquely
/// named temporary file and renamed into place, the snapshot first and the
/// pin last; then both are re-read from disk and their hashes compared. A
/// passing re-read does not guard against a later write: another fetch in
/// the same checkout can still replace either file afterwards, which the
/// check task then reports.
final class EsiFetcher {
  /// Creates a fetcher.
  ///
  /// [uniqueToken] names temporary files; [onStep] lets tests interleave two
  /// fetches deterministically.
  EsiFetcher(
    this._fileSystem,
    this._downloader, {
    String Function()? uniqueToken,
    Future<void> Function(EsiFetchStep step)? onStep,
  }) : _uniqueToken = uniqueToken ?? _randomToken,
       _onStep = onStep;

  final FileSystem _fileSystem;
  final EsiDownloader _downloader;
  final String Function() _uniqueToken;
  final Future<void> Function(EsiFetchStep step)? _onStep;

  static final Random _random = Random.secure();

  static String _randomToken() =>
      '$pid-${DateTime.now().microsecondsSinceEpoch}-'
      '${_random.nextInt(1 << 32).toRadixString(16)}';

  /// Fetches the spec for [date], which must be `YYYY-MM-DD`.
  Future<EsiFetchResult> fetch(String date) async {
    final url = esiSpecUrl(date);
    final String text;
    switch (await _downloader.download(url, {'X-Compatibility-Date': date})) {
      case EsiDownloadFailed(:final reason):
        return EsiFetchFailed(['download of $url failed: $reason']);
      case EsiDownloaded(:final status) when status != 200:
        return EsiFetchFailed(['download of $url returned HTTP $status']);
      case EsiDownloaded(:final bytes):
        try {
          text = utf8.decode(bytes);
        } on FormatException {
          return EsiFetchFailed(['the spec from $url is not UTF-8']);
        }
    }
    if (text.startsWith('﻿') || text.contains('\r')) {
      return EsiFetchFailed([
        'the spec from $url has a byte order mark or CR line endings, which '
            'the repository would rewrite; its hash would no longer match',
      ]);
    }
    final Object? document;
    try {
      document = jsonDecode(text);
    } on FormatException catch (e) {
      return EsiFetchFailed(['the spec from $url is not JSON: ${e.message}']);
    }
    final dateProblems = esiDateProblems(document, date, what: 'The requested');
    if (dateProblems.isNotEmpty) return EsiFetchFailed(dateProblems);

    final pin = EsiPin(
      date: date,
      source: url.toString(),
      sha256: esiSha256(text),
    );
    try {
      _replace(esiSnapshotPath, text);
      await _onStep?.call(EsiFetchStep.snapshotInPlace);
      _replace(esiPinPath, pin.render());
    } on FileSystemException catch (e) {
      return EsiFetchFailed(['writing failed: $e'], wroteFiles: true);
    }

    return switch (loadEsiSnapshot(_fileSystem)) {
      EsiSnapshotLoaded() => EsiFetched(pin),
      EsiSnapshotRefused(:final problems) => EsiFetchFailed([
        'the re-read after writing failed; another write may have replaced '
            'a file, so rerun the fetch:',
        ...problems,
      ], wroteFiles: true),
    };
  }

  /// Writes [content] to a unique temporary file beside [path] and renames
  /// it into place, deleting the temporary file if the rename fails.
  void _replace(String path, String content) {
    final slash = path.lastIndexOf('/');
    final temporary =
        '${path.substring(0, slash + 1)}.${path.substring(slash + 1)}.'
        '${_uniqueToken()}.tmp';
    _fileSystem.writeAsString(temporary, content);
    try {
      _fileSystem.rename(temporary, path);
    } on FileSystemException {
      try {
        _fileSystem.delete(temporary);
      } on FileSystemException {
        // The rename's failure is the one to report.
      }
      rethrow;
    }
  }
}
