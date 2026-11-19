import 'package:kaname_server/src/static_data/sde_import_args.dart';
import 'package:kaname_server/src/workers/worker_messages.dart';
import 'package:test/test.dart';

void main() {
  group('parseSdeImportArgs', () {
    test('a zip alone is a local import', () {
      final result = parseSdeImportArgs(['build.zip']);

      expect(result, isA<SdeImportRun>());
      final run = result as SdeImportRun;
      expect(run.source, isA<LocalZipSource>());
      expect((run.source as LocalZipSource).path, 'build.zip');
      expect(run.r38ReportPath, isNull);
    });

    test('--latest is CCP\'s newest build', () {
      final run = parseSdeImportArgs(['--latest']) as SdeImportRun;

      expect(run.source, isA<CcpLatestSource>());
    });

    test('--r38-report takes a path as the next argument or after "="', () {
      final spaced =
          parseSdeImportArgs(['a.zip', '--r38-report', 'r.md']) as SdeImportRun;
      final joined =
          parseSdeImportArgs(['--r38-report=r.md', '--latest']) as SdeImportRun;

      expect(spaced.r38ReportPath, 'r.md');
      expect(joined.r38ReportPath, 'r.md');
    });

    test('help is its own result', () {
      expect(parseSdeImportArgs(['--help']), isA<SdeImportHelp>());
      expect(parseSdeImportArgs(['-h', 'x']), isA<SdeImportHelp>());
    });

    for (final (args, fragment) in [
      (<String>[], 'name a zip'),
      (['a.zip', '--latest'], 'exclude each other'),
      (['a.zip', 'b.zip'], 'only one zip'),
      (['--latest', '--r38-report'], 'needs a path'),
      (['--latest', '--r38-report', '--latest'], 'needs a path'),
      (['--latest', '--r38-report='], 'needs a path'),
      (['--latest', '--r38-report', 'a', '--r38-report', 'b'], 'twice'),
      (['--nope'], 'unknown option --nope'),
    ]) {
      test('$args is a usage error', () {
        final result = parseSdeImportArgs(args);

        expect(result, isA<SdeImportUsageError>());
        expect((result as SdeImportUsageError).message, contains(fragment));
      });
    }
  });
}
