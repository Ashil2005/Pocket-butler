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
import 'package:serverpod_client/serverpod_client.dart' as _i1;

abstract class Contact implements _i1.SerializableModel {
  Contact._({
    this.id,
    required this.userId,
    required this.name,
    required this.phoneNumber,
    required this.isEmergency,
  });

  factory Contact({
    int? id,
    required int userId,
    required String name,
    required String phoneNumber,
    required bool isEmergency,
  }) = _ContactImpl;

  factory Contact.fromJson(Map<String, dynamic> jsonSerialization) {
    return Contact(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      name: jsonSerialization['name'] as String,
      phoneNumber: jsonSerialization['phoneNumber'] as String,
      isEmergency: jsonSerialization['isEmergency'] as bool,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int userId;

  String name;

  String phoneNumber;

  bool isEmergency;

  /// Returns a shallow copy of this [Contact]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Contact copyWith({
    int? id,
    int? userId,
    String? name,
    String? phoneNumber,
    bool? isEmergency,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Contact',
      if (id != null) 'id': id,
      'userId': userId,
      'name': name,
      'phoneNumber': phoneNumber,
      'isEmergency': isEmergency,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ContactImpl extends Contact {
  _ContactImpl({
    int? id,
    required int userId,
    required String name,
    required String phoneNumber,
    required bool isEmergency,
  }) : super._(
         id: id,
         userId: userId,
         name: name,
         phoneNumber: phoneNumber,
         isEmergency: isEmergency,
       );

  /// Returns a shallow copy of this [Contact]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Contact copyWith({
    Object? id = _Undefined,
    int? userId,
    String? name,
    String? phoneNumber,
    bool? isEmergency,
  }) {
    return Contact(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isEmergency: isEmergency ?? this.isEmergency,
    );
  }
}
