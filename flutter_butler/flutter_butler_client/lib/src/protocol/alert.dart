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

abstract class Alert implements _i1.SerializableModel {
  Alert._({
    this.id,
    required this.userId,
    required this.deviceId,
    required this.time,
    required this.alertType,
    required this.isResolved,
  });

  factory Alert({
    int? id,
    required int userId,
    required int deviceId,
    required DateTime time,
    required String alertType,
    required bool isResolved,
  }) = _AlertImpl;

  factory Alert.fromJson(Map<String, dynamic> jsonSerialization) {
    return Alert(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      deviceId: jsonSerialization['deviceId'] as int,
      time: _i1.DateTimeJsonExtension.fromJson(jsonSerialization['time']),
      alertType: jsonSerialization['alertType'] as String,
      isResolved: jsonSerialization['isResolved'] as bool,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int userId;

  int deviceId;

  DateTime time;

  String alertType;

  bool isResolved;

  /// Returns a shallow copy of this [Alert]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Alert copyWith({
    int? id,
    int? userId,
    int? deviceId,
    DateTime? time,
    String? alertType,
    bool? isResolved,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Alert',
      if (id != null) 'id': id,
      'userId': userId,
      'deviceId': deviceId,
      'time': time.toJson(),
      'alertType': alertType,
      'isResolved': isResolved,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AlertImpl extends Alert {
  _AlertImpl({
    int? id,
    required int userId,
    required int deviceId,
    required DateTime time,
    required String alertType,
    required bool isResolved,
  }) : super._(
         id: id,
         userId: userId,
         deviceId: deviceId,
         time: time,
         alertType: alertType,
         isResolved: isResolved,
       );

  /// Returns a shallow copy of this [Alert]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Alert copyWith({
    Object? id = _Undefined,
    int? userId,
    int? deviceId,
    DateTime? time,
    String? alertType,
    bool? isResolved,
  }) {
    return Alert(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      time: time ?? this.time,
      alertType: alertType ?? this.alertType,
      isResolved: isResolved ?? this.isResolved,
    );
  }
}
