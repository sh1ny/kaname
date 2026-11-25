import 'package:kaname_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

import '../test_tools/serverpod_test_tools.dart';

const _id = '9235606b-0c12-4a66-a7cc-48ef3a7a1801';

void main() {
  withServerpod('Static-data admin authorization', (sessions, endpoints) {
    final admin = sessions.copyWith(
      authentication: AuthenticationOverride.authenticationInfo('1', {
        Scope.admin,
      }),
    );
    final member = sessions.copyWith(
      authentication: AuthenticationOverride.authenticationInfo('2', {}),
    );

    test('Scoped admin action', () async {
      final answer = await endpoints.staticDataAdmin.setAutoUpdate(
        admin,
        false,
        NoWrites(),
        _id,
      );
      expect(answer.outcome, AdminAnswerOutcome.settingConfirmed);
      expect(answer.autoUpdate, isFalse);
    });

    test('Anonymous, non-admin or former key holder', () async {
      final before = await endpoints.staticData.status(sessions);
      for (final caller in [sessions, member]) {
        expect(
          (await endpoints.staticDataAdmin.setAutoUpdate(
            caller,
            !before.autoUpdate,
            before.settingRevision,
            _id,
          )).outcome,
          AdminAnswerOutcome.notAuthorized,
        );
        await endpoints.staticData.status(caller);
      }
      expect(
        (await endpoints.staticData.status(sessions)).autoUpdate,
        before.autoUpdate,
      );
    });

    test('Unconfigured during start-up recovery', () async {
      expect(
        (await endpoints.staticData.operation(sessions, _id)).state,
        AdminOperationReadState.unknownOperation,
      );
    });
  });
}
