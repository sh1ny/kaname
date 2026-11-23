import 'package:kaname_tools/kaname_tools.dart';
import 'package:test/test.dart';

import 'support/esi_fixtures.dart';
import 'support/harness.dart';
import 'support/in_memory_file_system.dart';

List<String> _generated(InMemoryFileSystem fs) => [
  for (final path in fs.filePaths)
    if (path.startsWith('$esiGeneratedDirectory/')) path,
];

void main() {
  test('pinned bytes accepted: every file is written', () async {
    final fs = esiRepository();
    final result = await runTool(fs, ['esi', 'generate']);
    expect(result.code, exitSuccess, reason: result.err);
    expect(result.err, isEmpty);
    expect(_generated(fs), [
      for (final name in [
        'catalogue.dart',
        'esi.dart',
        'gadgets_client.dart',
        'gadgets_models.dart',
        'pin.dart',
        'widgets_client.dart',
        'widgets_models.dart',
      ])
        '$esiGeneratedDirectory/$name',
    ]);
    expect(result.out, contains('7 files for $esiFixtureDate, 7 written'));
  });

  test('generate twice: the second run writes nothing', () async {
    final fs = esiRepository();
    await runTool(fs, ['esi', 'generate']);
    final first = {
      for (final path in _generated(fs)) path: fs.readAsString(path),
    };
    final writes = fs.writeCount;

    final again = await runTool(fs, ['esi', 'generate']);
    expect(again.code, exitSuccess, reason: again.err);
    expect(fs.writeCount, writes);
    expect({
      for (final path in _generated(fs)) path: fs.readAsString(path),
    }, first);
    expect(again.out, contains('0 written, 0 removed'));
  });

  test('a generated file the spec no longer yields is removed', () async {
    final fs = esiRepository()
      ..writeFile('$esiGeneratedDirectory/stale_client.dart', '// old')
      ..writeFile('$esiGeneratedDirectory/notes.txt', 'kept');
    final result = await runTool(fs, ['esi', 'generate']);
    expect(result.code, exitSuccess, reason: result.err);
    expect(fs.kindOf('$esiGeneratedDirectory/stale_client.dart'), isNull);
    expect(fs.readAsString('$esiGeneratedDirectory/notes.txt'), 'kept');
    expect(result.out, contains('1 removed'));
  });

  test('a snapshot that differs from its pin writes nothing', () async {
    final fs = esiRepository(snapshot: '${esiFixtureText()}\n');
    final writes = fs.writeCount;
    final result = await runTool(fs, ['esi', 'generate']);
    expect(result.code, exitCheckFailed);
    expect(result.err, contains("does not match the pin's hash"));
    expect(fs.writeCount, writes);
    expect(_generated(fs), isEmpty);
  });

  test('pin missing a field: names it and writes nothing', () async {
    final fs = esiRepository(
      pin: 'date: "$esiFixtureDate"\nsource: "$esiFixtureSource"\n',
    );
    final writes = fs.writeCount;
    final result = await runTool(fs, ['esi', 'generate']);
    expect(result.code, exitCheckFailed);
    expect(result.err, contains('$esiPinPath lacks its sha256'));
    expect(fs.writeCount, writes);
  });

  test('a name collision writes nothing and names both sources', () async {
    final text = esiFixtureText().replaceFirst(
      '"Empty": {',
      '"PriceIsk": {"type": "object"}, "Empty": {',
    );
    // Reach PriceIsk from the POST response so it is generated.
    final collides = text.replaceFirst(
      '"#/components/schemas/Empty"',
      '"#/components/schemas/PriceIsk"',
    );
    final fs = esiRepository(snapshot: collides);
    final writes = fs.writeCount;
    final result = await runTool(fs, ['esi', 'generate']);
    expect(result.code, exitCheckFailed);
    expect(result.err, contains('#/components/schemas/Price/oneOf/0'));
    expect(result.err, contains('#/components/schemas/PriceIsk'));
    expect(fs.writeCount, writes);
    expect(_generated(fs), isEmpty);
  });
}
