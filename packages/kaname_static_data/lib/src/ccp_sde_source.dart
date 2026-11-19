/// An SDE build downloaded from CCP's static data service.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'sde_limits.dart';
import 'sde_source.dart';
import 'zip_sde_archive.dart';

/// The address of CCP's tranquility static data service.
final Uri ccpStaticDataBaseUrl = Uri.parse(
  'https://developers.eveonline.com/static-data/tranquility/',
);

/// The most bytes read from `latest.jsonl`, which holds one short line.
const int _maxLatestBytes = 64 * 1024;

/// Downloads a build from CCP.
///
/// It reads `latest.jsonl` for the newest build number, then downloads
/// `eve-online-static-data-<build>-jsonl.zip` to a temporary directory of
/// this process, within the download limits: the byte cap on disk, the
/// overall time and the time without a byte. The directory is deleted when
/// the opened archive is closed, or at once when the download or the zip
/// fails. A killed process leaves it behind; the next import deletes every
/// directory with the [sdeScratchPrefix] once it holds the lock.
///
/// See [SdeSource] for what was verified about CCP's layout.
final class CcpSdeSource implements SdeSource {
  /// Creates a source that talks through [client].
  ///
  /// The caller owns [client] and closes it. [baseUrl] must end in a slash.
  CcpSdeSource({
    required this.client,
    Uri? baseUrl,
    this.limits = const SdeLimits(),
    Directory? scratchRoot,
  }) : baseUrl = baseUrl ?? ccpStaticDataBaseUrl,
       scratchRoot = scratchRoot ?? Directory.systemTemp;

  /// The HTTP client.
  final http.Client client;

  /// The service address.
  final Uri baseUrl;

  /// The download and unpacking caps.
  final SdeLimits limits;

  /// The directory that holds the temporary download directory.
  final Directory scratchRoot;

  Future<int>? _announced;

  @override
  SdeSourceKind get kind => SdeSourceKind.ccp;

  @override
  Future<int?> announcedBuild() => _announced ??= _readLatest();

  @override
  Future<SdeArchive> open() async {
    final build = await announcedBuild();
    final workDir = await scratchRoot.createTemp(sdeScratchPrefix);
    try {
      final zipFile = File(p.join(workDir.path, 'sde.zip'));
      await _download(
        baseUrl.resolve('eve-online-static-data-$build-jsonl.zip'),
        zipFile,
      );
      return await ZipSdeArchive.open(
        zipFile: zipFile,
        workDir: workDir,
        limits: limits,
        sourceName: 'CCP zip',
      );
    } on Object {
      // ZipSdeArchive.open deletes the directory itself; a failed download
      // has not reached it yet.
      try {
        if (workDir.existsSync()) await workDir.delete(recursive: true);
      } on FileSystemException {
        // Best effort.
      }
      rethrow;
    }
  }

  Future<int> _readLatest() async {
    final bytes = BytesBuilder(copy: false);
    await _fetch(baseUrl.resolve('latest.jsonl'), (chunk) {
      bytes.add(chunk);
      if (bytes.length > _maxLatestBytes) {
        throw const SdeSourceException('CCP latest.jsonl is too large');
      }
    }, maxBytes: _maxLatestBytes);
    try {
      final text = utf8.decode(bytes.takeBytes());
      for (final line in const LineSplitter().convert(text)) {
        if (line.trim().isEmpty) continue;
        if (jsonDecode(line) case {'buildNumber': final int build}) {
          return build;
        }
        break;
      }
    } on FormatException {
      // Falls through to the reason below.
    }
    throw const SdeSourceException(
      'CCP latest.jsonl does not hold a build number',
    );
  }

  Future<void> _download(Uri url, File target) async {
    final sink = target.openSync(mode: FileMode.write);
    var written = 0;
    try {
      final expected = await _fetch(url, (chunk) {
        written += chunk.length;
        if (written > limits.maxDownloadBytes) {
          throw SdeSourceException(
            'CCP download exceeds ${SdeLimits.describeBytes(limits.maxDownloadBytes)}',
          );
        }
        sink.writeFromSync(chunk);
      }, maxBytes: limits.maxDownloadBytes);
      if (expected != null && written != expected) {
        throw SdeSourceException(
          'CCP download cut off after $written of $expected bytes',
        );
      }
    } on FileSystemException catch (error) {
      throw SdeSourceException(
        'CCP download cannot be written: ${describeFailure(error)}',
      );
    } finally {
      sink.closeSync();
    }
  }

  /// Sends a GET for [url] and passes each body chunk to [onChunk].
  ///
  /// Returns the announced content length. Fails when the service cannot be
  /// reached, answers with an error status, announces more than [maxBytes],
  /// stalls, takes longer than the download timeout, or breaks off.
  Future<int?> _fetch(
    Uri url,
    void Function(List<int> chunk) onChunk, {
    required int maxBytes,
  }) async {
    final timer = Stopwatch()..start();
    final idle = limits.downloadIdleTimeout;
    final http.StreamedResponse response;
    try {
      response = await client.send(http.Request('GET', url)).timeout(idle);
    } on TimeoutException {
      throw SdeSourceException(
        'CCP unreachable: no answer in ${SdeLimits.describeDuration(idle)}',
      );
    } on Object catch (error) {
      throw SdeSourceException('CCP unreachable: ${describeFailure(error)}');
    }
    if (response.statusCode != 200) {
      throw SdeSourceException(
        'CCP answered ${response.statusCode} for ${url.pathSegments.last}',
      );
    }
    final expected = response.contentLength;
    if (expected != null && expected > maxBytes) {
      throw SdeSourceException(
        'CCP download exceeds ${SdeLimits.describeBytes(maxBytes)}',
      );
    }
    try {
      await for (final chunk in response.stream.timeout(idle)) {
        if (timer.elapsed > limits.downloadTimeout) {
          throw SdeSourceException(
            'CCP download exceeds '
            '${SdeLimits.describeDuration(limits.downloadTimeout)}',
          );
        }
        onChunk(chunk);
      }
    } on TimeoutException {
      throw SdeSourceException(
        'CCP download stalled: no bytes for ${SdeLimits.describeDuration(idle)}',
      );
    } on SdeSourceException {
      rethrow;
    } on Object catch (error) {
      if (error is FileSystemException) rethrow;
      throw SdeSourceException(
        'CCP download cut off: ${describeFailure(error)}',
      );
    }
    return expected;
  }
}
