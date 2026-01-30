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

abstract class Location implements _i1.SerializableModel {
  Location._({
    this.id,
    required this.alertId,
    required this.latitude,
    required this.longitude,
    required this.time,
  });

  factory Location({
    int? id,
    required int alertId,
    required double latitude,
    required double longitude,
    required DateTime time,
  }) = _LocationImpl;

  factory Location.fromJson(Map<String, dynamic> jsonSerialization) {
    return Location(
      id: jsonSerialization['id'] as int?,
      alertId: jsonSerialization['alertId'] as int,
      latitude: (jsonSerialization['latitude'] as num).toDouble(),
      longitude: (jsonSerialization['longitude'] as num).toDouble(),
      time: _i1.DateTimeJsonExtension.fromJson(jsonSerialization['time']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int alertId;

  double latitude;

  double longitude;

  DateTime time;

  /// Returns a shallow copy of this [Location]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Location copyWith({
    int? id,
    int? alertId,
    double? latitude,
    double? longitude,
    DateTime? time,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Location',
      if (id != null) 'id': id,
      'alertId': alertId,
      'latitude': latitude,
      'longitude': longitude,
      'time': time.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _LocationImpl extends Location {
  _LocationImpl({
    int? id,
    required int alertId,
    required double latitude,
    required double longitude,
    required DateTime time,
  }) : super._(
         id: id,
         alertId: alertId,
         latitude: latitude,
         longitude: longitude,
         time: time,
       );

  /// Returns a shallow copy of this [Location]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Location copyWith({
    Object? id = _Undefined,
    int? alertId,
    double? latitude,
    double? longitude,
    DateTime? time,
  }) {
    return Location(
      id: id is int? ? id : this.id,
      alertId: alertId ?? this.alertId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      time: time ?? this.time,
    );
  }
}
