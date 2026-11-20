/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_type_check

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:kaname_core/kaname_core.dart' as _idp9h2tz;
import 'package:serverpod/protocol.dart' as _isp;
import 'package:serverpod/serverpod.dart' as _is;

import 'health/dependency_status.dart' as _iztepymd;
import 'health/health_report.dart' as _if75m2mz;
import 'static_data/sde_build.dart' as _iqvvlz0n;
import 'static_data/sde_build_diff.dart' as _i6rvvlmq;
import 'static_data/sde_build_diff_outcome.dart' as _iby3hddy;
import 'static_data/sde_build_state.dart' as _isyk7irp;
import 'static_data/sde_bundle.dart' as _ijqwsv4v;
import 'static_data/sde_bundle_bytes.dart' as _imonpi0j;
import 'static_data/sde_bundle_outcome.dart' as _iquqzrxf;
import 'static_data/sde_check.dart' as _ig50l1bg;
import 'static_data/sde_check_outcome.dart' as _illgk9kj;
import 'static_data/sde_import.dart' as _iucgsa1v;
import 'static_data/sde_import_outcome.dart' as _is3f4xcr;
import 'static_data/sde_import_source.dart' as _ice2slzs;
import 'static_data/sde_record.dart' as _i9m0mwcw;
import 'static_data/sde_switch.dart' as _itdhfbzo;
import 'static_data/sde_switch_kind.dart' as _iqktcwf1;
import 'static_data/sde_switch_outcome.dart' as _icb88h1v;
import 'static_data/tables/sde_category.dart' as _ia9vf0pu;
import 'static_data/tables/sde_constellation.dart' as _i99obepy;
import 'static_data/tables/sde_dogma_attribute.dart' as _ighsxk4r;
import 'static_data/tables/sde_dogma_attribute_category.dart' as _ij6v2kiw;
import 'static_data/tables/sde_dogma_effect.dart' as _ixeydgad;
import 'static_data/tables/sde_dogma_unit.dart' as _iybgpetd;
import 'static_data/tables/sde_group.dart' as _iwdgrmzb;
import 'static_data/tables/sde_market_group.dart' as _izn7xnfb;
import 'static_data/tables/sde_meta_group.dart' as _i3etkb2u;
import 'static_data/tables/sde_region.dart' as _ioiqjh1t;
import 'static_data/tables/sde_solar_system.dart' as _iataywh8;
import 'static_data/tables/sde_type.dart' as _i19vm38w;
import 'static_data/tables/sde_type_dogma.dart' as _ib14m8bx;
export 'health/dependency_status.dart';
export 'health/health_report.dart';
export 'static_data/sde_build.dart';
export 'static_data/sde_build_diff.dart';
export 'static_data/sde_build_diff_outcome.dart';
export 'static_data/sde_build_state.dart';
export 'static_data/sde_bundle.dart';
export 'static_data/sde_bundle_bytes.dart';
export 'static_data/sde_bundle_outcome.dart';
export 'static_data/sde_check.dart';
export 'static_data/sde_check_outcome.dart';
export 'static_data/sde_import.dart';
export 'static_data/sde_import_outcome.dart';
export 'static_data/sde_import_source.dart';
export 'static_data/sde_record.dart';
export 'static_data/sde_switch.dart';
export 'static_data/sde_switch_kind.dart';
export 'static_data/sde_switch_outcome.dart';
export 'static_data/tables/sde_category.dart';
export 'static_data/tables/sde_constellation.dart';
export 'static_data/tables/sde_dogma_attribute.dart';
export 'static_data/tables/sde_dogma_attribute_category.dart';
export 'static_data/tables/sde_dogma_effect.dart';
export 'static_data/tables/sde_dogma_unit.dart';
export 'static_data/tables/sde_group.dart';
export 'static_data/tables/sde_market_group.dart';
export 'static_data/tables/sde_meta_group.dart';
export 'static_data/tables/sde_region.dart';
export 'static_data/tables/sde_solar_system.dart';
export 'static_data/tables/sde_type.dart';
export 'static_data/tables/sde_type_dogma.dart';

class Protocol extends _is.DatabaseSerializationManager
    implements _is.DatabaseProtocolDeserializationProvider {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  @override
  _is.ProtocolDeserialization get deserializationMetadata =>
      _is.ProtocolDeserialization.cached(
        this,
        types: const [
          _is.getType<_iztepymd.DependencyStatus>,
          _is.getType<_if75m2mz.HealthReport>,
          _is.getType<_iqvvlz0n.SdeBuild>,
          _is.getType<_i6rvvlmq.SdeBuildDiff>,
          _is.getType<_iby3hddy.SdeBuildDiffOutcome>,
          _is.getType<_isyk7irp.SdeBuildState>,
          _is.getType<_ijqwsv4v.SdeBundle>,
          _is.getType<_imonpi0j.SdeBundleBytes>,
          _is.getType<_iquqzrxf.SdeBundleOutcome>,
          _is.getType<_ig50l1bg.SdeCheck>,
          _is.getType<_illgk9kj.SdeCheckOutcome>,
          _is.getType<_iucgsa1v.SdeImport>,
          _is.getType<_is3f4xcr.SdeImportOutcome>,
          _is.getType<_ice2slzs.SdeImportSource>,
          _is.getType<_i9m0mwcw.SdeRecord>,
          _is.getType<_itdhfbzo.SdeSwitch>,
          _is.getType<_iqktcwf1.SdeSwitchKind>,
          _is.getType<_icb88h1v.SdeSwitchOutcome>,
          _is.getType<_ia9vf0pu.SdeCategory>,
          _is.getType<_i99obepy.SdeConstellation>,
          _is.getType<_ighsxk4r.SdeDogmaAttribute>,
          _is.getType<_ij6v2kiw.SdeDogmaAttributeCategory>,
          _is.getType<_ixeydgad.SdeDogmaEffect>,
          _is.getType<_iybgpetd.SdeDogmaUnit>,
          _is.getType<_iwdgrmzb.SdeGroup>,
          _is.getType<_izn7xnfb.SdeMarketGroup>,
          _is.getType<_i3etkb2u.SdeMetaGroup>,
          _is.getType<_ioiqjh1t.SdeRegion>,
          _is.getType<_iataywh8.SdeSolarSystem>,
          _is.getType<_i19vm38w.SdeType>,
          _is.getType<_ib14m8bx.SdeTypeDogma>,
          _is.getType<_iztepymd.DependencyStatus?>,
          _is.getType<_if75m2mz.HealthReport?>,
          _is.getType<_iqvvlz0n.SdeBuild?>,
          _is.getType<_i6rvvlmq.SdeBuildDiff?>,
          _is.getType<_iby3hddy.SdeBuildDiffOutcome?>,
          _is.getType<_isyk7irp.SdeBuildState?>,
          _is.getType<_ijqwsv4v.SdeBundle?>,
          _is.getType<_imonpi0j.SdeBundleBytes?>,
          _is.getType<_iquqzrxf.SdeBundleOutcome?>,
          _is.getType<_ig50l1bg.SdeCheck?>,
          _is.getType<_illgk9kj.SdeCheckOutcome?>,
          _is.getType<_iucgsa1v.SdeImport?>,
          _is.getType<_is3f4xcr.SdeImportOutcome?>,
          _is.getType<_ice2slzs.SdeImportSource?>,
          _is.getType<_i9m0mwcw.SdeRecord?>,
          _is.getType<_itdhfbzo.SdeSwitch?>,
          _is.getType<_iqktcwf1.SdeSwitchKind?>,
          _is.getType<_icb88h1v.SdeSwitchOutcome?>,
          _is.getType<_ia9vf0pu.SdeCategory?>,
          _is.getType<_i99obepy.SdeConstellation?>,
          _is.getType<_ighsxk4r.SdeDogmaAttribute?>,
          _is.getType<_ij6v2kiw.SdeDogmaAttributeCategory?>,
          _is.getType<_ixeydgad.SdeDogmaEffect?>,
          _is.getType<_iybgpetd.SdeDogmaUnit?>,
          _is.getType<_iwdgrmzb.SdeGroup?>,
          _is.getType<_izn7xnfb.SdeMarketGroup?>,
          _is.getType<_i3etkb2u.SdeMetaGroup?>,
          _is.getType<_ioiqjh1t.SdeRegion?>,
          _is.getType<_iataywh8.SdeSolarSystem?>,
          _is.getType<_i19vm38w.SdeType?>,
          _is.getType<_ib14m8bx.SdeTypeDogma?>,
          _is.getType<_idp9h2tz.SdeJson?>,
          _is.getType<_idp9h2tz.SdeJson>,
          _is.getType<_idp9h2tz.SdeJson?>,
        ],
        modules: const [_isp.Protocol.new],
        classNames: const [
          'SdeJson',
          'DependencyStatus',
          'HealthReport',
          'SdeBuild',
          'SdeBuildDiff',
          'SdeBuildDiffOutcome',
          'SdeBuildState',
          'SdeBundle',
          'SdeBundleBytes',
          'SdeBundleOutcome',
          'SdeCheck',
          'SdeCheckOutcome',
          'SdeImport',
          'SdeImportOutcome',
          'SdeImportSource',
          'SdeRecord',
          'SdeSwitch',
          'SdeSwitchKind',
          'SdeSwitchOutcome',
          'SdeCategory',
          'SdeConstellation',
          'SdeDogmaAttribute',
          'SdeDogmaAttributeCategory',
          'SdeDogmaEffect',
          'SdeDogmaUnit',
          'SdeGroup',
          'SdeMarketGroup',
          'SdeMetaGroup',
          'SdeRegion',
          'SdeSolarSystem',
          'SdeType',
          'SdeTypeDogma',
        ],
      );

  static List<_isp.TableDefinition> get targetTableDefinitions => [
    ..._ownTableDefinitions,
    ..._isp.Protocol.targetTableDefinitions,
  ];

  static List<_isp.TableDefinition> get _ownTableDefinitions => [
    _isp.TableDefinition(
      name: 'sde_build',
      dartName: 'SdeBuild',
      schema: 'public',
      module: 'kaname',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'build',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'state',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:SdeBuildState',
        ),
        _isp.ColumnDefinition(
          name: 'importedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'activeMarker',
          columnType: _isp.ColumnType.boolean,
          isNullable: true,
          dartType: 'bool?',
        ),
        _isp.ColumnDefinition(
          name: 'previousMarker',
          columnType: _isp.ColumnType.boolean,
          isNullable: true,
          dartType: 'bool?',
        ),
        _isp.ColumnDefinition(
          name: 'held',
          columnType: _isp.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sde_build_build_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'build',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'sde_build_active_marker_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'activeMarker',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'sde_build_previous_marker_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'previousMarker',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'sde_build_diff',
      dartName: 'SdeBuildDiff',
      schema: 'public',
      module: 'kaname',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'fromBuild',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'toBuild',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'outcome',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:SdeBuildDiffOutcome',
        ),
        _isp.ColumnDefinition(
          name: 'failureReason',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'report',
          columnType: _isp.ColumnType.jsonb,
          isNullable: true,
          dartType: 'package:kaname_core/kaname_core.dart:SdeJson?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sde_build_diff_builds_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'fromBuild',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'toBuild',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'sde_bundle',
      dartName: 'SdeBundle',
      schema: 'public',
      module: 'kaname',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'build',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'outcome',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:SdeBundleOutcome',
        ),
        _isp.ColumnDefinition(
          name: 'reason',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'formatMajor',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'formatMinor',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'sha256',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'size',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'builtAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sde_bundle_build_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'build',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'sde_bundle_bytes',
      dartName: 'SdeBundleBytes',
      schema: 'public',
      module: 'kaname',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'build',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'sha256',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'bytes',
          columnType: _isp.ColumnType.bytea,
          isNullable: false,
          dartType: 'dart:typed_data:ByteData',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sde_bundle_bytes_build_sha256_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'build',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'sha256',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'sde_category',
      dartName: 'SdeCategory',
      schema: 'public',
      module: 'kaname',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'build',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'sdeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'published',
          columnType: _isp.ColumnType.boolean,
          isNullable: true,
          dartType: 'bool?',
        ),
        _isp.ColumnDefinition(
          name: 'iconId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'raw',
          columnType: _isp.ColumnType.jsonb,
          isNullable: false,
          dartType: 'package:kaname_core/kaname_core.dart:SdeJson',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sde_category_build_sde_id_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'build',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'sdeId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'sde_check',
      dartName: 'SdeCheck',
      schema: 'public',
      module: 'kaname',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'checkedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'latestBuild',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'outcome',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:SdeCheckOutcome',
        ),
        _isp.ColumnDefinition(
          name: 'failureReason',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sde_check_checked_at_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'checkedAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'sde_constellation',
      dartName: 'SdeConstellation',
      schema: 'public',
      module: 'kaname',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'build',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'sdeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'regionId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'factionId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'raw',
          columnType: _isp.ColumnType.jsonb,
          isNullable: false,
          dartType: 'package:kaname_core/kaname_core.dart:SdeJson',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sde_constellation_build_sde_id_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'build',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'sdeId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'sde_dogma_attribute',
      dartName: 'SdeDogmaAttribute',
      schema: 'public',
      module: 'kaname',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'build',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'sdeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'displayName',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'attributeCategoryId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'unitId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'defaultValue',
          columnType: _isp.ColumnType.doublePrecision,
          isNullable: true,
          dartType: 'double?',
        ),
        _isp.ColumnDefinition(
          name: 'published',
          columnType: _isp.ColumnType.boolean,
          isNullable: true,
          dartType: 'bool?',
        ),
        _isp.ColumnDefinition(
          name: 'highIsGood',
          columnType: _isp.ColumnType.boolean,
          isNullable: true,
          dartType: 'bool?',
        ),
        _isp.ColumnDefinition(
          name: 'stackable',
          columnType: _isp.ColumnType.boolean,
          isNullable: true,
          dartType: 'bool?',
        ),
        _isp.ColumnDefinition(
          name: 'raw',
          columnType: _isp.ColumnType.jsonb,
          isNullable: false,
          dartType: 'package:kaname_core/kaname_core.dart:SdeJson',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sde_dogma_attribute_build_sde_id_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'build',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'sdeId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'sde_dogma_attribute_category',
      dartName: 'SdeDogmaAttributeCategory',
      schema: 'public',
      module: 'kaname',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'build',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'sdeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'description',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'raw',
          columnType: _isp.ColumnType.jsonb,
          isNullable: false,
          dartType: 'package:kaname_core/kaname_core.dart:SdeJson',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sde_dogma_attribute_category_build_sde_id_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'build',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'sdeId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'sde_dogma_effect',
      dartName: 'SdeDogmaEffect',
      schema: 'public',
      module: 'kaname',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'build',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'sdeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'displayName',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'effectCategoryId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'published',
          columnType: _isp.ColumnType.boolean,
          isNullable: true,
          dartType: 'bool?',
        ),
        _isp.ColumnDefinition(
          name: 'isOffensive',
          columnType: _isp.ColumnType.boolean,
          isNullable: true,
          dartType: 'bool?',
        ),
        _isp.ColumnDefinition(
          name: 'isAssistance',
          columnType: _isp.ColumnType.boolean,
          isNullable: true,
          dartType: 'bool?',
        ),
        _isp.ColumnDefinition(
          name: 'raw',
          columnType: _isp.ColumnType.jsonb,
          isNullable: false,
          dartType: 'package:kaname_core/kaname_core.dart:SdeJson',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sde_dogma_effect_build_sde_id_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'build',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'sdeId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'sde_dogma_unit',
      dartName: 'SdeDogmaUnit',
      schema: 'public',
      module: 'kaname',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'build',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'sdeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'displayName',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'description',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'raw',
          columnType: _isp.ColumnType.jsonb,
          isNullable: false,
          dartType: 'package:kaname_core/kaname_core.dart:SdeJson',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sde_dogma_unit_build_sde_id_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'build',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'sdeId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'sde_group',
      dartName: 'SdeGroup',
      schema: 'public',
      module: 'kaname',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'build',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'sdeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'categoryId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'published',
          columnType: _isp.ColumnType.boolean,
          isNullable: true,
          dartType: 'bool?',
        ),
        _isp.ColumnDefinition(
          name: 'raw',
          columnType: _isp.ColumnType.jsonb,
          isNullable: false,
          dartType: 'package:kaname_core/kaname_core.dart:SdeJson',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sde_group_build_sde_id_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'build',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'sdeId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'sde_import',
      dartName: 'SdeImport',
      schema: 'public',
      module: 'kaname',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'build',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'source',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:SdeImportSource',
        ),
        _isp.ColumnDefinition(
          name: 'startedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'finishedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'outcome',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:SdeImportOutcome',
        ),
        _isp.ColumnDefinition(
          name: 'failureReason',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'fileCounts',
          columnType: _isp.ColumnType.jsonb,
          isNullable: true,
          dartType: 'package:kaname_core/kaname_core.dart:SdeJson?',
        ),
        _isp.ColumnDefinition(
          name: 'drift',
          columnType: _isp.ColumnType.jsonb,
          isNullable: true,
          dartType: 'package:kaname_core/kaname_core.dart:SdeJson?',
        ),
        _isp.ColumnDefinition(
          name: 'badRecords',
          columnType: _isp.ColumnType.jsonb,
          isNullable: true,
          dartType: 'package:kaname_core/kaname_core.dart:SdeJson?',
        ),
        _isp.ColumnDefinition(
          name: 'knownIds',
          columnType: _isp.ColumnType.jsonb,
          isNullable: true,
          dartType: 'package:kaname_core/kaname_core.dart:SdeJson?',
        ),
        _isp.ColumnDefinition(
          name: 'fieldCheck',
          columnType: _isp.ColumnType.jsonb,
          isNullable: true,
          dartType: 'package:kaname_core/kaname_core.dart:SdeJson?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sde_import_started_at_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'startedAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'sde_market_group',
      dartName: 'SdeMarketGroup',
      schema: 'public',
      module: 'kaname',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'build',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'sdeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'parentGroupId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'hasTypes',
          columnType: _isp.ColumnType.boolean,
          isNullable: true,
          dartType: 'bool?',
        ),
        _isp.ColumnDefinition(
          name: 'iconId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'raw',
          columnType: _isp.ColumnType.jsonb,
          isNullable: false,
          dartType: 'package:kaname_core/kaname_core.dart:SdeJson',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sde_market_group_build_sde_id_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'build',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'sdeId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'sde_meta_group',
      dartName: 'SdeMetaGroup',
      schema: 'public',
      module: 'kaname',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'build',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'sdeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'iconId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'raw',
          columnType: _isp.ColumnType.jsonb,
          isNullable: false,
          dartType: 'package:kaname_core/kaname_core.dart:SdeJson',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sde_meta_group_build_sde_id_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'build',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'sdeId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'sde_record',
      dartName: 'SdeRecord',
      schema: 'public',
      module: 'kaname',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'build',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'file',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'line',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'key',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'record',
          columnType: _isp.ColumnType.jsonb,
          isNullable: false,
          dartType: 'package:kaname_core/kaname_core.dart:SdeJson',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sde_record_build_file_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'build',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'file',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'sde_region',
      dartName: 'SdeRegion',
      schema: 'public',
      module: 'kaname',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'build',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'sdeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'factionId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'raw',
          columnType: _isp.ColumnType.jsonb,
          isNullable: false,
          dartType: 'package:kaname_core/kaname_core.dart:SdeJson',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sde_region_build_sde_id_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'build',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'sdeId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'sde_solar_system',
      dartName: 'SdeSolarSystem',
      schema: 'public',
      module: 'kaname',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'build',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'sdeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'constellationId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'regionId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'securityStatus',
          columnType: _isp.ColumnType.doublePrecision,
          isNullable: true,
          dartType: 'double?',
        ),
        _isp.ColumnDefinition(
          name: 'securityClass',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'raw',
          columnType: _isp.ColumnType.jsonb,
          isNullable: false,
          dartType: 'package:kaname_core/kaname_core.dart:SdeJson',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sde_solar_system_build_sde_id_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'build',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'sdeId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'sde_switch',
      dartName: 'SdeSwitch',
      schema: 'public',
      module: 'kaname',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'kind',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:SdeSwitchKind',
        ),
        _isp.ColumnDefinition(
          name: 'fromBuild',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'toBuild',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'at',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'outcome',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:SdeSwitchOutcome',
        ),
        _isp.ColumnDefinition(
          name: 'failureReason',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sde_switch_at_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'at',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'sde_type',
      dartName: 'SdeType',
      schema: 'public',
      module: 'kaname',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'build',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'sdeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'groupId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'published',
          columnType: _isp.ColumnType.boolean,
          isNullable: true,
          dartType: 'bool?',
        ),
        _isp.ColumnDefinition(
          name: 'volume',
          columnType: _isp.ColumnType.doublePrecision,
          isNullable: true,
          dartType: 'double?',
        ),
        _isp.ColumnDefinition(
          name: 'capacity',
          columnType: _isp.ColumnType.doublePrecision,
          isNullable: true,
          dartType: 'double?',
        ),
        _isp.ColumnDefinition(
          name: 'portionSize',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'mass',
          columnType: _isp.ColumnType.doublePrecision,
          isNullable: true,
          dartType: 'double?',
        ),
        _isp.ColumnDefinition(
          name: 'marketGroupId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'metaGroupId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'raw',
          columnType: _isp.ColumnType.jsonb,
          isNullable: false,
          dartType: 'package:kaname_core/kaname_core.dart:SdeJson',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sde_type_build_sde_id_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'build',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'sdeId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'sde_type_dogma',
      dartName: 'SdeTypeDogma',
      schema: 'public',
      module: 'kaname',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'build',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'sdeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'raw',
          columnType: _isp.ColumnType.jsonb,
          isNullable: false,
          dartType: 'package:kaname_core/kaname_core.dart:SdeJson',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'sde_type_dogma_build_sde_id_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'build',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'sdeId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
  ];

  static String? getClassNameFromObjectJson(dynamic data) =>
      _is.ProtocolDeserialization.readClassName(data);

  @override
  T deserialize<T>(dynamic data, [Type? t]) {
    t ??= T;
    final rawDataClassName = _is.ProtocolDeserialization.readClassName(data);
    final dataClassName = rawDataClassName;
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on _is.DeserializationClassNameNotFoundException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _iztepymd.DependencyStatus) {
      return _iztepymd.DependencyStatus.fromJson(data) as T;
    }
    if (t == _if75m2mz.HealthReport) {
      return _if75m2mz.HealthReport.fromJson(data) as T;
    }
    if (t == _iqvvlz0n.SdeBuild) {
      return _iqvvlz0n.SdeBuild.fromJson(data) as T;
    }
    if (t == _i6rvvlmq.SdeBuildDiff) {
      return _i6rvvlmq.SdeBuildDiff.fromJson(data) as T;
    }
    if (t == _iby3hddy.SdeBuildDiffOutcome) {
      return _iby3hddy.SdeBuildDiffOutcome.fromJson(data) as T;
    }
    if (t == _isyk7irp.SdeBuildState) {
      return _isyk7irp.SdeBuildState.fromJson(data) as T;
    }
    if (t == _ijqwsv4v.SdeBundle) {
      return _ijqwsv4v.SdeBundle.fromJson(data) as T;
    }
    if (t == _imonpi0j.SdeBundleBytes) {
      return _imonpi0j.SdeBundleBytes.fromJson(data) as T;
    }
    if (t == _iquqzrxf.SdeBundleOutcome) {
      return _iquqzrxf.SdeBundleOutcome.fromJson(data) as T;
    }
    if (t == _ig50l1bg.SdeCheck) {
      return _ig50l1bg.SdeCheck.fromJson(data) as T;
    }
    if (t == _illgk9kj.SdeCheckOutcome) {
      return _illgk9kj.SdeCheckOutcome.fromJson(data) as T;
    }
    if (t == _iucgsa1v.SdeImport) {
      return _iucgsa1v.SdeImport.fromJson(data) as T;
    }
    if (t == _is3f4xcr.SdeImportOutcome) {
      return _is3f4xcr.SdeImportOutcome.fromJson(data) as T;
    }
    if (t == _ice2slzs.SdeImportSource) {
      return _ice2slzs.SdeImportSource.fromJson(data) as T;
    }
    if (t == _i9m0mwcw.SdeRecord) {
      return _i9m0mwcw.SdeRecord.fromJson(data) as T;
    }
    if (t == _itdhfbzo.SdeSwitch) {
      return _itdhfbzo.SdeSwitch.fromJson(data) as T;
    }
    if (t == _iqktcwf1.SdeSwitchKind) {
      return _iqktcwf1.SdeSwitchKind.fromJson(data) as T;
    }
    if (t == _icb88h1v.SdeSwitchOutcome) {
      return _icb88h1v.SdeSwitchOutcome.fromJson(data) as T;
    }
    if (t == _ia9vf0pu.SdeCategory) {
      return _ia9vf0pu.SdeCategory.fromJson(data) as T;
    }
    if (t == _i99obepy.SdeConstellation) {
      return _i99obepy.SdeConstellation.fromJson(data) as T;
    }
    if (t == _ighsxk4r.SdeDogmaAttribute) {
      return _ighsxk4r.SdeDogmaAttribute.fromJson(data) as T;
    }
    if (t == _ij6v2kiw.SdeDogmaAttributeCategory) {
      return _ij6v2kiw.SdeDogmaAttributeCategory.fromJson(data) as T;
    }
    if (t == _ixeydgad.SdeDogmaEffect) {
      return _ixeydgad.SdeDogmaEffect.fromJson(data) as T;
    }
    if (t == _iybgpetd.SdeDogmaUnit) {
      return _iybgpetd.SdeDogmaUnit.fromJson(data) as T;
    }
    if (t == _iwdgrmzb.SdeGroup) {
      return _iwdgrmzb.SdeGroup.fromJson(data) as T;
    }
    if (t == _izn7xnfb.SdeMarketGroup) {
      return _izn7xnfb.SdeMarketGroup.fromJson(data) as T;
    }
    if (t == _i3etkb2u.SdeMetaGroup) {
      return _i3etkb2u.SdeMetaGroup.fromJson(data) as T;
    }
    if (t == _ioiqjh1t.SdeRegion) {
      return _ioiqjh1t.SdeRegion.fromJson(data) as T;
    }
    if (t == _iataywh8.SdeSolarSystem) {
      return _iataywh8.SdeSolarSystem.fromJson(data) as T;
    }
    if (t == _i19vm38w.SdeType) {
      return _i19vm38w.SdeType.fromJson(data) as T;
    }
    if (t == _ib14m8bx.SdeTypeDogma) {
      return _ib14m8bx.SdeTypeDogma.fromJson(data) as T;
    }
    if (t == _is.getType<_iztepymd.DependencyStatus?>()) {
      return (data != null ? _iztepymd.DependencyStatus.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_if75m2mz.HealthReport?>()) {
      return (data != null ? _if75m2mz.HealthReport.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iqvvlz0n.SdeBuild?>()) {
      return (data != null ? _iqvvlz0n.SdeBuild.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i6rvvlmq.SdeBuildDiff?>()) {
      return (data != null ? _i6rvvlmq.SdeBuildDiff.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iby3hddy.SdeBuildDiffOutcome?>()) {
      return (data != null
              ? _iby3hddy.SdeBuildDiffOutcome.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_isyk7irp.SdeBuildState?>()) {
      return (data != null ? _isyk7irp.SdeBuildState.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ijqwsv4v.SdeBundle?>()) {
      return (data != null ? _ijqwsv4v.SdeBundle.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_imonpi0j.SdeBundleBytes?>()) {
      return (data != null ? _imonpi0j.SdeBundleBytes.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iquqzrxf.SdeBundleOutcome?>()) {
      return (data != null ? _iquqzrxf.SdeBundleOutcome.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ig50l1bg.SdeCheck?>()) {
      return (data != null ? _ig50l1bg.SdeCheck.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_illgk9kj.SdeCheckOutcome?>()) {
      return (data != null ? _illgk9kj.SdeCheckOutcome.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iucgsa1v.SdeImport?>()) {
      return (data != null ? _iucgsa1v.SdeImport.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_is3f4xcr.SdeImportOutcome?>()) {
      return (data != null ? _is3f4xcr.SdeImportOutcome.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ice2slzs.SdeImportSource?>()) {
      return (data != null ? _ice2slzs.SdeImportSource.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i9m0mwcw.SdeRecord?>()) {
      return (data != null ? _i9m0mwcw.SdeRecord.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_itdhfbzo.SdeSwitch?>()) {
      return (data != null ? _itdhfbzo.SdeSwitch.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iqktcwf1.SdeSwitchKind?>()) {
      return (data != null ? _iqktcwf1.SdeSwitchKind.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_icb88h1v.SdeSwitchOutcome?>()) {
      return (data != null ? _icb88h1v.SdeSwitchOutcome.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ia9vf0pu.SdeCategory?>()) {
      return (data != null ? _ia9vf0pu.SdeCategory.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i99obepy.SdeConstellation?>()) {
      return (data != null ? _i99obepy.SdeConstellation.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ighsxk4r.SdeDogmaAttribute?>()) {
      return (data != null ? _ighsxk4r.SdeDogmaAttribute.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ij6v2kiw.SdeDogmaAttributeCategory?>()) {
      return (data != null
              ? _ij6v2kiw.SdeDogmaAttributeCategory.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_ixeydgad.SdeDogmaEffect?>()) {
      return (data != null ? _ixeydgad.SdeDogmaEffect.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iybgpetd.SdeDogmaUnit?>()) {
      return (data != null ? _iybgpetd.SdeDogmaUnit.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iwdgrmzb.SdeGroup?>()) {
      return (data != null ? _iwdgrmzb.SdeGroup.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_izn7xnfb.SdeMarketGroup?>()) {
      return (data != null ? _izn7xnfb.SdeMarketGroup.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i3etkb2u.SdeMetaGroup?>()) {
      return (data != null ? _i3etkb2u.SdeMetaGroup.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ioiqjh1t.SdeRegion?>()) {
      return (data != null ? _ioiqjh1t.SdeRegion.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iataywh8.SdeSolarSystem?>()) {
      return (data != null ? _iataywh8.SdeSolarSystem.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i19vm38w.SdeType?>()) {
      return (data != null ? _i19vm38w.SdeType.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ib14m8bx.SdeTypeDogma?>()) {
      return (data != null ? _ib14m8bx.SdeTypeDogma.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_idp9h2tz.SdeJson?>()) {
      return (data != null ? _idp9h2tz.SdeJson.fromJson(data) : null) as T;
    }
    if (t == _idp9h2tz.SdeJson) {
      return _idp9h2tz.SdeJson.fromJson(data) as T;
    }
    if (t == _is.getType<_idp9h2tz.SdeJson?>()) {
      return (data != null ? _idp9h2tz.SdeJson.fromJson(data) : null) as T;
    }
    final modules = deserializationMetadata.modulesForDeserialization(
      t,
      className: rawDataClassName,
    );
    for (final module in modules) {
      try {
        return module.deserialize<T>(data, t);
      } on _is.DeserializationTypeNotFoundException catch (_) {}
    }

    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _idp9h2tz.SdeJson => 'SdeJson',
      _iztepymd.DependencyStatus => 'DependencyStatus',
      _if75m2mz.HealthReport => 'HealthReport',
      _iqvvlz0n.SdeBuild => 'SdeBuild',
      _i6rvvlmq.SdeBuildDiff => 'SdeBuildDiff',
      _iby3hddy.SdeBuildDiffOutcome => 'SdeBuildDiffOutcome',
      _isyk7irp.SdeBuildState => 'SdeBuildState',
      _ijqwsv4v.SdeBundle => 'SdeBundle',
      _imonpi0j.SdeBundleBytes => 'SdeBundleBytes',
      _iquqzrxf.SdeBundleOutcome => 'SdeBundleOutcome',
      _ig50l1bg.SdeCheck => 'SdeCheck',
      _illgk9kj.SdeCheckOutcome => 'SdeCheckOutcome',
      _iucgsa1v.SdeImport => 'SdeImport',
      _is3f4xcr.SdeImportOutcome => 'SdeImportOutcome',
      _ice2slzs.SdeImportSource => 'SdeImportSource',
      _i9m0mwcw.SdeRecord => 'SdeRecord',
      _itdhfbzo.SdeSwitch => 'SdeSwitch',
      _iqktcwf1.SdeSwitchKind => 'SdeSwitchKind',
      _icb88h1v.SdeSwitchOutcome => 'SdeSwitchOutcome',
      _ia9vf0pu.SdeCategory => 'SdeCategory',
      _i99obepy.SdeConstellation => 'SdeConstellation',
      _ighsxk4r.SdeDogmaAttribute => 'SdeDogmaAttribute',
      _ij6v2kiw.SdeDogmaAttributeCategory => 'SdeDogmaAttributeCategory',
      _ixeydgad.SdeDogmaEffect => 'SdeDogmaEffect',
      _iybgpetd.SdeDogmaUnit => 'SdeDogmaUnit',
      _iwdgrmzb.SdeGroup => 'SdeGroup',
      _izn7xnfb.SdeMarketGroup => 'SdeMarketGroup',
      _i3etkb2u.SdeMetaGroup => 'SdeMetaGroup',
      _ioiqjh1t.SdeRegion => 'SdeRegion',
      _iataywh8.SdeSolarSystem => 'SdeSolarSystem',
      _i19vm38w.SdeType => 'SdeType',
      _ib14m8bx.SdeTypeDogma => 'SdeTypeDogma',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst('kaname.', '');
    }

    switch (data) {
      case _idp9h2tz.SdeJson():
        return 'SdeJson';
      case _iztepymd.DependencyStatus():
        return 'DependencyStatus';
      case _if75m2mz.HealthReport():
        return 'HealthReport';
      case _iqvvlz0n.SdeBuild():
        return 'SdeBuild';
      case _i6rvvlmq.SdeBuildDiff():
        return 'SdeBuildDiff';
      case _iby3hddy.SdeBuildDiffOutcome():
        return 'SdeBuildDiffOutcome';
      case _isyk7irp.SdeBuildState():
        return 'SdeBuildState';
      case _ijqwsv4v.SdeBundle():
        return 'SdeBundle';
      case _imonpi0j.SdeBundleBytes():
        return 'SdeBundleBytes';
      case _iquqzrxf.SdeBundleOutcome():
        return 'SdeBundleOutcome';
      case _ig50l1bg.SdeCheck():
        return 'SdeCheck';
      case _illgk9kj.SdeCheckOutcome():
        return 'SdeCheckOutcome';
      case _iucgsa1v.SdeImport():
        return 'SdeImport';
      case _is3f4xcr.SdeImportOutcome():
        return 'SdeImportOutcome';
      case _ice2slzs.SdeImportSource():
        return 'SdeImportSource';
      case _i9m0mwcw.SdeRecord():
        return 'SdeRecord';
      case _itdhfbzo.SdeSwitch():
        return 'SdeSwitch';
      case _iqktcwf1.SdeSwitchKind():
        return 'SdeSwitchKind';
      case _icb88h1v.SdeSwitchOutcome():
        return 'SdeSwitchOutcome';
      case _ia9vf0pu.SdeCategory():
        return 'SdeCategory';
      case _i99obepy.SdeConstellation():
        return 'SdeConstellation';
      case _ighsxk4r.SdeDogmaAttribute():
        return 'SdeDogmaAttribute';
      case _ij6v2kiw.SdeDogmaAttributeCategory():
        return 'SdeDogmaAttributeCategory';
      case _ixeydgad.SdeDogmaEffect():
        return 'SdeDogmaEffect';
      case _iybgpetd.SdeDogmaUnit():
        return 'SdeDogmaUnit';
      case _iwdgrmzb.SdeGroup():
        return 'SdeGroup';
      case _izn7xnfb.SdeMarketGroup():
        return 'SdeMarketGroup';
      case _i3etkb2u.SdeMetaGroup():
        return 'SdeMetaGroup';
      case _ioiqjh1t.SdeRegion():
        return 'SdeRegion';
      case _iataywh8.SdeSolarSystem():
        return 'SdeSolarSystem';
      case _i19vm38w.SdeType():
        return 'SdeType';
      case _ib14m8bx.SdeTypeDogma():
        return 'SdeTypeDogma';
    }
    className = _isp.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.') ? className : 'serverpod.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'SdeJson') {
      return deserialize<_idp9h2tz.SdeJson>(data['data']);
    }
    if (dataClassName == 'DependencyStatus') {
      return deserialize<_iztepymd.DependencyStatus>(data['data']);
    }
    if (dataClassName == 'HealthReport') {
      return deserialize<_if75m2mz.HealthReport>(data['data']);
    }
    if (dataClassName == 'SdeBuild') {
      return deserialize<_iqvvlz0n.SdeBuild>(data['data']);
    }
    if (dataClassName == 'SdeBuildDiff') {
      return deserialize<_i6rvvlmq.SdeBuildDiff>(data['data']);
    }
    if (dataClassName == 'SdeBuildDiffOutcome') {
      return deserialize<_iby3hddy.SdeBuildDiffOutcome>(data['data']);
    }
    if (dataClassName == 'SdeBuildState') {
      return deserialize<_isyk7irp.SdeBuildState>(data['data']);
    }
    if (dataClassName == 'SdeBundle') {
      return deserialize<_ijqwsv4v.SdeBundle>(data['data']);
    }
    if (dataClassName == 'SdeBundleBytes') {
      return deserialize<_imonpi0j.SdeBundleBytes>(data['data']);
    }
    if (dataClassName == 'SdeBundleOutcome') {
      return deserialize<_iquqzrxf.SdeBundleOutcome>(data['data']);
    }
    if (dataClassName == 'SdeCheck') {
      return deserialize<_ig50l1bg.SdeCheck>(data['data']);
    }
    if (dataClassName == 'SdeCheckOutcome') {
      return deserialize<_illgk9kj.SdeCheckOutcome>(data['data']);
    }
    if (dataClassName == 'SdeImport') {
      return deserialize<_iucgsa1v.SdeImport>(data['data']);
    }
    if (dataClassName == 'SdeImportOutcome') {
      return deserialize<_is3f4xcr.SdeImportOutcome>(data['data']);
    }
    if (dataClassName == 'SdeImportSource') {
      return deserialize<_ice2slzs.SdeImportSource>(data['data']);
    }
    if (dataClassName == 'SdeRecord') {
      return deserialize<_i9m0mwcw.SdeRecord>(data['data']);
    }
    if (dataClassName == 'SdeSwitch') {
      return deserialize<_itdhfbzo.SdeSwitch>(data['data']);
    }
    if (dataClassName == 'SdeSwitchKind') {
      return deserialize<_iqktcwf1.SdeSwitchKind>(data['data']);
    }
    if (dataClassName == 'SdeSwitchOutcome') {
      return deserialize<_icb88h1v.SdeSwitchOutcome>(data['data']);
    }
    if (dataClassName == 'SdeCategory') {
      return deserialize<_ia9vf0pu.SdeCategory>(data['data']);
    }
    if (dataClassName == 'SdeConstellation') {
      return deserialize<_i99obepy.SdeConstellation>(data['data']);
    }
    if (dataClassName == 'SdeDogmaAttribute') {
      return deserialize<_ighsxk4r.SdeDogmaAttribute>(data['data']);
    }
    if (dataClassName == 'SdeDogmaAttributeCategory') {
      return deserialize<_ij6v2kiw.SdeDogmaAttributeCategory>(data['data']);
    }
    if (dataClassName == 'SdeDogmaEffect') {
      return deserialize<_ixeydgad.SdeDogmaEffect>(data['data']);
    }
    if (dataClassName == 'SdeDogmaUnit') {
      return deserialize<_iybgpetd.SdeDogmaUnit>(data['data']);
    }
    if (dataClassName == 'SdeGroup') {
      return deserialize<_iwdgrmzb.SdeGroup>(data['data']);
    }
    if (dataClassName == 'SdeMarketGroup') {
      return deserialize<_izn7xnfb.SdeMarketGroup>(data['data']);
    }
    if (dataClassName == 'SdeMetaGroup') {
      return deserialize<_i3etkb2u.SdeMetaGroup>(data['data']);
    }
    if (dataClassName == 'SdeRegion') {
      return deserialize<_ioiqjh1t.SdeRegion>(data['data']);
    }
    if (dataClassName == 'SdeSolarSystem') {
      return deserialize<_iataywh8.SdeSolarSystem>(data['data']);
    }
    if (dataClassName == 'SdeType') {
      return deserialize<_i19vm38w.SdeType>(data['data']);
    }
    if (dataClassName == 'SdeTypeDogma') {
      return deserialize<_ib14m8bx.SdeTypeDogma>(data['data']);
    }
    if (dataClassName.startsWith('serverpod.')) {
      return _isp.Protocol().deserializeByClassName({
        ...data,
        'className': dataClassName.substring(10),
      });
    }
    return super.deserializeByClassName(data);
  }

  @override
  _is.Table? getTableForType(Type t) {
    {
      var table = _isp.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    switch (t) {
      case _iqvvlz0n.SdeBuild:
        return _iqvvlz0n.SdeBuild.t;
      case _i6rvvlmq.SdeBuildDiff:
        return _i6rvvlmq.SdeBuildDiff.t;
      case _ijqwsv4v.SdeBundle:
        return _ijqwsv4v.SdeBundle.t;
      case _imonpi0j.SdeBundleBytes:
        return _imonpi0j.SdeBundleBytes.t;
      case _ig50l1bg.SdeCheck:
        return _ig50l1bg.SdeCheck.t;
      case _iucgsa1v.SdeImport:
        return _iucgsa1v.SdeImport.t;
      case _i9m0mwcw.SdeRecord:
        return _i9m0mwcw.SdeRecord.t;
      case _itdhfbzo.SdeSwitch:
        return _itdhfbzo.SdeSwitch.t;
      case _ia9vf0pu.SdeCategory:
        return _ia9vf0pu.SdeCategory.t;
      case _i99obepy.SdeConstellation:
        return _i99obepy.SdeConstellation.t;
      case _ighsxk4r.SdeDogmaAttribute:
        return _ighsxk4r.SdeDogmaAttribute.t;
      case _ij6v2kiw.SdeDogmaAttributeCategory:
        return _ij6v2kiw.SdeDogmaAttributeCategory.t;
      case _ixeydgad.SdeDogmaEffect:
        return _ixeydgad.SdeDogmaEffect.t;
      case _iybgpetd.SdeDogmaUnit:
        return _iybgpetd.SdeDogmaUnit.t;
      case _iwdgrmzb.SdeGroup:
        return _iwdgrmzb.SdeGroup.t;
      case _izn7xnfb.SdeMarketGroup:
        return _izn7xnfb.SdeMarketGroup.t;
      case _i3etkb2u.SdeMetaGroup:
        return _i3etkb2u.SdeMetaGroup.t;
      case _ioiqjh1t.SdeRegion:
        return _ioiqjh1t.SdeRegion.t;
      case _iataywh8.SdeSolarSystem:
        return _iataywh8.SdeSolarSystem.t;
      case _i19vm38w.SdeType:
        return _i19vm38w.SdeType.t;
      case _ib14m8bx.SdeTypeDogma:
        return _ib14m8bx.SdeTypeDogma.t;
    }
    return null;
  }

  @override
  List<_isp.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

  @override
  List<_isp.TableDefinition> getOwnTableDefinitions() => _ownTableDefinitions;

  @override
  String getModuleName() => 'kaname';

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    try {
      return _isp.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
