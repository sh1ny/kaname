import 'package:kaname_server/src/static_data/sde_diff_args.dart';
import 'package:test/test.dart';

void main() {
  group('parseSdeDiffArgs', () {
    test('two build numbers are the pair to compare', () {
      final result = parseSdeDiffArgs(['100', '101']);

      expect(result, isA<SdeDiffRun>());
      final run = result as SdeDiffRun;
      expect((run.fromBuild, run.toBuild), (100, 101));
    });

    test('help is its own result', () {
      expect(parseSdeDiffArgs(['--help']), isA<SdeDiffHelp>());
      expect(parseSdeDiffArgs(['-h', 'x']), isA<SdeDiffHelp>());
    });

    for (final (args, fragment) in [
      (<String>[], 'name two builds'),
      (['100'], 'name two builds'),
      (['100', '101', '102'], 'name two builds'),
      (['100', 'abc'], 'not a build number'),
      (['0', '101'], 'not a build number'),
      (['-5', '101'], 'unknown option -5'),
      (['--nope', '1'], 'unknown option --nope'),
    ]) {
      test('$args is a usage error', () {
        final result = parseSdeDiffArgs(args);

        expect(result, isA<SdeDiffUsageError>());
        expect((result as SdeDiffUsageError).message, contains(fragment));
      });
    }
  });
}
