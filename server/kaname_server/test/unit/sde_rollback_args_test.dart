import 'package:kaname_server/src/static_data/sde_rollback_args.dart';
import 'package:test/test.dart';

void main() {
  group('parseSdeRollbackArgs', () {
    test('no arguments run the rollback', () {
      expect(parseSdeRollbackArgs([]), isA<SdeRollbackRun>());
    });

    test('help is its own result', () {
      expect(parseSdeRollbackArgs(['--help']), isA<SdeRollbackHelp>());
      expect(parseSdeRollbackArgs(['-h']), isA<SdeRollbackHelp>());
    });

    for (final (args, fragment) in [
      (['--nope'], 'unknown option --nope'),
      (['100'], 'takes no arguments'),
    ]) {
      test('$args is a usage error', () {
        final result = parseSdeRollbackArgs(args);

        expect(result, isA<SdeRollbackUsageError>());
        expect((result as SdeRollbackUsageError).message, contains(fragment));
      });
    }
  });
}
