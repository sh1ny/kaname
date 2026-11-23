import 'package:args/command_runner.dart';

import 'cli.dart';
import 'esi_fetch.dart';
import 'esi_pin.dart';
import 'file_system.dart';

/// The `esi` command: the pinned ESI spec and the client generated from it.
final class EsiCommand extends Command<int> {
  /// Creates the command and its subcommands over [fileSystem], downloading
  /// with [downloader] and writing to [output].
  EsiCommand(
    FileSystem fileSystem,
    EsiDownloader downloader,
    CliOutput output,
  ) {
    addSubcommand(EsiFetchCommand(fileSystem, downloader, output));
  }

  @override
  String get name => 'esi';

  @override
  String get description =>
      'Fetch the pinned ESI spec, generate the client from it, or check it.';
}

/// `esi fetch --date YYYY-MM-DD`: download ESI's spec for a date and replace
/// the snapshot and the pin. The only task that downloads the spec; no CI
/// job runs it.
final class EsiFetchCommand extends Command<int> {
  /// Creates the command.
  EsiFetchCommand(this._fileSystem, this._downloader, this._output) {
    argParser.addOption(
      'date',
      help: 'The compatibility date to fetch, as YYYY-MM-DD.',
      valueHelp: 'YYYY-MM-DD',
    );
  }

  final FileSystem _fileSystem;
  final EsiDownloader _downloader;
  final CliOutput _output;

  @override
  String get name => 'fetch';

  @override
  String get description =>
      "Download ESI's spec for --date and replace the snapshot and the pin.";

  @override
  Future<int> run() async {
    final date = argResults!.option('date');
    if (date == null || !isEsiDate(date)) {
      usageException('Pass --date as YYYY-MM-DD.');
    }
    switch (await EsiFetcher(_fileSystem, _downloader).fetch(date)) {
      case EsiFetched(:final pin):
        _output.out
          ..writeln('$esiSnapshotPath fetched for ${pin.date}')
          ..writeln('$esiPinPath records sha256 ${pin.sha256}');
        return exitSuccess;
      case EsiFetchFailed(:final problems):
        problems.forEach(_output.err.writeln);
        return exitCheckFailed;
    }
  }
}
