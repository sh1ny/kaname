import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
// The test factory and storage class are public only through `src`.
// ignore: implementation_imports
import 'package:flutter_secure_storage_windows/src/flutter_secure_storage_windows_ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:win32/win32.dart';

/// Windows regression tests for the patched secure-storage backend.
///
/// Every value is synthetic and every store lives in a fresh temporary
/// directory, so the user's keyring is never read or written. The process
/// exit cases run a child `flutter test` host, stop it at a publication
/// barrier, confirm through its process handle that it exited, and only then
/// reopen the store.
void main() {
  if (_childCase.isNotEmpty) {
    test(_childTestName, _runChild);
    return;
  }

  const options = {'useBackwardCompatibility': 'false'};

  group('Windows secure storage', skip: !Platform.isWindows, () {
    late Directory directory;
    late List<String> printed;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('kaname-dpapi-');
      addTearDown(() => directory.delete(recursive: true));
      printed = [];
      final previousPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
      addTearDown(() => debugPrint = previousPrint);
    });

    File committed() => File(p.join(directory.path, encryptedJsonFileName));
    File staged() => File('${committed().path}$stagedJsonFileSuffix');
    DpapiJsonFileMapStorage storage() =>
        DpapiJsonFileMapStorage.forTesting(directory: directory.path);

    test(
      'The default Windows facade reopens the complete credential set',
      () async {
        await storage().save(_initial, options);

        // `flutter test` does not run the generated Dart plugin registrant,
        // so register the package's own Windows class as the app's
        // registrant does. Only the support directory is replaced.
        final previousStorage = FlutterSecureStoragePlatform.instance;
        final previousPaths = PathProviderPlatform.instance;
        addTearDown(() {
          FlutterSecureStoragePlatform.instance = previousStorage;
          PathProviderPlatform.instance = previousPaths;
        });
        FlutterSecureStorageWindows.registerWith();
        // The facade picks options by target platform, which tests set to
        // Android. Select Windows so it sends the app's Windows options.
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        PathProviderPlatform.instance = _FixtureSupportPath(directory.path);
        const facade = FlutterSecureStorage();

        await facade.write(key: _writtenKey, value: _writtenValue);
        expect(await storage().load(options), _afterWrite);
        expect(await facade.read(key: _writtenKey), _writtenValue);

        await facade.delete(key: _deletedKey);
        expect(
          await storage().load(options),
          {..._afterWrite}..remove(_deletedKey),
        );
        expect(await facade.read(key: _deletedKey), isNull);
        expect(await facade.read(key: _installKey), _initial[_installKey]);
        expect(staged().existsSync(), isFalse);
        _expectNoSecret(printed.join('\n'));
      },
    );

    test('A partial staged file is never read and is replaced', () async {
      await storage().save(_initial, options);
      await staged().writeAsBytes(const [0x01, 0x02, 0x03]);
      final plugin = createFlutterSecureStorageWindows(
        MethodChannelFlutterSecureStorage(),
        storage(),
      );

      expect(await plugin.readAll(options: options), _initial);
      await plugin.write(
        key: _writtenKey,
        value: _writtenValue,
        options: options,
      );

      expect(await storage().load(options), _afterWrite);
      expect(staged().existsSync(), isFalse);
    });

    test('A complete staged file never supplies credentials', () async {
      // A complete staged map from an interrupted first write, with no
      // committed file.
      final source = await directory.createTemp('complete-');
      await DpapiJsonFileMapStorage.forTesting(directory: source.path)
          .save(_initial, options);
      await File(p.join(source.path, encryptedJsonFileName))
          .copy(staged().path);
      final plugin = createFlutterSecureStorageWindows(
        MethodChannelFlutterSecureStorage(),
        storage(),
      );

      expect(await plugin.readAll(options: options), isEmpty);
      expect(committed().existsSync(), isFalse);
      await plugin.write(
        key: _writtenKey,
        value: _writtenValue,
        options: options,
      );

      expect(await storage().load(options), {_writtenKey: _writtenValue});
      expect(staged().existsSync(), isFalse);
    });

    test(
      'A malformed decrypted credential file fails without exposing it',
      () async {
        for (final payload in [
          'not json $_sentinel',
          jsonEncode(['list-$_sentinel']),
          jsonEncode({_installKey: 5, _deletedKey: 'proof-$_sentinel'}),
        ]) {
          final bytes = _protect(utf8.encode(payload));
          await committed().writeAsBytes(bytes);
          final plugin = createFlutterSecureStorageWindows(
            MethodChannelFlutterSecureStorage(),
            storage(),
          );

          for (final operation in [
            () => plugin.readAll(options: options),
            () => plugin.write(
              key: _writtenKey,
              value: _writtenValue,
              options: options,
            ),
          ]) {
            Object? failure;
            try {
              await operation();
            } on Object catch (error) {
              failure = error;
            }
            expect(failure, isA<PlatformException>());
            _expectNoSecret('$failure\n${printed.join('\n')}');
            expect(await committed().readAsBytes(), bytes);
            expect(staged().existsSync(), isFalse);
          }
        }
      },
    );

    test('A failed replacement keeps the committed bytes', () async {
      await storage().save(_initial, options);
      final before = await committed().readAsBytes();
      final plugin = createFlutterSecureStorageWindows(
        MethodChannelFlutterSecureStorage(),
        storage(),
      );

      // A handle without delete sharing makes the replacement fail.
      final handle = using((alloc) {
        final Win32Result(value: handle, :error) = CreateFile(
          alloc.pcwstr(committed().path),
          GENERIC_READ,
          FILE_SHARE_READ,
          null,
          OPEN_EXISTING,
          FILE_ATTRIBUTE_NORMAL,
          null,
        );
        if (!handle.isValid) fail('Could not hold the committed file: $error');
        return handle;
      });
      Object? failure;
      try {
        await plugin.write(
          key: _writtenKey,
          value: _writtenValue,
          options: options,
        );
      } on Object catch (error) {
        failure = error;
      } finally {
        handle.close();
      }

      expect(failure, isA<PlatformException>());
      _expectNoSecret('$failure\n${printed.join('\n')}');
      expect(await committed().readAsBytes(), before);
      expect(staged().existsSync(), isFalse);
      expect(await storage().load(options), _initial);
    });

    for (final operation in _Operation.values) {
      test(
        'Interrupted Windows ${operation.name} preserves the old or new map',
        timeout: const Timeout(Duration(minutes: 20)),
        () async {
          for (final stage in _Stage.values) {
            final caseDirectory = await directory.createTemp(
              '${operation.name}-${stage.name}-',
            );
            await DpapiJsonFileMapStorage.forTesting(
              directory: caseDirectory.path,
            ).save(_initial, options);

            final exit = await _runChildToExit(
              operation: operation,
              stage: stage,
              directory: caseDirectory.path,
            );

            expect(exit.stage, stage.name);
            expect(exit.code, _childExitCode);
            _expectNoSecret(exit.output);
            final reopened = await DpapiJsonFileMapStorage.forTesting(
              directory: caseDirectory.path,
            ).load(options);
            expect(
              reopened,
              stage == _Stage.beforePublish ? _initial : operation.after,
              reason: '${operation.name} exited ${stage.name}',
            );
          }
        },
      );
    }
  });
}

const _installKey = 'kaname.install';
const _deletedKey = 'kaname.proof.a';
const _writtenKey = 'kaname.proof.b';
const _sentinel = 'SYNTHETIC-SECRET-7f3c';
const _writtenValue = 'proof-b-$_sentinel';
const _initial = {
  _installKey: 'install-$_sentinel',
  _deletedKey: 'proof-a-$_sentinel',
  'kaname.proof.c': 'proof-c-$_sentinel',
};
const _afterWrite = {..._initial, _writtenKey: _writtenValue};
const _childExitCode = 73;
const _childTestName = 'Windows secure storage child host';

const _childCase = String.fromEnvironment('KANAME_CRASH_CASE');
const _childPort = int.fromEnvironment('KANAME_CRASH_PORT');
const _childDirectory = String.fromEnvironment('KANAME_CRASH_DIR');

enum _Operation {
  write,
  delete;

  Map<String, String> get after => switch (this) {
    _Operation.write => _afterWrite,
    _Operation.delete => {..._initial}..remove(_deletedKey),
  };
}

enum _Stage { beforePublish, afterPublish }

/// Encrypts [plain] with DPAPI for the current user, as the backend does.
Uint8List _protect(List<int> plain) => using((alloc) {
  final input = alloc<Uint8>(plain.length);
  input.asTypedList(plain.length).setAll(0, plain);
  final inputBlob = alloc<CRYPT_INTEGER_BLOB>()
    ..ref.cbData = plain.length
    ..ref.pbData = input;
  final outputBlob = alloc<CRYPT_INTEGER_BLOB>();
  if (!CryptProtectData(inputBlob, null, null, null, 0, outputBlob).value) {
    fail('Could not protect the fixture.');
  }
  try {
    return Uint8List.fromList(
      outputBlob.ref.pbData.asTypedList(outputBlob.ref.cbData),
    );
  } finally {
    LocalFree(HLOCAL(outputBlob.ref.pbData.cast()));
  }
});

void _expectNoSecret(String text) {
  // Report a fixed failure; never print the text that leaked a value.
  expect(
    text.contains(_sentinel),
    isFalse,
    reason: 'A synthetic secret reached the output.',
  );
}

/// Runs in the child host: performs one mutation and exits at its barrier.
Future<void> _runChild() async {
  final [operationName, stageName] = _childCase.split(':');
  final operation = _Operation.values.byName(operationName);
  final stage = _Stage.values.byName(stageName);

  Future<void> barrier() async {
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      _childPort,
    );
    socket.writeln('$pid ${stage.name}');
    await socket.flush();
    await socket.cast<List<int>>().transform(utf8.decoder).first;
    // Exit without unwinding the save, as a killed process would.
    exit(_childExitCode);
  }

  final plugin = createFlutterSecureStorageWindows(
    MethodChannelFlutterSecureStorage(),
    DpapiJsonFileMapStorage.forTesting(
      directory: _childDirectory,
      beforePublish: stage == _Stage.beforePublish ? barrier : null,
      afterPublish: stage == _Stage.afterPublish ? barrier : null,
    ),
  );
  const options = {'useBackwardCompatibility': 'false'};
  switch (operation) {
    case _Operation.write:
      await plugin.write(
        key: _writtenKey,
        value: _writtenValue,
        options: options,
      );
    case _Operation.delete:
      await plugin.delete(key: _deletedKey, options: options);
  }
  fail('The mutation finished without reaching its barrier.');
}

typedef _ChildExit = ({String stage, int code, String output});

/// Starts the child host, holds its process handle and waits for its exit.
Future<_ChildExit> _runChildToExit({
  required _Operation operation,
  required _Stage stage,
  required String directory,
}) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final flutter = _flutterCommand();
  final process = await Process.start(
    flutter,
    [
      'test',
      '--no-pub',
      '--no-test-assets',
      '--plain-name',
      _childTestName,
      '--dart-define=KANAME_CRASH_CASE=${operation.name}:${stage.name}',
      '--dart-define=KANAME_CRASH_PORT=${server.port}',
      '--dart-define=KANAME_CRASH_DIR=$directory',
      p.join('test', 'esi_sso', 'windows_secure_storage_crash_test.dart'),
    ],
    workingDirectory: Directory.current.path,
    runInShell: true,
  );
  final output = StringBuffer();
  final drained = [
    process.stdout.transform(utf8.decoder).forEach(output.write),
    process.stderr.transform(utf8.decoder).forEach(output.write),
  ];

  // The parent owns the accepted socket and reaps the runner on every path.
  // Closing the socket ends a child that is still waiting at its barrier.
  Socket? socket;
  final ({String stage, int code}) observed;
  try {
    final accepted = await Future.any([
      server.first,
      process.exitCode.then<Socket>(
        (code) => throw StateError(
          'The child runner exited with $code before its barrier:\n$output',
        ),
      ),
    ]);
    socket = accepted;
    final lines = accepted
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    final [childPid, childStage] = (await lines.first).split(' ');

    final handle = OpenProcess(
      PROCESS_SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION,
      false,
      int.parse(childPid),
    ).value;
    if (!handle.isValid) {
      fail('Could not open the child host process.');
    }
    try {
      accepted.writeln('continue');
      await accepted.flush();
      final address = handle.address;
      final waited = await Isolate.run(
        () => WaitForSingleObject(
          HANDLE(Pointer.fromAddress(address)),
          INFINITE,
        ).value,
      );
      expect(waited, WAIT_OBJECT_0, reason: 'The child host did not exit.');
      final code = using((alloc) {
        final exitCode = alloc<Uint32>();
        if (!GetExitCodeProcess(handle, exitCode).value) {
          fail('Could not read the child host exit code.');
        }
        return exitCode.value;
      });
      observed = (stage: childStage, code: code);
    } finally {
      handle.close();
    }
  } finally {
    socket?.destroy();
    await server.close();
    await process.exitCode;
    await Future.wait(drained);
  }
  return (stage: observed.stage, code: observed.code, output: '$output');
}

/// The `flutter` command of the SDK that runs this test.
String _flutterCommand() {
  // flutter_tester.exe lives in <root>\bin\cache\artifacts\engine\<platform>.
  var root = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 5; i++) {
    root = root.parent;
  }
  final flutter = File(p.join(root.path, 'bin', 'flutter.bat'));
  if (!flutter.existsSync()) {
    fail('No Flutter command next to ${Platform.resolvedExecutable}.');
  }
  return flutter.path;
}

final class _FixtureSupportPath extends PathProviderPlatform {
  _FixtureSupportPath(this.path);

  final String path;

  @override
  Future<String> getApplicationSupportPath() async => path;
}
