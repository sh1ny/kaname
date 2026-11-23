import 'package:args/command_runner.dart';

import 'cli.dart';
import 'esi_fetch.dart';
import 'esi_generate.dart';
import 'esi_pin.dart';
import 'esi_render.dart';
import 'file_system.dart';

/// The `esi` command: the pinned ESI spec and the client generated from it.
final class EsiCommand extends Command<int> {
  /// Creates the command and its subcommands over [fileSystem], downloading
  /// with [downloader], checking in [scratch] and writing to [output].
  EsiCommand(
    FileSystem fileSystem,
    EsiDownloader downloader,
    EsiScratch scratch,
    CliOutput output,
  ) {
    addSubcommand(EsiFetchCommand(fileSystem, downloader, output));
    addSubcommand(EsiGenerateCommand(fileSystem, output));
    addSubcommand(EsiCheckCommand(fileSystem, scratch, output));
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

/// `esi generate`: write the typed client and the route catalogue from the
/// pinned snapshot alone. Every file is rendered in memory first; nothing
/// is written unless all of them render.
final class EsiGenerateCommand extends Command<int> {
  /// Creates the command.
  EsiGenerateCommand(this._fileSystem, this._output);

  final FileSystem _fileSystem;
  final CliOutput _output;

  @override
  String get name => 'generate';

  @override
  String get description =>
      'Generate the ESI client and route catalogue from the pinned snapshot.';

  @override
  int run() {
    switch (renderPinnedEsiClient(_fileSystem)) {
      case EsiGenerationRefused(:final problems):
        problems.forEach(_output.err.writeln);
        return exitCheckFailed;
      case EsiGenerationReady(:final pin, :final files):
        final (:written, :removed) = writeEsiGeneratedFiles(_fileSystem, files);
        _output.out.writeln(
          'ESI client: ${files.length} files for ${pin.date}, '
          '${written.length} written, ${removed.length} removed',
        );
        return exitSuccess;
    }
  }
}

/// `esi check`: fail when the committed generated output differs from what
/// the pinned snapshot generates, or when the snapshot does not match its
/// pin. Regenerates into a temporary directory; writes nothing in the
/// repository and needs no network.
final class EsiCheckCommand extends Command<int> {
  /// Creates the command.
  EsiCheckCommand(this._fileSystem, this._scratch, this._output);

  final FileSystem _fileSystem;
  final EsiScratch _scratch;
  final CliOutput _output;

  @override
  String get name => 'check';

  @override
  String get description =>
      'Fail if the generated ESI client differs from the pinned snapshot.';

  @override
  int run() {
    final (:pin, :files, :problems) = checkEsiGenerated(_fileSystem, _scratch);
    if (problems.isNotEmpty) {
      problems.forEach(_output.err.writeln);
      return exitCheckFailed;
    }
    _output.out.writeln('ESI client: $files files current for ${pin?.date}');
    return exitSuccess;
  }
}
