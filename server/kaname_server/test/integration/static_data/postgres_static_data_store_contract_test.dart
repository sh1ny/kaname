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

    test('job store and control-plane tables cover the SDE schema', () {
      const controlPlane = {
        'sde_admin_operation',
        'sde_build_revision',
        'sde_setting_write',
      };
      final written = PostgresStaticDataStore.writtenTables.keys.toSet();
      final modelled = definitions.keys.where(
        (name) => name.startsWith('sde_'),
      );
      expect({...written, ...controlPlane}, unorderedEquals(modelled));
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
        final written = columns.map((column) => column.name).toList();
        expect(
          written,
          generated.values
              .where(
                (column) =>
                    written.contains(column.name) ||
                    (!column.isNullable && column.columnDefault == null),
              )
              .map((column) => column.name)
              .toList(),
          reason: 'written and required columns, in table order',
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
