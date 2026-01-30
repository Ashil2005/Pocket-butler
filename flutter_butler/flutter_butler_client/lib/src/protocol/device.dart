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

abstract class Device implements _i1.SerializableModel {
  Device._({
    this.id,
    required this.userId,
    required this.deviceName,
    required this.deviceAddress,
    required this.isTrusted,
    this.rssiThreshold,
  });

  factory Device({
    int? id,
    required int userId,
    required String deviceName,
    required String deviceAddress,
    required bool isTrusted,
    int? rssiThreshold,
  }) = _DeviceImpl;

  factory Device.fromJson(Map<String, dynamic> jsonSerialization) {
    return Device(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      deviceName: jsonSerialization['deviceName'] as String,
      deviceAddress: jsonSerialization['deviceAddress'] as String,
      isTrusted: jsonSerialization['isTrusted'] as bool,
      rssiThreshold: jsonSerialization['rssiThreshold'] as int?,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int userId;

  String deviceName;

  String deviceAddress;

  bool isTrusted;

  int? rssiThreshold;

  /// Returns a shallow copy of this [Device]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Device copyWith({
    int? id,
    int? userId,
    String? deviceName,
    String? deviceAddress,
    bool? isTrusted,
    int? rssiThreshold,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Device',
      if (id != null) 'id': id,
      'userId': userId,
      'deviceName': deviceName,
      'deviceAddress': deviceAddress,
      'isTrusted': isTrusted,
      if (rssiThreshold != null) 'rssiThreshold': rssiThreshold,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DeviceImpl extends Device {
  _DeviceImpl({
    int? id,
    required int userId,
    required String deviceName,
    required String deviceAddress,
    required bool isTrusted,
    int? rssiThreshold,
  }) : super._(
         id: id,
         userId: userId,
         deviceName: deviceName,
         deviceAddress: deviceAddress,
         isTrusted: isTrusted,
         rssiThreshold: rssiThreshold,
       );

  /// Returns a shallow copy of this [Device]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Device copyWith({
    Object? id = _Undefined,
    int? userId,
    String? deviceName,
    String? deviceAddress,
    bool? isTrusted,
    Object? rssiThreshold = _Undefined,
  }) {
    return Device(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      deviceName: deviceName ?? this.deviceName,
      deviceAddress: deviceAddress ?? this.deviceAddress,
      isTrusted: isTrusted ?? this.isTrusted,
      rssiThreshold: rssiThreshold is int? ? rssiThreshold : this.rssiThreshold,
    );
  }
}
