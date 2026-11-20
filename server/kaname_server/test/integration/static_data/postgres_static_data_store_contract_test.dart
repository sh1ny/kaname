import 'package:kaname_server/src/generated/protocol.dart';
import 'package:kaname_server/src/static_data/postgres_static_data_store.dart';
import 'package:test/test.dart';

/// The name of the generated column type of each type the store writes.
const _expectedType = {
  StoredColumnType.bigint: 'bigint',
  StoredColumnType.text: 'text',
  StoredColumnType.boolean: 'boolean',
  StoredColumnType.doublePrecision: 'doublePrecision',
  StoredColumnType.timestamp: 'timestampWithoutTimeZone',
  StoredColumnType.jsonb: 'jsonb',
  StoredColumnType.bytea: 'bytea',
};

/// C4: the store writes tables that Serverpod migrations own with hand-written
/// SQL, so its columns must match the generated table definitions.
void main() {
  final definitions = {
    for (final table in Protocol().getTargetTableDefinitions())
      table.name: table,
  };

  group('Given the generated table definitions', () {
    test('when the store writes a table then the table exists', () {
      for (final table in PostgresStaticDataStore.writtenTables.keys) {
        expect(definitions, contains(table), reason: '$table is not migrated');
      }
    });

    test('when the models hold a static-data table then the store writes '
        'it', () {
      final modelled = {
        for (final name in definitions.keys)
          if (name.startsWith('sde_')) name,
      };
      expect(PostgresStaticDataStore.writtenTables.keys.toSet(), modelled);
    });

    for (final MapEntry(key: table, value: columns)
        in PostgresStaticDataStore.writtenTables.entries) {
      test('when $table is written then its columns and types match the '
          'definition', () {
        final definition = definitions[table]!;
        final generated = {
          for (final column in definition.columns)
            if (column.name != 'id') column.name: column,
        };
        expect(
          columns.map((column) => column.name).toList(),
          generated.keys.toList(),
          reason: 'columns written by the store, in table order',
        );
        for (final column in columns) {
          final expected = generated[column.name]!;
          expect(
            expected.columnType.name,
            _expectedType[column.type],
            reason: '$table.${column.name} type',
          );
          if (column.nullable) {
            expect(
              expected.isNullable,
              isTrue,
              reason:
                  '$table.${column.name} must accept the nulls the store '
                  'writes',
            );
          }
        }
      });
    }
  });
}
