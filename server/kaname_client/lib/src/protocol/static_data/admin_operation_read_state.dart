/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _isc;

/// Closed public operation-read outcomes (D9, D21).
enum AdminOperationReadState implements _isc.SerializableModel {
  waiting,
  running,
  ended,
  unknownOperation,
  operationReadBusy;

  static AdminOperationReadState fromJson(String name) {
    switch (name) {
      case 'waiting':
        return AdminOperationReadState.waiting;
      case 'running':
        return AdminOperationReadState.running;
      case 'ended':
        return AdminOperationReadState.ended;
      case 'unknownOperation':
        return AdminOperationReadState.unknownOperation;
      case 'operationReadBusy':
        return AdminOperationReadState.operationReadBusy;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "AdminOperationReadState"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
